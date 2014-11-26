##############################################################################
##
## LabStartup.ps1, v3.5, November 25, 2014 (unified version) 
##
##############################################################################
<#
.SYNOPSIS
Performs various tasks to ensure that a vPod is ready to run, and then provides 
feedback to the user (via DesktopInfo) and management system via vpodrouter NIC.

.DESCRIPTION
Connects to vCenter, Powers up vVMs, waits for availability of services on TCP 
ports or via URLs. Records progress into a file for consumption by DesktopInfo. 
Modifies 6th NIC on vpodrouter to report status to vCD

.EXAMPLE
LabStartup.ps1
Call it like this from a .BAT file: C:\WINDOWS\system32\windowspowershell\v1.0\powershell.exe -windowstyle hidden "& 'c:\HOL\LabStartup.ps1'"

.INPUTS
No inputs

OUTPUTS
Status messages are written to the console or output file and the C:\HOL\startup_status.txt ($statusFile) is updated with periodic status for consumption by DesktopInfo.exe. 
In addition, the IP address of the 6th NIC on the vpodrouter (router.corp.local) is modified 
with an encoded status code as the script progresses.

.NOTES
The format of the TCPServices and ESXiHosts entries is "server:port_number"
URLs must begin with http:// or https:// (with valid certificate)
The IP address on the NIC of the vpodrouter is set using SSH (plink.exe) and sudo 
(installed on the router) using the holuser account. 

#>

$startTime = $(Get-Date)
Write-Output "$startTime beginning LabStartup"

##############################################################################
##### User Variables
##############################################################################

# Credentials used to login to vCenters
$vcuser = 'CORP\Administrator'
$password = 'VMware1!'

# Credentials used to login to Linux machines
$linuxuser = 'root'
$linuxpassword = 'VMware1!'

$statusFile = "C:\HOL\startup_status.txt"
# sleep time between checks
$sleepSeconds = 10
# if still running this long, fail the pod
$maxMinutesBeforeFail = 30
# path to the DesktopInfo config -- used to get the lab SKU
$desktopInfo = 'C:\DesktopInfo\desktopinfo.ini'
# path to Plink.exe -- for status & managing Linux
$plinkPath = 'C:\hol\plink.exe'

### Populate the following with values appropriate to your lab

$vCenters = @(
	'vcsa-01a.corp.local'
)
# Test ESXi hosts are responding on port 22
# be sure to enable SSH on all HOL vESXi hosts
$ESXiHosts = @(
	'esx-01a.corp.local:22'
	'esx-02a.corp.local:22'
	)

#Windows Services to be checked / started
$windowsServices = @(
	'controlcenter.corp.local:VMTools'
)

#Linux Services to be checked / started
$linuxServices = @(
	'router.corp.local:vmware-tools'
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

#Remove the file that causes a "Reset" message in Firefox
$userProfilePath = (Get-Childitem env:UserProfile).Value
$firefoxProfiles = Get-ChildItem (Join-Path $userProfilePath 'AppData\Roaming\Mozilla\Firefox\Profiles')
ForEach ($firefoxProfile in $firefoxProfiles) {
	$firefoxLock = Join-Path $firefoxProfile.FullName 'parent.lock'
	If(Test-Path $firefoxLock) { Remove-Item $firefoxLock | Out-Null }
}
##############################################################################
# REPORT VPOD status
##############################################################################
$statusTable = @{
 'GOOD-1'   = 1
 'GOOD-2'   = 2
 'GOOD-3'   = 3
 'GOOD-4'   = 4
 'GOOD-5'   = 5
 'FAIL-1'   = 101
 'FAIL-2'   = 102
 'FAIL-3'   = 103
 'FAIL-4'   = 104
 'FAIL-5'   = 105
 'READY'    = 200
 'AUTOLAB'  = 201
 'STARTING' = 202
 'TIMEOUT'  = 203
}

Function Invoke-Plink ([string]$remoteHost, [string]$login, [string]$passwd, [string]$command) {
<#
	This function executes the specified command on the remote host via SSH
#>
	Invoke-Expression "Echo Y | $plinkPath -ssh $remoteHost -l $login -pw $passwd $command"
} #End Invoke-Plink

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

If( Test-Path $desktopInfo ) {
	# read the desktopInfo.ini configuration file and find the line that begins with "HEADER=active:1"
	$TMP = Select-String $desktopInfo -pattern "^HEADER=active:1"
	# split the line on the ":"
	$TMP = $TMP.Line.Split(":")
	# split the last field on the "-"
	$TMP = $TMP[4].Split("-")
	Try {
	# the YEAR is the first two characters of the last field as an integer
		$YEAR = [int]$TMP[2].SubString(0,2)
		# the SKU is the rest of the last field beginning with the third character as an integer (no leading zeroes)
		$SKU = [int]$TMP[2].SubString(2)
		$IPNET = "192.$YEAR.$SKU"
	} 
	Catch {
		# Problems: Use the default IP network and FAIL
		Write-Output "Lab SKU parsing Failure: $TMP"
		$IPNET= '192.168.250'
		# fail the script 
		Write-Progress "FAIL-Bad Lab SKU" 'FAIL-1'
		Exit
	}
} Else {
	# Something went wrong. Use the default IP network and FAIL
	$IPNET= '192.168.250'
	Write-Progress "FAIL-No DesktopInfo" 'FAIL-1'
	Exit
}

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

Function ManageWindowsService ([string] $action, [string]$server, [string]$service, [int]$waitsec, [REF]$result) {
<#
	This function performs an action (start/stop/restart/query) on the specified Windows service on the specified server
	The service must report within $waitsec seconds or the function reports 'fail'
#>
	Try {
	    If( $action -eq "start" ) {
		  Start-Service -InputObject (Get-Service -ComputerName $server -Name $service)
		} ElseIf ( $action -eq "restart" ) {
		  Restart-Service -InputObject (Get-Service -ComputerName $server -Name $service)
		} ElseIf ( $action -eq "stop" ) {
		  Stop-Service -InputObject (Get-Service -ComputerName $server -Name $service)
		} Else {  # query option
		  $svc = Get-Service -ComputerName $server -name $service
		  $result.value = 'success'
		  return $svc.Status
		}
		LabStartup-Sleep $waitsec
		$svc = Get-service -computerName $server -name $service
		If (( $action -eq "start" ) -or ( $action -eq "restart")) {
		  If($svc.Status -eq "Running") {
			$result.value = "success" 
		  }
		} ElseIf ( $action -eq "stop" ) {
		  If($svc.Status -eq "Stopped") {
			$result.value = "success" 
		  }
		}
	}
	Catch {
		Write-Host "Failed to $action $service on $server"
		$result.value = "fail"
	}
} #End ManageWindowsService

Function Invoke-PlinkKey ([string]$puttySession, [string]$command) {
<#
	This function executes the specified command on the remote host via SSH
	utilizing key-based authentication and a saved PuTTY session name rather than 
	a username/password combination
#>
	Invoke-Expression "Echo Y | $plinkPath -ssh -load $puttySession $command"
} #End Invoke-PlinkKey


Function ManageLinuxService ([string]$action, [string]$server, [string]$service, [int]$waitsec, [REF]$result) {
<#
	This function manages (start/stop/restart/query) the specified service on the specified server
	The service must respond within $waitsec seconds or the function reports 'fail'
#>
	$lcmd1 = "service $service $action"
	$lcmd2 = "service $service status"
	Try {
		If ($action -ne "query") {
			$msg = Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmd1
			LabStartup-Sleep $waitsec
		}
		$msg = Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmd2
		If (( $action -eq "start" ) -or ( $action -eq "restart") -or ( $action -eq "query" )) {
			If( $msg -like "* is running" ) {
				$result.value = "success"
				If ($action -eq "query") { Return "Running" }
			}
		} ElseIf (( $action -eq "stop" ) -or ( $action -eq "query" )) {
				If( $msg -like "* is not running" ) {
					$result.value = "success"
					If ($action -eq "query") { Return "Stopped" }
				}
		}
	}
	Catch {
		Write-Host "Failed to $action $service on $server : $msg"
		$result.value = "fail"
	}
} #ManageLinuxService


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
			Return $TRUE
		}
	}
	Return $FALSE
} #End Start-AutoLab

Function Get-RuntimeSeconds ( [datetime]$start ) {
<#
  Calculate and return number of seconds since $start
#>
	$runtime = $(get-date) - $start
	Return $runtime.TotalSeconds
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
Exit

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
	Do {
		Test-TcpPortOpen $server $port ([REF]$result)
		LabStartup-Sleep $sleepSeconds
	} Until ($result -eq "success")
}

Write-Progress "Connecting vCenter" 'STARTING'
Foreach ($vcserver in $vCenters) {
	Do {
		Connect-VC $vcserver $vcuser $password ([REF]$result)
		LabStartup-Sleep $sleepSeconds
	} Until ($result -eq "success")
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
	Do { 
		Test-TcpPortOpen $server $port ([REF]$result)
		LabStartup-Sleep $sleepSeconds
	} Until ($result -eq "success")
}

Write-Progress "Checking URLs" 'GOOD-2'

#Testing URLs
Foreach ($url in $($URLs.Keys)) {
	Do { 
		Test-URL $url $URLs[$url] ([REF]$result)
		LabStartup-Sleep $sleepSeconds
	} Until ($result -eq "success")
}

##############################################################################
##### Lab Startup - STEP #4 (Start/Restart/Stop/Query Services) 
##############################################################################

Write-Progress "Manage Win Svcs" 'GOOD-3'

# options are "start", "restart", "stop" or "query"
$action = "query"
# Manage Windows services on remote machines
Foreach ($service in $windowsServices) {
	($wserver,$wservice) = $service.Split(":")
	Write-Output "Performing $action $wservice on $wserver"
	$waitSecs = '30' # seconds to wait for service startup/shutdown
	Do {
		$status = ManageWindowsService $action $wserver $wservice $waitSecs ([REF]$result)
		Write-Host "status is" $status
	} Until ($result -eq "success")
}

Write-Output "$(Get-Date) Finished $action Windows services"

Write-Progress "Manage Linux Svcs" 'GOOD-3'

# options are "start", "restart", "stop" or "query"
$action = "query"
# Manage Linux services on remote machines
Foreach ($service in $linuxServices) {
	($lserver,$lservice) = $service.Split(":")
	Write-Output "Performing $action $lservice on $lserver"
	$waitSecs = '30' # seconds to wait for service startup/shutdown
	Do {
		$status = ManageLinuxService $action $lserver $lservice $waitSecs ([REF]$result)
		Write-Host "status is" $status
	} Until ($result -eq "success")
}

Write-Output "$(Get-Date) Finished $action Linux services"

## Any final checks here. Maybe you need to check something after the
## services are started/restarted.

#Report Final State
Write-Progress "Ready" 'READY'
Write-Output "$(Get-Date) LabStartup Finished"

##############################################################################
