Function QueryCloudsForVpodVersions {
<#
	Query HOL Clouds for Lab SKU and return presence + version
	Default search in the "HOL-Masters" catalog of each cloud. 
	Assumes $LibPath is authoritative regarding which SKUs should be reported.
	
	*** Must be authenticated to all $Clouds prior to running this function

	Example usage:
		$vcaClouds | % { connect-cloud -k $_ }
		QueryCloudsForVpodVersions -Clouds $vcaClouds -Catalog HOL-Masters -LibPath E:\2016-PODS -VpodFilter '*-16*'
		Disconnect-ciserver * -Confirm:$false

#>
	PARAM (
		$Clouds = @('HOL','VW2','SC2'),
		$Catalog = 'HOL-Masters',
		$LibPath = 'E:\HOL-Library',
		$VpodFilter = 'HOL-*'
	)
	
	BEGIN {
		#Setup variables to collect the data
		$report = @{}
		$cloudHash = @{}
		$currentVersions = @{}
		$Clouds | % { $cloudHash.Add($_,"") }

		If( Test-Path $LibPath ) {
			(Get-ChildItem $LibPath) | % { 
				$vAppName = $_.Name
				$vAppSKU = $vAppName.Substring(0,$vAppName.LastIndexOf('-'))
				$vAppVersion = $vAppName.Replace("$vAppSKU-",'')
				$currentVersions.Add($vAppSKU,$vAppVersion)
				$report.Add($vAppSKU,$cloudHash.Clone()) 
			}
		} Else {
			Write-Host -Foreground Red "ERROR: Unable to continue. Path $LibPath does not exist"
			Return
		}
	}
	PROCESS {

		Foreach( $cloud in $Clouds ) {
			$cloudName = (Get-CloudInfoFromKey -Key $cloud)[0]
			$orgName = (Get-CloudInfoFromKey -Key $cloud)[1]
			
			Try {
				$catSrc = Get-Catalog $Catalog -Server $cloudName -Org $orgName  -ErrorAction 1
				Foreach( $vApp in ( $catSrc.ExtensionData.CatalogItems.catalogItem ) ) {
					$vAppName = $vApp.Name
					If( $vAppName -like $VpodFilter ) {
						$vAppSKU = $vAppName.Substring(0,$vAppName.LastIndexOf('-'))
						$vAppVersion = $vAppName.Replace("$vAppSKU-",'')
						#Write-Host -Fore Yellow "DEBUG: $cloud $vAppSKU $vAppVersion"
						#Add the information only if the SKU exists in the hashtable
						If( ($vAppVersion -like 'v*') -and ($report.ContainsKey($vAppSKU)) ) {
							if($vAppVersion -ne $currentVersions[$vAppSKU]) {
								$vAppVersion += '*'
							}
							$report[$vAppSKU][$cloud] += "$vAppVersion "
						}
					} Else {
						Write-Host -Fore Yellow "DEBUG: $cloud discarding $vAppName by filter"
					}
				}
			}
			Catch {
				Write-Host -Fore Red "ERROR: $Catalog not found in $orgName of $cloudName"
			}
		}
		
		$out = @()
		Foreach( $vpod in ( $report.keys | Sort-Object ) ) {
			$line = "" | select (@('SKU') + $Clouds)
			$line.SKU = $vpod
			Foreach( $cloud in $Clouds ) {
				$line.($cloud) = $report[$vpod][$cloud]
			}
			$out += $line
		}
		
		$out | Sort-Object -Property "SKU" | Format-Table -AutoSize
	}
} #QueryCloudsForVpodVersions
