Function Get-VmdkHash {
<#
	Create a list of MD5 hashes for the VMDKs at a given path
	Write the list to CHECKSUM-<SITENAME>.txt at the root of the VPODPATH
	HashAlgorithm defaults to MD5, which is fine for file validation
	Requires Powershell 4.0 or higher
#>
	PARAM(
		$VpodPath = $(throw "need -VPodName"),
		$SiteName = $(throw "need -SiteName"),
		$HashAlgorithm = 'MD5' #one of the supported types: MD5, SHA1, SHA256, SHA384, SHA512
	)
	PROCESS {
		# See if the checksum file already exists. Don't do anything if it's already there.
		## 
		
		$vmdkHashes = @()
		Foreach ( $vmdk in (Get-ChildItem $VpodPath -Filter *.vmdk) ) {
			$vmdkHash = "" | Select FileName,Hash
			$vmdkHash.FileName = $vmdk.Name
			$vmdkHash.Hash = $(Get-FileHash $vmdk.FullName -Algorithm $HashAlgorithm).Hash
			$vmdkHashes += $vmdkHash
			Write-Host 
		}
		$vmdkHashes | Export-Csv -NoTypeInformation $(Join-Path $VpodPath "CHECKSUMS-$SiteName.txt")
	}
} #Get-VmdkHash

Function Check-VmdkHash {
<#
	Verify the VMDK hashes for Site A against the hashes in file from Site B
	Read CHECKSUM-<SITEA>.txt and CHECKSUM-<SITEB>.txt and output differences
	Does not care about which hashing algorithm was used as long as the same 
		was used for both.
#>
	PARAM(
		$VpodPath = $(throw "need -VPodPath"),
		$SiteName = $(throw "need -SiteName"),
		$SourceSiteName = $(throw "need -SourceSiteName")
	)
	PROCESS {
		$good = $true
		# Import the CSV files into hash tables for comparison
		$sourceChecksumFile = $(Join-Path $VpodPath "CHECKSUMS-$SourceSiteName.txt")
		$sourceHashes = @{}
		Import-CSV $sourceChecksumFile | % { $sourceHashes.Add($_.FileName,$_.Hash) }

		$localChecksumFile = $(Join-Path $VpodPath "CHECKSUMS-$SiteName.txt")
		$localHashes = @{}
		Import-CSV $localChecksumFile | % { $localHashes.Add($_.FileName,$_.Hash) }
		
		Foreach ($FileName in ($localHashes.Keys)) {
			If( -Not( $sourceHashes[$FileName] -eq $localHashes[$FileName] ) ) {
				Write-Host -Fore Red "$FileName - hashes DO NOT match"
				$good = $false
			}
			$sourceHashes.Remove($FileName)
		}
		#Report 'extra' files in source that don't show up in localChecksumFile
		If( $sourceHashes.Length -ne 0 ) {
			Foreach ($FileName in ($sourceHashes.Keys)) {
				Write-Host -Fore Red "SOURCE FILE MISSING: $FileName"
				$good = $false
			}
		}
		If( -Not ($good) ) {
			Write-Host -Fore Red "Checksums for $VpodPath DO NOT match between $SourceSiteName and $SiteName"
		} Else {
			Write-Host -Fore Green "Checksums for $VpodPath match between $SourceSiteName and $SiteName"
		}
		return $good
	}
} #Check-VmdkHash

