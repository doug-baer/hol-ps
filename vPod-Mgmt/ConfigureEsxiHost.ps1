<#
	Configuration script for HOL vCenter(s) and vESXi hosts
	Start with empty vCenter inventory
	End with Datacenter, Cluster, $baseHostCount hosts in the Cluster
		NFS datastore mounted, VDS implemented and hosts migrated to the VDS
#>

$esxSettings = @{
	'UserVars.DcuiTimeOut' = 0
	'UserVars.SuppressShellWarning' = 1
	'Vpx.Vpxa.Config.log.level' = 'info'
	'Syslog.global.logHost' = 'udp://vcsa-01b.corp.local:514'
	'Syslog.global.defaultRotate' = 2
}

$vcLogSettings = @{
	'config.log.maxFileSize' = 1048576
	'config.log.maxFileNum'  = 2
}

$vCenterLicense = '' #vc.standard.instance
$esxLicense = '' #esx.vcloudEnterprise.cpuPackage

$baseHostCount = 1
$baseSites = $('b')
$datacenterNamePrefix = 'Datacenter Site '
$clusterNamePrefix = 'Cluster Site '

#####################################################################

Foreach( $baseSite in $baseSites) {
	$vCenterServer = "vcsa-01{0}.corp.local" -f $baseSite
	Connect-VIserver $vCenterServer -username administrator@vsphere.local -password VMware1!
	#this should add the licenses to the vCenter inventory
	$LicMgr = Get-View (Get-View $DefaultViServer).Content.LicenseManager
	$LicMgr.AddLicense($vCenterLicense,$null)
	$LicMgr.AddLicense($esxLicense,$null)
	
	#Prepare for license assignments
	$si = Get-View ServiceInstance
	$LicManRef = $si.Content.LicenseManager
	$LicManView = Get-View $LicManRef
	$LicAssignMgrView = Get-View $LicManView.LicenseAssignmentManager

	#Assign the license to vCenter (not yet tested)
	$vcUuid = $si.Content.About.InstanceUuid
	$LicAssignMgrView.UpdateAssignedLicense($vcUuid,$vCenterLicense,$null)
	
	#Reconfigure vCenter logging
	$vcLogSettings.Keys | % { Get-AdvancedSetting -Entity $defaultviserver -name $_ | Set-AdvancedSetting -Value $($vcLogSettings[$_]) -Confirm:$false | Out-Null }

	#Build the datacenter if it is not already there
	$dcName = $datacenterNamePrefix + $baseSite.ToUpper()
	
	Try {
		$dc = Get-Datacenter -Name $dcName -ErrorAction 1
	} Catch {
		$f = Get-Folder
		$dc = New-Datacenter -Name $dcName -Location $f
	}
	
	$clusterName = $clusterNamePrefix + $baseSite.ToUpper()

	Try {
		$cluster = Get-Cluster -Name $clusterName -Location $dc -ErrorAction 1
	} Catch {
		#Create a cluster with VSAN, HA, DRS disabled -- set DRS to 'PartiallyAutomated' before disabling
		$cluster = New-Cluster -Location $dc -Name $clusterName -HAEnabled:$false -DrsEnabled:$true -VsanEnabled:$false -DrsAutomationLevel PartiallyAutomated
		$cluster | Set-Cluster -DrsEnabled:$false
	}
	
	#Add the hosts if they're not already in the DC... put them into the cluster
	1..$baseHostCount | Foreach {
		$hostName = "esx-{0:00}{1}.corp.local" -f $_,$baseSite
		Try {
			Get-VMHost -Location $dc -Name $hostName -ErrorAction 1
		} Catch {
			Add-VMHost -Location $cluster -Name $hostName -username "root" -password "VMware1!" -Confirm:$false -Force
		}
	}
	
	Foreach ($h in (Get-VMHost -Location $dc) ) {
		$hostname = $h.name
	
		#Assign license to host
		$hostMoRef = ($h | Get-View).MoRef
		#it looks like the 3rd parameter here is the "Asset" name
		$LicAssignMgrView.UpdateAssignedLicense($hostMoRef.Value,$esxLicense,$hostname)	

		#Configure NTP on the host
		Add-VMhostNtpserver -vmhost $h -ntpserver '192.168.100.1'
		Get-VMHostFirewallException  -vmh $h | where {$_.name -like "*NTP Client*" } | Set-VMHostFirewallException -Enabled:$true
		Get-VMHostService -vmhost $h | Where {$_.key -eq "ntpd"} | Start-VMHostService
		Get-VMHostService -vmhost $h | Where {$_.key -eq "ntpd"} | Set-VMHostService -policy 'automatic'
	
		#Basic vSwitch (vSS) Configuration to get access to the NFS storage
		$vs = get-virtualswitch -name vSwitch0 -vmhost $h
		$matches = Select-String -InputObject $h.Name -Pattern 'esx-(\d+)(a|b).corp.local'
		$hostNum = [int]$matches.Matches[0].Groups[1].value
		$hostSite = $matches.Matches[0].Groups[2].value
		
		$hostID = 50 + $hostNum
		$storageIP = '10.00.20.' + $hostID
		$vmotionIP = '10.00.30.' + $hostID
		$nfsHostIP = '10.00.20.60'
		If( $hostSite -eq 'a' ) {
			$storageIP = $storageIP.Replace('00','10')
			$vmotionIP = $vmotionIP.Replace('00','10')
			$nfsHostIP = $nfsHostIP.Replace('00','10')
		} Else {
			$storageIP = $storageIP.Replace('00','20')
			$vmotionIP = $vmotionIP.Replace('00','20')
			$nfsHostIP = $nfsHostIP.Replace('00','20')
		}
		
		New-VmhostNetworkAdapter -vmhost $h -portgroup $($hostname +"_storage") -IP $storageIP -subnetmask 255.255.255.0 -virtualswitch $vs -confirm:$false
		New-VmhostNetworkAdapter -vmhost $h -portgroup $($hostname +"_vmotion") -IP $vmotionIP -subnetmask 255.255.255.0 -virtualswitch $vs -vmotionenabled:$true -confirm:$false
		
		#Add vmnic1 to the vSwitch0 so it has two uplinks
		$pNic1 = $h | Get-VMHostNetworkAdapter -Physical -Name vmnic1
		Get-VirtualSwitch -VMHost $h -Standard -Name "vSwitch0" | Add-VirtualSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $pNic1 -Confirm:$false
	
		#Mount the NFS datastore from the FreeNAS
		$nfsDatastoreName = 'ds-site-' + $baseSite + '-nfs01'
		$nfsPath = '/mnt/NFS' + $baseSite.ToUpper()
		New-datastore -NFS -Name $nfsDatastoreName -VMhost $h -nfshost $nfsHostIP -path $nfsPath

		#Tweak advanced settings on the host
		#can I get away with just setting the 'global' value instead of resetting each one?
		Get-AdvancedSetting -Entity $h -Name 'Syslog.loggers.*.rotate' | Set-AdvancedSetting -Value 2 -Confirm:$false | Out-Null
		Foreach ($setting in $esxSettings.Keys) { 
			Get-AdvancedSetting -Entity $h -name $setting | Set-AdvancedSetting -Value $($esxSettings[$setting]) -Confirm:$false | Out-Null
		}
	} #Foreach Host
	
	#Create the vDS
	# If needed, Import-Module Vmware.VimAutomation.Vds
	$vdsName = "vds-site-{0}" -f $baseSite
	$vds = New-VDSwitch -Name $vdsName -Location (Get-Datacenter -Name $dcName)
	
	#rename uplink group: vds-site-a-corpnet-uplinks
	#how??
	
	# Create DVPortgroups
	Write-Host "Creating new Management DVPortgroup"
	New-VDPortgroup -Name "Management Network" -Vds $vds | Out-Null
	Write-Host "Creating new Storage DVPortgroup"
	New-VDPortgroup -Name "Storage Network" -Vds $vds | Out-Null
	Write-Host "Creating new vMotion DVPortgroup"
	New-VDPortgroup -Name "vMotion Network" -Vds $vds | Out-Null
	Write-Host "Creating new VM DVPortgroup`n"
	New-VDPortgroup -Name "VM Network" -Vds $vds | Out-Null
	
	#Migrate site's hosts to new VDS
	Foreach ($vmhost in (Get-VMHost -Location (Get-Datacenter -Name $dcName)) {
		$hostname = $vmhost.Name
		Write-Host ("Adding {0} to {1}" -f $hostname,$vdsName)
		$vds | Add-VDSwitchVMHost -VMHost $vmhost | Out-Null

		# Migrate host's first pNIC to VDS (vmnic0)
		Write-Host ("Adding vmnic0 to {0}" -f $vdsName)
		$vmhostNetworkAdapter = Get-VMHost $vmhost | Get-VMHostNetworkAdapter -Physical -Name vmnic0
		$vds | Add-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $vmhostNetworkAdapter -Confirm:$false

		# Migrate Management VMkernel interface to VDS

		# Management #
		$mgmt_portgroup = "Management Network"
		Write-Host ("Migrating {0} to {1}" -f $mgmt_portgroup, $vdsName)
		$dvportgroup = Get-VDPortgroup -name $mgmt_portgroup -VDSwitch $vds
		$vmk = Get-VMHostNetworkAdapter -Name vmk0 -VMHost $vmhost
		Set-VMHostNetworkAdapter -PortGroup $dvportgroup -VirtualNic $vmk -Confirm:$false | Out-Null

		# Migrate host's second pNIC to VDS (vmnic1)
		Write-Host ("Adding vmnic1 to {0}" -f $vdsName)
 		$vmhostNetworkAdapter = Get-VMHost $vmhost | Get-VMHostNetworkAdapter -Physical -Name vmnic1
		$vds | Add-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $vmhostNetworkAdapter -Confirm:$false

		# Migrate remaining VMkernel interfaces to VDS

		# Storage #
		$storage_portgroup = "Storage Network"
		Write-Host ("Migrating {0} to {1}" -f $storage_portgroup, $vdsName)
		$dvportgroup = Get-VDPortgroup -name $storage_portgroup -VDSwitch $vds
		$vmk = Get-VMHostNetworkAdapter -Name vmk1 -VMHost $vmhost
		Set-VMHostNetworkAdapter -PortGroup $dvportgroup -VirtualNic $vmk -Confirm:$false | Out-Null
 
		# vMotion #
		$vmotion_portgroup = "vMotion Network"
		Write-Host ("Migrating {0} to {1}" -f $vmotion_portgroup, $vdsName)
		$dvportgroup = Get-VDPortgroup -name $vmotion_portgroup -VDSwitch $vds
		$vmk = Get-VMHostNetworkAdapter -Name vmk2 -VMHost $vmhost
		Set-VMHostNetworkAdapter -PortGroup $dvportgroup -VirtualNic $vmk -Confirm:$false | Out-Null
 
		# Migrate remaining pNICs to VDS (vmnic2/vmnic3) -- HOL does not use these by default
<#
		Write-Host "Adding vmnic2/vmnic3 to" $vdsName
		$vmhostNetworkAdapter = Get-VMHost $vmhost | Get-VMHostNetworkAdapter -Physical -Name vmnic2
		$vds | Add-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $vmhostNetworkAdapter -Confirm:$false
		$vmhostNetworkAdapter = Get-VMHost $vmhost | Get-VMHostNetworkAdapter -Physical -Name vmnic3
		$vds | Add-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $vmhostNetworkAdapter -Confirm:$false
#>

		# Remove old vSwitch portgroups from vSwitch0
		$vswitch = Get-VirtualSwitch -VMHost $vmhost -Name "vSwitch0"
		 
		Write-Host "Removing vSwitch portgroup" $mgmt_portgroup
		$mgmt_pg = Get-VirtualPortGroup -Name $mgmt_portgroup -VirtualSwitch $vswitch
		Remove-VirtualPortGroup -VirtualPortGroup $mgmt_pg -confirm:$false
 
		$vmotion_portgroup = $hostname + "_vmotion" 
		Write-Host "Removing vSwitch portgroup" $vmotion_portgroup
		$vmotion_pg = Get-VirtualPortGroup -Name $vmotion_portgroup -VirtualSwitch $vswitch
		Remove-VirtualPortGroup -VirtualPortGroup $vmotion_pg -confirm:$false

 		$storage_portgroup = $hostname + "_storage"
		Write-Host "Removing vSwitch portgroup" $storage_portgroup
		$storage_pg = Get-VirtualPortGroup -Name $storage_portgroup -VirtualSwitch $vswitch
		Remove-VirtualPortGroup -VirtualPortGroup $storage_pg -confirm:$false
		
		#Remove the old vSwitch
		Remove-VirtualSwitch -VirtualSwitch $vswitch -Confirm:$false
		Write-Host "`n"

	} #Foreach host - vSwitch migration to VSD
	
} #Foreach Site

### END ###
