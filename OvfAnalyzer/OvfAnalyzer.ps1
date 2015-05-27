<#
.NOTES
	Name:			OvfAnalyzer.ps1
	Author:		Doug Baer
	Version:	1.0
	Date:			2015-05-27

.SYNOPSIS
	parse OVF file and extract sizing information for HOL.

.DESCRIPTION
	Obtain the following summary information per OVF
		Lab SKU
		Number of VMs
		Number of vCPUs
		Amount of RAM (GB)
		Amount of Disk (GB)
	

.PARAMETER
	-Library
	
.EXAMPLE - using defaults
	OvfAnalyzer.ps1 -Library C:\OVF-Collection


.CHANGELOG
	Concept

#>

[CmdletBinding()]
param(
	[Parameter(Position=0,Mandatory=$true,HelpMessage="Path to the Content Library",
	ValueFromPipeline=$False)]
	[System.String]$ContentLibrary,

	[Parameter(Position=1,Mandatory=$false,HelpMessage="Path to the output file (CSV)",
	ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
	[System.String]$OutfilePath

)

###############################################################################
BEGIN {
	
	try { 
		if( -not (Test-Path $ContentLibrary) ) {
			Write-Host -Fore Red "Exiting: unable to find $ContentLibrary"
			Exit
		}
	}
	catch {
		#
	}

}

###############################################################################
PROCESS {
	
	$report = @()
	
	$libraryOvfs = @()
	Get-ChildItem $ContentLibrary -recurse -include '*.ovf' | % { $libraryOvfs += $_.FullName }

	$totalOvfs = ($libraryOvfs | Measure-Object).Count
	$currentOvf = 0

	foreach ($theOvf in $libraryOvfs ) {
		$currentOvf += 1
		Write-Host "Working on $currentOvf of $totalOvfs"

		[xml]$old = Get-Content $TheOvf
		$totalVms = 0
		$totalVcpu = 0
		$totalGbRam = 0
		$totalGbDisk = 0
		
		$row = "" | Select SKU, NumVM, NumCPU, GbRAM, GbDisk
		$row.SKU = $old.Envelope.VirtualSystemCollection.Name
		
		#Map the VMDK file names to the OVF IDs in a hash table by diskID within the OVF
		$oldVmdks = @{}
		foreach ($disk in $old.Envelope.References.File) {
			$diskID = ($disk.ID).Remove(0,5)
			$oldVmdks.Add($diskID,$disk.href)
		}
		
		## Match the OLD VMs and their files (uses $oldVmdks to resolve)
		$oldVms = @()
		$oldVms = $old.Envelope.VirtualSystemCollection.VirtualSystem
		$oldDiskMap = @{}
		
		foreach ($vm in $oldVms) {
			$totalVms += 1
			
			$numVcpu = ($vm.VirtualHardwareSection.Item | Where {$_.description -like 'Number of Virtual CPUs'}).VirtualQuantity
			$totalVcpu += $numVcpu
			
			$ramSize = ($vm.VirtualHardwareSection.Item | Where {$_.description -like 'Memory Size'})
			switch ($ramSize.AllocationUnits) {
				'byte * 2^20' { $GbRam = [int]($RamSize.VirtualQuantity) / 1024 }
				'byte * 2^30' { $GbRam = [int]($RamSize.VirtualQuantity) }
				default			 { $GbRam = 999999 }
			}
			$totalGbRam += $GbRam
	
			$disks = ($vm.VirtualHardwareSection.Item | Where {$_.description -like "Hard disk*"} | Sort -Property AddressOnParent)
			$i = 0
			foreach ($disk in $disks) {
				$parentDisks = @($Disks)
				$diskName = $parentDisks[$i].ElementName
				$i++
				$ref = ($disk.HostResource."#text")
				$ref = $ref.Remove(0,$ref.IndexOf("-") + 1)
				$thisDisk = $old.Envelope.DiskSection.disk | where { $_.diskId -match $ref }
				switch ($thisDisk.capacityAllocationUnits) {
					'byte * 2^20' { $GbDisk ="{0:N2}" -f ([int]($thisDisk.capacity) / 1024) }
					'byte * 2^30' { $GbDisk = [int]($thisDisk.capacity) }
					default				{ $diskSize = 99999999 } 
				}
				$totalGbDisk += $GbDisk
			}
		}
	
		$row.NumVM = $totalVms
		$row.NumCPU = $totalVcpu
		$row.GbRAM = $totalGbRam
		$row.GbDisk = $totalGbDisk

		$report += $row
	}

	If ($outfilePath){
		$report | Export-Csv -UseCulture $OutfilePath
	} Else {
		$report | Format-Table -Autosize
	}

}

###############################################################################

END {
	#Write-Host -fore Green "`n=*=*=*=*=* OvfAnalyzer $TheOvf End $(Get-Date) *=*=*=*=*="
}