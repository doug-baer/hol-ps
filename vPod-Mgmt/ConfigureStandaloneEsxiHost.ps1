<#
	Configuration script for HOL vCenter(s) and vESXi hosts
	Start with empty vCenter inventory
	End with Datacenter, Cluster, $baseHostCount hosts in the Cluster
		NFS datastore mounted, VDS implemented and hosts migrated to the VDS
#>

$esxSettings = @{
	'UserVars.DcuiTimeOut' = 0
	'UserVars.SuppressShellWarning' = 1
	'Syslog.global.logHost' = 'udp://vcsa-01a.corp.local:514'
	'Syslog.global.defaultRotate' = 2
}

#only valid setting if attached to vCenter
# 	'Vpx.Vpxa.Config.log.level' = 'info'


$hostNames = $('esx-03a.corp.local','esx-04a.corp.local')
$rootPassword = 'VMware1!'

#####################################################################

Foreach( $hostName in $hostNames) {
	Write-Host -Fore Green "Working on host $hostname"
	Connect-VIserver $hostName -username root -password $rootPassword
	$h = Get-VmHost $hostname
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
	
	#Tweak advanced settings on the host
	#can I get away with just setting the 'global' value instead of resetting each one?
	Get-AdvancedSetting -Entity $h -Name 'Syslog.loggers.*.rotate' | Set-AdvancedSetting -Value 2 -Confirm:$false | Out-Null
	Foreach ($setting in $esxSettings.Keys) { 
		Get-AdvancedSetting -Entity $h -name $setting | Set-AdvancedSetting -Value $($esxSettings[$setting]) -Confirm:$false | Out-Null
	}
	
	Write-Host -Fore Green "Finished with host $hostname"
	Disconnect-VIserver * -Confirm:$false
} #Foreach Host

### END ###
