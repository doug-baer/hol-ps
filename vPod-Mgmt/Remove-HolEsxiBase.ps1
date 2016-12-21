<#
.SYNOPSIS
Removes identified host(s) from vCenter inventory, including unhooking from vDS

.DESCRIPTION
This is an HOL accelerator tool and is intended to be quick and dirty with minimal error checking.
It has been tested against the HOL vSphere 6.5 Base vPods and assumes a clean, unmodified deployment.

The script will
	* look for VMs on the host
	* put the host into maintenance mode
	* remove the FreeNAS iSCSI target from the iSCSI configuration
	* remove the host from the vDS
	* remove the host from vCenter inventory

.NOTES
Remove-HolEsxiBase.ps1 - December 21, 2016

.EXAMPLE
Remove-HolEsxiBase.ps1

.INPUTS
Interactive: 
	* site [a|b]
	* comma-separated list of host numbers

.OUTPUTS
#>

### Variables
$adminUser = 'administrator@corp.local'
$rootPassword = 'VMware1!'
$svsName = 'vSwitchTemp'
$mgmtPgName = 'Management Network'

#If not present, Load PowerCLI
If( !(Get-Module VMware.VimAutomation.Core) ) {
	Try {
		#For PowerCLI v6.5
		$PowerCliInit = 'C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1'
		. $PowerCliInit $true
	} 
	Catch {
		Write-Host -ForegroundColor Red "No PowerCLI found, unable to continue."
		Write-Host "Press any key to end script."
		$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		Break
	}
}

# Disconnect from all vCenters to eliminate confusion
if( ($global:DefaultVIServers).Count -gt 0 ) {
	Disconnect-VIserver * -Confirm:$false | Out-Null
}

#Determine whether we will work on site A or site B
$site = ''
while( ($site -ne 'a') -and ($site -ne 'b') -and ($site -ne 'q') ) {
	$site = Read-Host "Enter the site (a|b) or 'q' to quit"
	$site = $site.ToLower()
}
if( $site -eq 'q' ) { Return }

#Set this to the numbers of the hosts that you want to configure
$numbers = Read-Host 'Host numbers as a comma-separated list (default=4,5)'
if( $numbers -ne '' ) { 
	$hostNumbers =  ($numbers.Split(',')) | %  { [int] $_ }
}
else {
	#default to hosts 4-5
	$hostNumbers = (4,5)
	$numbers = '4,5'
}

# Generate the host names based on standard naming and entered numbers
$hostNames = @()
foreach( $hostNumber in $hostNumbers ) { 
	$hostNames += ("esx-{0:00}{1}.corp.local" -f $hostNumber,$site)
}

Write-Host "Ready to work on site $($site.ToUpper())"
Foreach( $hostName in $hostNames ) {
	Write-Host "`t$hostName"
}
while( $answer -ne 'y' ) {
	$answer = Read-Host "Confirm? [Y|n]"
	$answer = $answer.ToLower()
	if( $answer -eq '' ) { $answer = 'y' }
	if( $answer -eq 'n' ) { Return }
}

$vCenterServer = "vcsa-01{0}.corp.local" -f $site
try {
	Connect-VIserver $vCenterServer -username $adminUser -password $rootPassword
} catch {
	#Bail if the connection to vCenter does not work. Nothing else makes sense to try.
	Write-Host -ForegroundColor Red "ERROR: Unable to connect to vCenter $vCenterServer"
	Write-Host "Press any key to end script."
	$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	Return
}

#####################################################################

$dc = Get-Datacenter

#Get the VDS -- there should only be one in the base pod
$vdsName = "Region"+$site.ToUpper()+"01-vDS-COMP"
$vds = Get-VDSwitch -name $vdsName

Foreach ($hostName in $hostNames) {
	Write-Host -ForegroundColor Green "Working on $hostName"
	$vmhost = Get-VMHost -Location $dc -Name $hostName 

	#look for VMs registered on host, stop if found
	Write-Host "`tLooking for VMs"
	$vms = ($vmhost | Get-VM)
	if( $vms.Count -gt 0 ) {
		Write-Host -ForegroundColor Red "VMs exist on host $hostName. Cannot continue."
		Write-Host "Press any key to end script."
		$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		Return
	}

	# Put the target into Maintenance Mode
	Write-Host "`tEntering Maintenance Mode"
	$vmhost | Set-VMhost -State Maintenance | Out-Null

	Write-Host "`tUnconfiguring iSCSI"
	#Disconnect iSCSI datastore from this host
	$vmhost | Get-VMHostHba -Type iScsi | Get-IScsiHbaTarget | Remove-IScsiHbaTarget -Confirm:$false

	#Unhook from vDS
	#Remove vmnic1 from VDS -- sleep is necessary to allow NIC to finish reassignment
	Write-Host ("`tRemoving {0} vmnic1 from {1} (~10 sec)" -f $hostName,$vdsName)
	$pNic1 = $vmhost | Get-VMHostNetworkAdapter -Physical -Name 'vmnic1'
	Remove-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $pNic1 -Confirm:$false
	Sleep -Seconds 10

	#Look for standard vSwitch. If none, create a new one called "vSwitchTemp"
	try { 
		Write-Host "`tChecking $hostName for existing vSwitch"
		$svs = Get-VirtualSwitch -Standard -VMHost $vmhost -Name $svsName -ErrorAction 1
	}
	catch {
		Write-Host "`tCreating new vSwitch on $hostName (~10 sec)"
		$svs = New-VirtualSwitch -VMHost $vmhost -Name $svsName -Nic $pNic1
		Sleep -Seconds 10
	}

	#Create the "Management Network" portgroup if it is not there already
	try { 
		Write-Host "`tChecking $svsName for existing Management port group"
		$mgmtPg = Get-VirtualPortGroup -VirtualSwitch $svs -Name $mgmtPgName -ErrorAction 1
	}
	catch {
		Write-Host "`tCreating new port group on $hostName (~10 sec)"
		$mgmtPg = New-VirtualPortGroup -VirtualSwitch $svs -Name $mgmtPgName
		Sleep -Seconds 10
	}

	#Remove vmk1, vmk2
	Write-Host "`tRemoving vmk1 and vmk2"
	(1..2) | % { $vmhost | Get-VMHostNetworkAdapter -VMKernel -Name "vmk$_" |  Remove-VMHostNetworkAdapter -Confirm:$false }
	
	Write-Host "`tMigrating $hostName vmk0 to $svsName"
	$vmk0 = $vmhost | Get-VMHostNetworkAdapter -VMKernel -Name 'vmk0'
	Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $svs -VMHostPhysicalNic $pNic1 -VMHostVirtualNic $vmk0 -VirtualNicPortgroup $mgmtPgName -Confirm:$false	
	
	#Remove vmnic0 from vDS
	Write-Host ("`tRemoving {0} vmnic0 from {1}" -f $hostName,$vdsName)
	$pNic0 = $vmhost | Get-VMHostNetworkAdapter -Physical -Name 'vmnic0'
	Remove-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $pNic0 -Confirm:$false

	#Remove host from vDS
	Write-Host "`tRemoving $hostName from $vdsName"
	$vds | Remove-VDSwitchVMHost -VMHost $vmhost -Confirm:$false
 
	#Remove host from vCenter
	Write-Host "`tRemoving $hostName from vCenter"
	$vmhost | Remove-VMHost -Confirm:$false
}

#####################################################################

Disconnect-VIserver * -Confirm:$false

Write-Host -Fore Green "*** Finished ***"

### END ###
