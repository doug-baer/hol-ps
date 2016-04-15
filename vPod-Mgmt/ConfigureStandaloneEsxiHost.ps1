<#
	Configuration script for HOL "extra" vESXi hosts
		Basic networking + VSAN prep
		
	April 15, 2016
#>


$rootPassword = 'VMware1!'
$ntpServer = '192.168.100.1'
# Base config has a single 5 GB SSD and a single 40 GB HDD
$vsanSsdSize = 5
$vsanHddSize = 40

#Determine site A or site B
$site = ''
while( ($site -ne 'a') -and ($site -ne 'b') -and ($site -ne 'q') ) {
	$site = Read-Host "Enter the site (a|b) or 'q' to quit"
	$site = $site.ToLower()
}
if( $site -eq 'q' ) { Return }

#Set this to the numbers of the hosts that you want to configure
$numbers = Read-Host 'Host numbers as a comma-separated list (default=4,5,6,7,8)'
if( $numbers -ne '' ) { 
	$hostNumbers =  ($numbers.Split(',')) | %  { [int] $_ }
}
else {
	$hostNumbers = (4,5,6,7,8)
	$numbers = '4,5,6,7,8'
}

Write-Host "Performing operation on site $($site.ToUpper()) for hosts $numbers"

$esxSettings = @{
	'UserVars.DcuiTimeOut' = 0
	'UserVars.SuppressShellWarning' = 1
	'Syslog.global.logHost' = "udp://vcsa-01$site.corp.local:514"
	'Syslog.global.defaultRotate' = 2
}

#Import the module we use for flagging SSD/HDD devices
try {
	Import-Module 'C:\HOL\Tools\HOL-SCSI.psm1' -ErrorAction 1
} catch {
	Write-Host "no HOL-SCSI module"
}


#####################################################################

$hostNames = @()
foreach( $hostNumber in $hostNumbers ) { 
	if( $hostNumber -lt 10 ) { 
		$hostNumber = "0$hostNumber" 
	}
	$hostNames += ('esx-' + $hostNumber + "$site.corp.local") 
}

Write-Host "Perform configuration for hosts:"
Foreach( $hostName in $hostNames ) {
	Write-Host "`t$hostName"
}

while( $answer -ne 'y' ) {
	$answer = Read-Host "Confirm? [Y|n]"
	$answer = $answer.ToLower()
	if( $answer -eq '' ) { $answer = 'y' }
	if( $answer -eq 'n' ) { Return }
}

#####################################################################

Foreach( $hostName in $hostNames) {
	Write-Host -Fore Green "Working on host $hostname"
	Connect-VIserver $hostName -username root -password $rootPassword
	$h = Get-VmHost $hostname
	#get the short host name (first node of FQDN)
	$hn = ($hostname.Split('.'))[0]

	Write-Host -Fore Green "Working on NTP"
	Add-VMhostNtpserver -vmhost $h -ntpserver $ntpServer
	Get-VMHostFirewallException  -vmh $h | where {$_.name -like "*NTP Client*" } | Set-VMHostFirewallException -Enabled:$true
	Get-VMHostService -vmhost $h | Where {$_.key -eq "ntpd"} | Start-VMHostService
	Get-VMHostService -vmhost $h | Where {$_.key -eq "ntpd"} | Set-VMHostService -policy 'on'


	Write-Host -Fore Green "Working on Networking"	
	##Basic vSwitch (vSS) Configuration
	$vs = get-virtualswitch -name vSwitch0 -vmhost $h

	#Add vmnic1 to the vSwitch0 so it has two uplinks
	$pNic1 = $h | Get-VMHostNetworkAdapter -Physical -Name vmnic1

	$vswitch = Get-VirtualSwitch -VMHost $h -Standard -Name "vSwitch0"
	$vswitch | Add-VirtualSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $pNic1 -Confirm:$false

	#Add vmkernel ports for vmotion and virtual SAN
	$matches = Select-String -InputObject $h.Name -Pattern 'esx-(\d+)(a|b).corp.local'
	$hostNum = [int]$matches.Matches[0].Groups[1].value
	$hostSite = $matches.Matches[0].Groups[2].value
		
	$hostID = 50 + $hostNum
	$storageIP = '10.00.20.' + $hostID
	$vmotionIP = '10.00.30.' + $hostID
	$vmotionGW = '10.00.30.1'

	If( $hostSite -eq 'a' ) {
		$storageIP = $storageIP.Replace('00','10')
		$vmotionIP = $vmotionIP.Replace('00','10')
		$vmotionGW = $vmotionGW.Replace('00','10')
	} Else {
		$storageIP = $storageIP.Replace('00','20')
		$vmotionIP = $vmotionIP.Replace('00','20')
		$vmotionGW = $vmotionGW.Replace('00','20')
	}
	
	#vmk1 is vmotion
	#This command uses the default IP stack in ESXi
	#New-VMhostNetworkAdapter -vmhost $h -portgroup $($hn +"_vmotion") -IP $vmotionIP -subnetmask 255.255.255.0 -virtualswitch $vs -vmotionenabled:$true -confirm:$false
	#This block creates the vmk1 interface on the 'vmotion' IP stack
	$vmotion_pg = New-VirtualPortGroup -Name $($hn +"_vmotion") -VirtualSwitch $vswitch
	$nic = New-Object VMware.Vim.HostVirtualNicSpec
	$nic.Portgroup = $vmotion_pg
	$nic.netStackInstanceKey = 'vmotion'

	$ip = New-Object VMware.Vim.HostIpConfig
	$ip.dhcp = $false
	$ip.ipAddress = $vmotionIP
	$ip.subnetMask = '255.255.255.0'
	$nic.Ip = $ip

	$networkSystem = $h.ExtensionData.configManager.NetworkSystem
	$theHostNetworkSystem = Get-view -Id ($networkSystem.Type + "-" + $networkSystem.Value)
	$theHostNetworkSystem.AddVirtualNic($vmotion_pg.name, $nic)

	#Set the default route for the vmotion stack
	$esxcli = Get-EsxCli -VMHost $h
	$esxcli.network.ip.route.ipv4.add($vmotionGW,'vmotion','default')
	
	#vmk2 is VSAN, flag it for VSAN traffic	
	New-VmHostNetworkAdapter -vmhost $h -portgroup $($hn +"_storage") -IP $storageIP -subnetmask 255.255.255.0 -virtualswitch $vs -vsantrafficenabled $true -confirm:$false

	Write-Host -Fore Green "Working on Advanced Settings"	
	Get-AdvancedSetting -Entity $h -Name 'Syslog.loggers.*.rotate' | Set-AdvancedSetting -Value 2 -Confirm:$false | Out-Null
	Foreach ($setting in $esxSettings.Keys) { 
		Get-AdvancedSetting -Entity $h -name $setting | Set-AdvancedSetting -Value $($esxSettings[$setting]) -Confirm:$false | Out-Null
	}
	
	## Configure the LUNs for VSAN (assume all 'SSD' devices are the same size
	if( Get-Module HOL-SCSI ) {
		Write-Host -Fore Green "Working on Storage"
		Get-SCSILun | where {$_.CapacityGB -eq $vsanSsdSize} | Set-ScsiLunFlags | Out-Null
		Get-SCSILun | where {$_.CapacityGB -eq $vsanHddSize} | Set-ScsiLunFlags -ExplicitHDD | Out-Null
		
		Get-SCSILun | Get-ScsiLunFlags
	} else {
		Write-Host -Fore Yellow "No PS module HOL-SCSI loaded, not flagging devices"
	}
	
	Write-Host -Fore Green "Enter Maintenance Mode"
	$h | Set-VMhost -State Maintenance
	
	Write-Host -Fore Green "Finished with host $hostname"
	Disconnect-VIserver * -Confirm:$false
} #Foreach Host

### END ###
