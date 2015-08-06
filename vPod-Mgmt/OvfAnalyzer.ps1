<#
.NOTES
	Name:    OvfAnalyzer.ps1
	Author:  Doug Baer
	Version: 1.2
	Date:	   2015-07-01

.SYNOPSIS
	Parse OVF files and extract sizing information for HOL vPod analysis

.DESCRIPTION
	Obtain summary information per OVF:
		* vPod SKU (vApp name in OVF)
		* Count of VMs in the vApp
		* Total number of vCPUs requested
		* Total amount of RAM (GB) requested
		* Total amount of Disk (GB) requested

	Optionally report the same information per VM

.PARAMETER
	Library - (required) Windows path to folder containing OVF(s). Script will traverse the tree looking for files with .OVF extension.
	
.PARAMETER
	OutfilePath - (optional) Windows path to the CSV-formatted output file
	
.PARAMETER
	ExpandVMs - (optional) switch to indicate whether summary (default) or per-VM data is reported
	
.EXAMPLE
	OvfAnalyzer.ps1 -Library C:\OVFs

.EXAMPLE
	OvfAnalyzer.ps1 -Library C:\OVFs -ExpandVMs

.EXAMPLE
	OvfAnalyzer.ps1 -Library C:\OVFs -OutfilePath C:\temp\OVFs-Report.csv

.EXAMPLE
	OvfAnalyzer.ps1 -Library C:\OVFs -OutfilePath C:\temp\OVFs-DetailReport.csv -ExpandVMs

.CHANGELOG
	1.0   - Initial concept
	1.1   - Revised and cleaned up variables, added -ExpandVMs option
	1.1.1 - Added documentation, renamed ContentLibrary parameter to Library, cleaned up code.
	1.2   - Corrected per-VM reporting issue with disk space calculation

#>

[CmdletBinding()]
param(
	[Parameter(Position=0,Mandatory=$true,HelpMessage="Path to the OVF Library",
	ValueFromPipeline=$False)]
	[System.String]$Library,
	
	[Switch]$ExpandVMs,

	[Parameter(Position=1,Mandatory=$false,HelpMessage="Path to the output file (CSV)",
	ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
	[System.String]$OutfilePath

)

###############################################################################
BEGIN {
	
	try { 
		if( -not (Test-Path $Library) ) {
			Write-Host -Fore Red "Exiting: unable to find $Library"
			Exit
		}
	}
	catch {
		#
	}
	Write-Host -fore Green "`n=*=*=*=*=* OvfAnalyzer Begin $(Get-Date) *=*=*=*=*="
}

###############################################################################
PROCESS {
	
	$report = @()
	$reportVMs = @()
	
	$libraryOvfs = @()
	Get-ChildItem $Library -recurse -include '*.ovf' | % { $libraryOvfs += $_.FullName }

	$totalOvfs = ($libraryOvfs | Measure-Object).Count
	$currentOvf = 0

	Foreach( $theOvf in $libraryOvfs ) {
		$currentOvf += 1
		Write-Host "Working on $currentOvf of $totalOvfs"

		[xml]$ovf = Get-Content $theOvf
		$totalVms    = 0
		$totalVcpu   = 0
		$totalGbRam  = 0
		$totalGbDisk = 0
		
		$currentVpod = "" | Select SKU, NumVM, NumCPU, GbRAM, GbDisk
		$currentVpod.SKU = $ovf.Envelope.VirtualSystemCollection.Name
			
		$vpodVms = @()
		$vpodVms = $ovf.Envelope.VirtualSystemCollection.VirtualSystem
		
		Foreach( $vm in $vpodVms ) {
			$totalVms += 1
			$currentVM = "" | Select SKU, Name, NumCPU, GbRAM, GbDisk
			$currentVM.SKU = $ovf.Envelope.VirtualSystemCollection.Name
			$currentVM.Name = $vm.Name
			$currentVM.GbDisk = 0
			
			$numVcpu = ($vm.VirtualHardwareSection.Item | Where {$_.description -like 'Number of Virtual CPUs'}).VirtualQuantity
			$totalVcpu += $numVcpu
			$currentVM.NumCPU = $numVcpu
			
			$ramSize = ($vm.VirtualHardwareSection.Item | Where {$_.description -like 'Memory Size'})
			
			Switch( $ramSize.AllocationUnits ) {
				'byte * 2^20' { $GbRam = [int]($RamSize.VirtualQuantity) / 1024 }
				'byte * 2^30' { $GbRam = [int]($RamSize.VirtualQuantity) }
				'byte * 2^40' { $GbRam = 1024 * [int]($RamSize.VirtualQuantity) }
				default       { $GbRam = 999999 }
			}
			
			$totalGbRam += $GbRam
			$currentVM.GbRAM = $GbRam
	
			$disks = ($vm.VirtualHardwareSection.Item | Where {$_.description -like "Hard disk*"} | Sort -Property AddressOnParent)
			$i = 0
			Foreach( $disk in $disks ) {
				$parentDisks = @($Disks)
				$diskName = $parentDisks[$i].ElementName
				$i++
				$ref = ($disk.HostResource."#text")
				$ref = $ref.Remove(0,$ref.IndexOf("-") + 1)
				$thisDisk = $ovf.Envelope.DiskSection.disk | where { $_.diskId -match $ref }
				
				Switch( $thisDisk.capacityAllocationUnits ) {
					'byte * 2^20' { $GbDisk ="{0:N2}" -f ([int]($thisDisk.capacity) / 1024) }
					'byte * 2^30' { $GbDisk = [int]($thisDisk.capacity) }
					'byte * 2^40' { $GbDisk = 1024 * [int]($thisDisk.capacity) }
					default       { $diskSize = 99999999 } 
				}
				
				$totalGbDisk += $GbDisk
				$currentVM.GbDisk += $GbDisk
			}
			$reportVMs += $currentVM
		}
	
		$currentVpod.NumVM  = $totalVms
		$currentVpod.NumCPU = $totalVcpu
		$currentVpod.GbRAM  = $totalGbRam
		$currentVpod.GbDisk = $totalGbDisk

		$report += $currentVpod
	}

	If ($outfilePath) {
		If( $ExpandVMs ) { 
			$reportVMs | Export-Csv -UseCulture $OutfilePath 
		} Else {
			$report | Export-Csv -UseCulture $OutfilePath
		}
	} Else {
		If( $ExpandVMs ) { 
			$reportVMs | Sort -Property SKU | Format-Table -Autosize
		} Else {
			$report | Sort -Property SKU | Format-Table -Autosize
		}
	}
	
}

###############################################################################

END {
	Write-Host -fore Green "`n=*=*=*=*=* OvfAnalyzer Finished $(Get-Date) *=*=*=*=*="
}