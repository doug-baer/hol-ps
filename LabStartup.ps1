##############################################################################
##
## LabStartup.ps1, v3.1, November 2014 (Win 2012 version) 
##
##############################################################################
<#
.SYNOPSIS
	Performs various tasks to ensure that a vPod is "Ready" to run:
		Connects to vCenter
		Powers up VMs
		Waits for availability of services on TCP ports or via URLs
		Records progress into a file for consumption by DesktopInfo
		
		NEW: v3 modifies 6th NIC on vpodrouter to report status to vCD

.DESCRIPTION

.PARAMETER
	None

.EXAMPLE
	LabStartup.ps1

.EXAMPLE
	C:\WINDOWS\system32\windowspowershell\v1.0\powershell.exe -windowstyle hidden "& 'c:\LabStartup.ps1'"

.INPUTS
	None - modify parameters in User Variables section

.OUTPUTS
	Modifies file identified by $statusFile with incremental status text

.NOTES
	Tested with PowerCLI version 5.1 update 2 and Powershell 2
	
	The format of the TCPServices entries is "server:port_number"
	
	URLs must begin with http:// or https:// (with valid certificate)
	
.LINK
	http://blogs.vmware.com/hol
#>

##############################################################################
##### User Variables
##############################################################################
##############################################################################
##### User Variables
##############################################################################
$startTime = $(Get-Date)
$vcserver = "vcsa-01a.corp.local"
$vcuser = 'CORP\Administrator'
$password = 'VMware1!'
$linuxuser = 'root'
$linuxpassword = 'VMware1!'
$statusFile = "C:\HOL\startup_status.txt"
$sleepSeconds = 10
$maxMinutesBeforeFail = 30 # if still running this long, fail the pod
$result = 'fail'
$desktopInfo = 'C:\DesktopInfo\desktopinfo.ini'
Write-Output "$startTime beginning LabStartup"

### Populate the following arrays with values appropriate to your lab

# Test ESXi hosts are responding on port 22 (enable SSH on all HOL vESXi hosts)
$ESXiHosts = @(
	'esx-01a.corp.local:22'
	'esx-02a.corp.local:22'
	)

#Windows Services to be checked / started
$WINservices = @(
#	'controlcenter.corp.local:VMTools'
)

#Linux Services to be checked / started
$LINservices = @(
#	'router.corp.local:vmware-tools'
)

#Virtual Machines to be powered on
$VMs = @(
	'base-sles-01a'
	)

#TCP Ports to be checked (host listens on port)
$TCPservices = @(
	'esx-01a.corp.local:22'
	'esx-02a.corp.local:22'
	)

#URLs to be checked for specified text in response
$URLs = @{
	'https://vcsa-01a.corp.local:9443/vsphere-client/' = 'vSphere Web Client'
	'http://stga-01a.corp.local/account/login' = 'FreeNAS'
	}

#Remove the file that causes a "reset" message in Firefox (2012 CC path)
$ff="C:\Users\Administrator\AppData\Roaming\Mozilla\Firefox\Profiles\5qs0vngr.default\parent.lock" 
If(Test-Path $ff) { Remove-Item $ff | Out-Null }

##############################################################################
# REPORT VPOD status
##############################################################################
If( Test-Path $desktopInfo ) {
	# read the desktopInfo.ini configuration file and find the line that begins with "HEADER=active:1"
	$TMP = Select-String $desktopInfo -pattern "^HEADER=active:1"
	# split the line on the ":"
	$TMP = $TMP.Line.Split(":")
	# split the last field on the "-"
	$TMP = $TMP[4].Split("-")
	# the YEAR is the first two characters of the last field as an integer
	$YEAR = [int]$TMP[2].SubString(0,2)
	# the SKU is the rest of the last field beginning with the third character as an integer (no leading zeroes)
	$SKU = [int]$TMP[2].SubString(2)
	$IPNET = "192.$YEAR.$SKU"
} Else {
	# Something went wrong. Use the default IP network.
	$IPNET= '192.168.250'
}
$statusTable = @{
 'STARTING' = 1
 'TIMEOUT'  = 2
 'GOOD-1'   = 3
 'GOOD-2'   = 4
 'GOOD-3'   = 5
 'GOOD-4'   = 6
 'GOOD-5'   = 7
 'FAIL-1'   = 103
 'FAIL-2'   = 104
 'FAIL-3'   = 105
 'FAIL-4'   = 106
 'FAIL-5'   = 107
 'READY'    = 200
 'AUTOLAB'  = 201
}

Function Report-VpodStatus ([string] $newStatus) {
  $server = 'router.corp.local'
  $newStatus = "$IPNET." + $statusTable[$newStatus]
  $bcast = "$IPNET." + "255"
  #replace the IP address on the vpodrouter's 6th NIC with our indicator code
  $lcmd = "sudo /sbin/ifconfig eth5 broadcast $bcast netmask 255.255.255.0 $newStatus"
  #Write-Host $lcmd
  $msg = Invoke-Plink -remoteHost $server -login holuser -passwd $linuxpassword -command '$lcmd'
  $currentStatus = $newStatus

} # END Report-VpodStatus

##############################################################################

Function Write-Progress ([string] $msg, [string] $code) {
	$myTime = $(Get-Date)
	If( $code -eq 'READY' ) {
		$dateCode = "{0:D2}/{1:D2} {2:D2}:{3:D2}" -f $myTime.month,$myTime.day,$myTime.hour,$myTime.minute
		Set-Content -Value "$msg $dateCode" -Path $statusFile
	} Else {
		$dateCode = "{0:D2}:{1:D2}" -f $myTime.hour,$myTime.minute
		Set-Content -Value "$dateCode $msg " -Path $statusFile
	}
	Report-VpodStatus $code
}#End Write-Progress

##############################################################################

#Load the VMware PowerCLI tools
Try {
  Add-PSSnapin VMware.VimAutomation.Core -ErrorAction 1 
} 
Catch {
  Write-Host "No PowerCLI found, unable to continue."
  Write-Progress "FAIL-No PowerCLI" 'FAIL-1'
  Exit
}

##############################################################################
##### Support Functions
##############################################################################
Function Connect-VC ([string]$server, [string]$username, [string]$password, [REF]$result) {
<#
	This function attempts once to connect to the specified vCenter 
	It sets the $result variable to 'success' or 'fail' based on the result
#>
	Try {
		Connect-ViServer -server $server -username $username -password $password -ea 1
		Write-Host "Connection Successful"
		$result.value = "success"
	}
	Catch {
		Write-Host "Failed to connect to server $server"
#		Write-Host $_.Exception.Message
		$result.value = "fail"
	}
}#End Connect

Function Test-TcpPortOpen ([string]$server, [int]$port, [REF]$result) {
<#
	This function makes sure a host is listening on the specified port
	It does not attempt to validate anything beyond a simple response
	It sets the $result variable to 'success' or 'fail' based on the result
#>
	Try {
		$socket = New-Object Net.Sockets.TcpClient
		$socket.Connect($server,$port)
		if($socket.Connected) { 
			Write-Host "Successfully connected to server $server on port $port"
			$result.value = "success"
		}
	}
	Catch {
		Write-Host "Failed to connect to server $server on port $port"
		$result.value = "fail"
	}
}#End Test-TcpPortOpen

Function Test-URL ([string]$url, [string]$lookup, [REF]$result) {
<#
	This function tries to access the specified URL and looks for the string
	specified in the resulting HTML
	It sets the $result variable to 'success' or 'fail' based on the result 
#>
	Try {
		$wc = (New-Object Net.WebClient).DownloadString($url)
		If( $wc -match $lookup ) {
			Write-Output "Successfully connected to $url"
			$result.value = "success"
		} Else {
			Write-Output "Connected to $url but lookup ( $lookup ) did not match"
			$result.value = "fail"
		}
	}
	Catch {
		Write-Output "URL $url not accessible"
		$result.value = "fail"
	}
} #End Test-URL

#### Manage Windows Services ####
Function Start-WindowsService ([string]$server, [string]$service, [int]$waitsec, [REF]$result) {
<#
	This function restarts the specified Windows service on the specified server
	The service must report "Running" within $waitsec seconds or the function 
	reports 'fail'
#>
	Try {
		Start-Service -InputObject (Get-Service -ComputerName $server -Name $service)
		LabStartup-Sleep $waitsec
		$svc = Get-service -computerName $server -name $service
		If($svc.Status -eq "Running") {
			$result.value = "success" 
		}
	}
	Catch {
		Write-Host "Failed to restart $service on $server"
		$result.value = "fail"
	}
} #End Start-WindowsService

Function Restart-WindowsService ([string]$server, [string]$service, [int]$waitsec, [REF]$result) {
<#
	This function restarts the specified Windows service on the specified server
	The service must report "Running" within $waitsec seconds or the function 
	reports 'fail'
#>
	Try {
		Restart-Service -InputObject (Get-Service -ComputerName $server -Name $service)
		LabStartup-Sleep $waitsec
		$svc = Get-service -computerName $server -name $service
		If($svc.Status -eq "Running") {
			$result.value = "success" 
		}
	}
	Catch {
		Write-Host "Failed to restart $service on $server"
		$result.value = "fail"
	}
} #End Restart-WindowsService

Function Stop-WindowsService ([string]$server, [string]$service, [int]$waitsec, [REF]$result) {
<#
	This function stops the specified Windows service on the specified server
	The service must report "Stopped" within the $waitsec seconds or the function 
	reports 'fail'
#>
	Try {
		Stop-Service -InputObject (Get-Service -ComputerName $server -Name $service)
		LabStartup-Sleep $waitsec
		$svc = Get-Service -ComputerName $server -name $service
		If($svc.Status -eq "Stopped") {
			$result.value = "success" 
		}
	}
	Catch {
		Write-Host "Failed to stop $service on $server"
		$result.value = "fail"
	}
} #End Stop-WindowsService

Function Query-WindowsService ([string]$server, [string]$service, [REF]$result) {
<#
	This function returns the current running state of a Windows service
#>
	Try {
		$svc = Get-Service -ComputerName $server -name $service
		$result.value = 'success'
		return $svc.Status 
	}
	Catch {
		Write-Host "Failed to query $service on $server"
		$result.value = "fail"
	}
} #End Query-WindowsService

Function Invoke-Plink ([string]$remoteHost, [string]$login, [string]$passwd, [string]$command) {
<#
	This function executes the specified command on the remote host via SSH
#>
	Invoke-Expression "Echo Y | c:\hol\plink.exe -ssh $remoteHost -l $login -pw $passwd $command"
} #End Invoke-Plink

Function Invoke-PlinkKey ([string]$puttySession, [string]$command) {
<#
	This function executes the specified command on the remote host via SSH
	utilizing key-based authentication and a saved PuTTY session
	Rather than a username/password combination
#>
	Invoke-Expression "Echo Y | c:\hol\plink.exe -ssh -load $puttySession $command"
} #End Invoke-PlinkKey

#### Manage Linux Services ####
Function Start-LinuxService ([string]$server, [string]$service, [int]$waitsec, [REF]$result) {
<#
	This function starts the specified service on the specified server
	The service must start within $waitsec seconds or the function reports 'fail'
#>
	$lcmd1 = "service $service start"
	$lcmd2 = "service $service status"
	Try {
		$msg = Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmd1
		LabStartup-Sleep $waitsec
		$msg = Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmd2
		if( $msg -like "* is running" ) {
			$result.value = "success"
		}
	}
	Catch {
		Write-Host "Failed to start $service on $server : $msg"
		$result.value = "fail"
	}
} #Start-LinuxService

Function Restart-LinuxService ([string]$server, [string]$service, [int]$waitsec, [REF]$result) {
<#
	This function restarts the specified service on the specified server
	The service must restart within $waitsec seconds or the function reports 'fail'
#>
	$lcmd1 = "service $service restart"
	$lcmd2 = "service $service status"
	Try {
		$msg = Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmd1
		LabStartup-Sleep $waitsec
		$msg = Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmd2
		if( $msg -like "* is running" ) {
			$result.value = "success"
		}
	}
	Catch {
		Write-Host "Failed to restart $service on $server"
		$result.value = "fail"
	}
} #Restart-LinuxService

Function Stop-LinuxService ([string]$server, [string]$service, [int]$waitsec, [REF]$result) {
<#
	This function stops the specified service on the specified server
	The service must stop within $waitsec seconds or the function reports 'fail'
#>
	$lcmd1 = "service $service stop"
	$lcmd2 = "service $service status"
	Try {
		$msg = Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmd1
		LabStartup-Sleep $waitsec
		$msg = Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmd2
		if( $msg -like "* is not running" ) {
			$result.value = "success"
		}
	}
	Catch {
		Write-Host "Failed to stop $service on $server : $msg"
		$result.value = "fail"
	}
} #Stop-LinuxService

Function Query-LinuxService ([string]$server, [string]$service, [REF]$result) {
<#
	This function returns the current state of the service on the specified server
#>
	$lcmd1 = "service $service status"
	Try {
		$msg = Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmd1
		if( $msg -like "* is not running" ) {
			$result.value = "success"
		return "Stopped"
		}
		if( $msg -like "* is running" ) {
			$result.value = "success"
		return "Running"
		}
	}
	Catch {
		Write-Host "Failed to query $service on $server : $msg"
		$result.value = "fail"
	}
} #Query-LinuxService


#### FOR TESTING ####

Function Start-AutoLab () {
<#
	Please leave this function here to enable scale testing automation:
	If there is media in the CD/DVD drive and it contains "autolab.ps1"
	run that script - enables vpod automation for scale testing
#>
	$cd = (Get-WmiObject win32_LogicalDisk -filter 'DriveType=5')|%{$_.DeviceID}
	If( $cd ) {
		Write-Host "Testing $cd\autolab.ps1"
		If( Test-Path -Path "$cd\autolab.ps1" ) {
			Write-Host "Executing $cd\autolab.ps1"
			Write-Progress "Ready: Executing $cd\autolab.ps1" 'AUTOLAB'
			Start-Process powershell -ArgumentList "-command $cd\autolab.ps1"
			Write-Host "Finished with $cd\autolab.ps1"
			Write-Progress "Finished with $cd\autolab.ps1" 'AUTOLAB'
			return $TRUE
		}
	}
	return $FALSE
} #End Start-AutoLab

Function Get-RuntimeSeconds ( [datetime]$start ) {
<#
  Calculate and return number of seconds since $start
#>
	$runtime = $(get-date) - $start
	return $runtime.TotalSeconds
} #End Get-RuntimeSeconds

Function LabStartup-Sleep ( [int] $sleepSecs ) {
<#
  Each sleep is an opportunity to check for TIMEOUT and act appropriately 
#>
  $currentRunningSeconds = Get-RuntimeSeconds $startTime
  $currentRunningMinutes = $currentRunningSeconds / 60
  If( $currentRunningMinutes -gt $maxMinutesBeforeFail ) {
    Write-Progress "FAIL - TIMEOUT" 'TIMEOUT'
    Write-Output $("FAILURE: labStartup ran for {0:N0} minutes and has been terminated."  -f $currentRunningMinutes )
    Exit
  } Else {
    If( ([int]$currentRunningSeconds % 10) -lt 3 ) {
      #throttle the number of messages a little
      Write-Output $("Labstartup has been running for {0:N0} minutes." -f $currentRunningMinutes )
    }
    Start-Sleep -sec $sleepSecs
  }
} #End LabStartup-Sleep

##############################################################################
##### Main Script - Base vPod
##############################################################################

#Please leave this line here to enable scale testing automation 
If( Start-AutoLab ) { exit } Write-Host "No autolab.ps1 found, continuing."

#ATTENTION: Remove the next two lines when you implement this script for your pod
Set-Content -Value "Not Implemented" -Path $statusFile
exit

#Report Initial State
Write-Output "Beginning Main script"
Write-Progress "Not Ready" 'STARTING'


##############################################################################
##### Lab Startup - STEP #1 (Infrastructure) 
##############################################################################

#Testing vESXi hosts are online
Write-Progress "Checking vESXi" 'STARTING'
Foreach ($ESXihost in $ESXiHosts) {
	($server,$port) = $ESXiHost.Split(":")
	$result = "fail"
	while ($result -eq "fail" ) { 
		Test-TcpPortOpen $server $port ([REF]$result)
		LabStartup-Sleep $sleepSeconds
	}
}

Write-Progress "Connecting vCenter" 'STARTING'
#reset the result
$result = 'fail'
While ($result -eq "fail" ) { 
	Connect-VC $vcserver $vcuser $password ([REF]$result)
	LabStartup-Sleep $sleepSeconds
}


##############################################################################
##### Lab Startup - STEP #2 (Starting vVMs) 
##############################################################################

Write-Progress "Starting vVMs" 'STARTING'

# Start the nested VMs - wait for each vVM to report 'PoweredOn'
Foreach ($vmName in $VMs) {
	$vm = Get-VM $vmName
	$powerState = [string]$vm.PowerState
	While ( !($powerState.Contains("PoweredOn")) ) {
		Write-Host "Starting VM" $vm.name
		$vm | Start-VM -RunAsync
	LabStartup-Sleep $sleepSeconds
	$vm = Get-VM $vmName
	$powerState = [string]$vm.PowerState
	}
}

Write-Output "$(Get-Date) disconnecting from $vcserver ..."
Disconnect-VIServer -Confirm:$false

##############################################################################
##### Lab Startup - STEP #3 (Testing Ports & Services) 
##############################################################################

Write-Progress "Testing TCP ports" 'GOOD-1'

#Testing services are answering on TCP ports 
Foreach ($service in $TCPservices) {
	($server,$port) = $service.Split(":")
	$result = "fail"
	while ($result -eq "fail" ) { 
		Test-TcpPortOpen $server $port ([REF]$result)
		LabStartup-Sleep $sleepSeconds
	}
}

Write-Progress "Checking URLs" 'GOOD-2'

#Testing URLs
Foreach ($url in $($URLs.Keys)) {
	$result = "fail"
	while ($result -eq "fail" ) { 
		Test-URL $url $URLs[$url] ([REF]$result)
		LabStartup-Sleep $sleepSeconds
	}
}

##############################################################################
##### Lab Startup - STEP #4 (Start/Restart Services) 
##############################################################################

Write-Progress "Manage Win Svcs" 'GOOD-3'

# Restart Windows services on remote machines
Foreach ($service in $WINservices) {
	($wserver,$wservice) = $service.Split(":")
	Write-Output "Restarting $wservice on $wserver"
	$result = "fail"
	$waitSecs = '30' # seconds to wait for service startup
	while ($result -eq "fail") {
		Restart-WindowsService $wserver $wservice $waitSecs ([REF]$result)
	}
}

Write-Output "$(Get-Date) Finished Restart-WinServices"

Write-Progress "Manage Linux Svcs" 'GOOD-3'

# Restart Linux services on remote machines
Foreach ($service in $LINservices) {
	($lserver,$lservice) = $service.Split(":")
	write-output "Restarting $lservice on $lserver"
	$result = "fail"
	$waitSecs = '30' # seconds to wait for service startup
	while ($result -eq "fail") {
		Restart-LinuxService $lserver $lservice $waitSecs ([REF]$result)
	}
}

Write-Output "$(Get-Date) Finished Restart-LinuxServices"

## Any final checks here. Maybe you need to check something after the
## services are started/restarted.

#Report Final State
Write-Progress "Ready" 'READY'
Write-Output "$(Get-Date) LabStartup Finished"

##############################################################################
