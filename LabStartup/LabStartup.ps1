<#

.SYNOPSIS
Performs various tasks to ensure that a vPod is ready to run, and then provides 
feedback to the user (via DesktopInfo) and management system via vpodrouter NIC.

.DESCRIPTION
Connects to vCenter, Powers up vVMs, waits for availability of services on TCP 
ports or via URLs. Records progress into a file for consumption by DesktopInfo. 
Modifies 6th NIC on vpodrouter to report status to vCD

.NOTES
LabStartup.ps1 v3.8.1 - January 7, 2015 (unified version) 
* The format of the TCPServices and ESXiHosts entries is "server:port_number"
* URLs must begin with http:// or https:// (with valid certificate)
* The IP address on the NIC of the vpodrouter is set using SSH (plink.exe) 
  and sudo (installed on the router) using the holuser account. 


.EXAMPLE
LabStartup.ps1
.EXAMPLE
C:\WINDOWS\system32\windowspowershell\v1.0\powershell.exe -windowstyle hidden "& 'c:\HOL\LabStartup.ps1'"

.INPUTS
No inputs

.OUTPUTS
Status messages are written to the console or output file and the C:\HOL\startup_status.txt ($statusFile) is updated with periodic status for consumption by DesktopInfo.exe. 
In addition, the IP address of the 6th NIC on the vpodrouter (router.corp.local) is modified 
with an encoded status code as the script progresses.

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
# number of minutes it takes vCenter to boot before API connection
$vcBootMinutes = 10
# number of minutes it takes for vSphere Web Client URL
$ngcBootMinutes = 15
# if still running this long, fail the pod
$maxMinutesBeforeFail = 30
# path to the DesktopInfo config -- used to get the lab SKU
$desktopInfo = 'C:\DesktopInfo\desktopinfo.ini'
# path to Plink.exe -- for status & managing Linux
$plinkPath = 'C:\hol\Tools\plink.exe'
#must be defined in order to pass as reference for looping
$result = ''

### Populate the following with values appropriate to your lab

#FQDN of vCenter server(s)
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

$vApps = @(
#	'example vApp:vcsa-01a.corp.local'
)

#Virtual Machines to be powered on
# if multiple vCenters, specify the FQDN of the owning vCenter after the colon
# optionally indicate a pause with the "Pause" record.  In this case the number after the colon is the seconds to pause.
$VMs = @(
	'base-sles-01a'
#	'Pause:30'
#	'full-sles-01a:vcsa-01a.corp.local'
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

# IP addresses to be pinged
$Pings = @(
	'192.168.110.1'
)

#Remove the file that causes a "Reset" message in Firefox
$userProfilePath = (Get-Childitem env:UserProfile).Value
$firefoxProfiles = Get-ChildItem (Join-Path $userProfilePath 'AppData\Roaming\Mozilla\Firefox\Profiles')
ForEach ($firefoxProfile in $firefoxProfiles) {
	$firefoxLock = Join-Path $firefoxProfile.FullName 'parent.lock'
	If(Test-Path $firefoxLock) { Remove-Item $firefoxLock | Out-Null }
}

##############################################################################
# REPORT VPOD status codes
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

# starts the nested VMs or vApps
Function Start-Nested ( [array] $records ) {

	If ($records -eq $null ) { 
		Write-Host " no records! "
		Return
	}

	ForEach ($record in $records) {
		# separate out the vVM name and the owning vCenter
		($name,$vcenter) = $record.Split(":")
		# If blank, default to the first/only vCenter
		If ( $vcenter -eq $null ) { $vcenter = $vCenters[0] }
		If ( $name -eq "Pause" ) {
		    Write-Host "Pausing for $vcenter seconds..."
			LabStartup-Sleep $vcenter
			Continue
		}
		
		If( $vApp = Get-VApp -Name $name -Server $vcenter -ea 0 ) {
			$type = "vApp"
			$entity = $vApp
			$powerState = [string]$vApp.Status
			$goodPower = "Started"
		} ElseIf( $vm = Get-VM -Name $name -Server $vcenter -ea 0 ) {
			$type = "vVM"
			$entity = $vm
			$powerState = [string]$vm.PowerState
			$goodPower = "PoweredOn"
		} Else {
			Write-Output $("ERROR: Unable to find entity {0} on {1}" -f $name, $vcenter )
			Continue
		}
		
		Write-Output $("Checking {0} {1} power state: {2}" -f $type, $name, $powerState )
		While ( !($powerState.Contains($goodPower)) ) {
			If ( !($powerState.Contains("Starting")) ) {
				Write-Output $("Starting {0} {1} on {2}" -f $type, $name, $vcenter )
				If ( $type -eq "vVM" ) {
					$task = Start-VM $entity -RunAsync -Server $vcenter
					$tasks = Get-Task -Server $vcenter
					ForEach ($task in $tasks) {
						If ($task.ObjectId -eq $vm.Id) { Break }
					}
				} Else {
					$task = Start-VApp $entity -RunAsync -Server $vcenter
				}
			}
			LabStartup-Sleep $sleepSeconds
			$task = Get-Task -Id $task.Id -Server $vcenter
			If ( $type -eq "vVM" ) {
				$entity = Get-VM -Name $name -Server $vcenter
				$powerState = [string]$entity.PowerState
			} Else {
				$entity = Get-VApp -Name $name -Server $vcenter
				$powerState = [string]$entity.Status
			}
			If ($task.State -eq "Error") {
				Write-Progress "FATAL ERROR" 'FAIL-2'  
				$currentRunningSeconds = Get-RuntimeSeconds $startTime
				$currentRunningMinutes = $currentRunningSeconds / 60
				Write-Output $("FAILURE: labStartup ran for {0:N0} minutes and has been terminated."  -f $currentRunningMinutes )
				Write-Output $("Cannot start {0} {1} on {2}" -f $type, $name, $vcenter )
				Write-Output $("Error task Id {0} task state: {1}" -f $task.Id, $task.State )
				Exit
			}
			Write-Output $("Current {0} {1} power state: {2}" -f $type, $name, $powerState )
			Write-Output $("Current task Id {0} task state: {1}" -f $task.Id, $task.State )
		}
	}
} #End Start-Nested

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
} #End Report-VpodStatus

Function RunWinCmd ([string]$wcmd, [REF]$result) {
<#
  Execute a Windows command on the local machine with some degree of error checking
#>
	$errorVar = ""
	
	# need this in order to capture output but make certain not already included
	if ( !($wcmd.Contains(" 2>&1"))) {
	   $wcmd += ' 2>&1'
	}
	
	$output = Invoke-Expression -Command $wcmd -ErrorVariable errorVar
	
	if ( $errorVar.Length -gt 0 ) {
		#Write-Host "Error: $errorVar"
		$result.Value = "fail"
		return $errorVar
	} else {
		$result.Value = "success"
		return $output
	}
} #End RunWinCmd

Function Write-Progress ([string] $msg, [string] $code) {
	$myTime = $(Get-Date)
	If( $code -eq 'READY' ) {
		$dateCode = "{0:D2}/{1:D2} {2:D2}:{3:D2}" -f $myTime.month,$myTime.day,$myTime.hour,$myTime.minute
		Set-Content -Value ([byte[]][char[]] "$msg $dateCode") -Path $statusFile -Encoding Byte
		#also change text color to Green (55cc77) in desktopInfo
		(Get-Content $desktopInfo) | % { 
			$line = $_
			If( $line -match 'Lab Status' ) {
				$line = $line -replace '3A3AFA','55CC77'
			}
			$line
		} | Out-File -FilePath $desktopInfo -encoding "ASCII"
	} Else {
		$dateCode = "{0:D2}:{1:D2}" -f $myTime.hour,$myTime.minute
		Set-Content -Value ([byte[]][char[]] "$dateCode $msg ") -Path $statusFile -Encoding Byte
	}
	Report-VpodStatus $code
} #End Write-Progress

##############################################################################

If( Test-Path $desktopInfo ) {
	# read the desktopInfo.ini configuration file and find the line that begins with "COMMENT="
	# NOTE: new DesktopInfo 1.51 format
	$TMP = Select-String $desktopInfo -pattern "^COMMENT=active:1"
	# split the line on the ":"
	$TMP = $TMP.Line.Split(":")
	# split the last field on the "-" and space characters
	$TMP = $TMP[5].Split("- ")
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
	Write-Progress "FAIL - No PowerCLI" 'FAIL-1'
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
} #End Connect-VC

Function Restart-VC ([string]$server, [REF]$result){
	If ($server.Contains("vcsa") ) {
		# vSphere 6 appliance is most likely
		Write-Host "Trying appliance vCenter 6 reboot..."
		$lcmd = "shutdown reboot -r now 2>&1"
		$msg = Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmd
		If ( $msg -ne $null ) {
			Write-Host "msg from vSphere 6 restart: $msg"
			If ( $msg -eq "The system is going down for reboot NOW!") {  # not sure what this should be for success
				$result.Value = "success"
				Return
			}
		}
		If ( $msg -eq $null ) { $result.Value = "success" }
		Else {
			# if not success then try vSphere 5
			Write-Host "Trying appliance vCenter 5 reboot..."
			$lcmd = "init 6 2>&1"
			$msg = Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmd
			If ( $msg -eq $null ) { $result.Value = "success" }
			Else { $result.Value = "fail" }
		}
	} Else {
		# try Windows
		Write-Host "Trying Windows vCenter reboot..."
		$wresult = ""
		$wcmd = "shutdown /m \\$server /r /t 0"
		$msg = RunWinCmd $wcmd ([REF]$wresult)
		$result.Value = $wresult
	}
} #End Restart-VC

Function Test-Ping ([string]$server, [REF]$result) {
<#
	This function makes sure a host is responding to a PING
	It does not attempt to validate anything beyond a simple response
	It sets the $result variable to 'success' or 'fail' based on the result
#>
	If ( Test-Connection -ComputerName $server -Quiet ) {
		Write-Output "Successfully pinged $server"
		$result.value = "success"
	}
	Else {
		Write-Output "Cannot ping $server"
		$result.value = "fail"
	}
} #End Test-Ping


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
} #End Test-TcpPortOpen

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
	This function performs an action (start/stop/restart/query) on the specified 
	Windows service on the specified server. The service must report within $waitsec 
	seconds or the function reports 'fail'
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
			Return $svc.Status
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
		return $msg
	}
	Catch {
		Write-Host "Failed to $action $service on $server : $msg"
		$result.value = "fail"
	}
} #End ManageLinuxService


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
    LabFail "Lab startup has run for the maximum minutes of $maxMinutesBeforeFail"
  } Else {
    If( ([int]$currentRunningSeconds % 10) -lt 3 ) {
      #throttle the number of messages a little
      Write-Output $("Labstartup has been running for {0:N0} minutes." -f $currentRunningMinutes )
    }
    Start-Sleep -sec $sleepSecs
  }
} #End LabStartup-Sleep

Function LabFail ( [string] $message ) {
	$currentRunningSeconds = Get-RuntimeSeconds $startTime
	$currentRunningMinutes = $currentRunningSeconds / 60
	Write-Output $message
	Write-Progress "FAIL - TIMEOUT" 'TIMEOUT'
	Write-Output $("FAILURE: labStartup ran for {0:N0} minutes and has been terminated."  -f $currentRunningMinutes )
	Exit
} #End LabFail

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
# attempt to connect to each vCenter and restart if no connection by $vcBootMinutes
$VCstartTime = @{}
Foreach ($vcserver in $vCenters) {
	$VCrestarted = $false
	$VCstartTime[$vcserver] = $startTime
	# do a ping test first
	Test-Ping $vcserver ([REF]$result)
	If ($result -ne "success" ) {
		LabFail "Cannot ping vCenter $vcserver.  Failing lab."
	}
	Do {
		Connect-VC $vcserver $vcuser $password ([REF]$result)
		LabStartup-Sleep $sleepSeconds
		$currentRunningSeconds = Get-RuntimeSeconds $VCstartTime[$vcserver]
		$currentRunningMinutes = $currentRunningSeconds / 60
		If( $currentRunningMinutes -gt $vcBootMinutes ) {
			If ( $VCrestarted -eq $false ) {  # try restarting vCenter to fix the issue
				Write-Output "Restarting vCenter $vcserver" 
				Restart-VC $vcserver ([REF]$VCrestarted)
				If ($VCrestarted -eq "success") { 
					$VCstartTime[$vcserver] = $(Get-Date)  # record the reboot for this VC
					# add more time before fail due to VC reboot
					$maxMinutesBeforeFail += $vcBootMinutes
					# reset the currentRunningMinutes
					$currentRunningSeconds = Get-RuntimeSeconds $VCstartTime[$vcserver]
					$currentRunningMinutes = $currentRunningSeconds / 60
				} Else {
					LabFail "Cannot restart vCenter $vcserver.  Failing lab."
				}
			}
		}
		If ( ($currentRunningMinutes -gt $vcBootMinutes) -And ($VCrestarted -eq "success" ) ) {
			LabFail "Failing the lab after restarting vCenter $vcserver"
		}
	} Until ($result -eq "success")
}

##############################################################################
##### Lab Startup - STEP #2 (Starting Nested VMs and vApps) 
##############################################################################

Write-Progress "Starting vVMs" 'STARTING'

# Use the Start-Nested function to start batches of nested VMs and/or vApps
# Create additional arrays for each batch of VMs and/or vApps
# Insert a LabStartup-Sleep as needed if a pause is desired between batches
# Or include additional tests for services after each batch and before the next batch

Start-Nested $vApps
Start-Nested $VMs

Foreach ($vcserver in $vCenters) {
	Write-Output "$(Get-Date) disconnecting from $vcserver ..."
	Disconnect-VIServer -Server $vcserver -Confirm:$false
}

##############################################################################
##### Lab Startup - STEP #3 (Start/Restart/Stop/Query Services) 
##############################################################################

Write-Progress "Manage Win Svcs" 'GOOD-2'

# options are "start", "restart", "stop" or "query"
$action = "start"
# Manage Windows services on remote machines
Foreach ($service in $windowsServices) {
	($wserver,$wservice) = $service.Split(":")
	Write-Output "Performing $action $wservice on $wserver"
	$waitSecs = '30' # seconds to wait for service startup/shutdown
	Do {
		$status = ManageWindowsService $action $wserver $wservice $waitSecs ([REF]$result)
# If using "query" option, uncomment next line to display current state in log
#		Write-Host "status is" $status
	} Until ($result -eq "success")
}

Write-Output "$(Get-Date) Finished $action Windows services"

Write-Progress "Manage Linux Svcs" 'GOOD-3'

# options are "start", "restart", "stop" or "query"
$action = "start"
# Manage Linux services on remote machines
Foreach ($service in $linuxServices) {
	($lserver,$lservice) = $service.Split(":")
	Write-Output "Performing $action $lservice on $lserver"
	$waitSecs = '30' # seconds to wait for service startup/shutdown
	Do {
		$status = ManageLinuxService $action $lserver $lservice $waitSecs ([REF]$result)
# If using "query" option, uncomment next line to display current state in log
#		Write-Host "status is" $status
	} Until ($result -eq "success")
}

Write-Output "$(Get-Date) Finished $action Linux services"

##############################################################################
##### Lab Startup - STEP #3 (Testing Pings, Ports & Services) 
##############################################################################

Write-Progress "Testing TCP ports" 'GOOD-3'

# Testing Pings
Foreach ($ping in $Pings) {
	Do { 
		Test-Ping $ping ([REF]$result)
		LabStartup-Sleep $sleepSeconds
	} Until ($result -eq "success")
}

#Testing services are answering on TCP ports 
Foreach ($service in $TCPservices) {
	($server,$port) = $service.Split(":")
	Do { 
		Test-TcpPortOpen $server $port ([REF]$result)
		LabStartup-Sleep $sleepSeconds
	} Until ($result -eq "success")
}

Write-Progress "Checking URLs" 'GOOD-4'

#Testing URLs - if vSphere Web Client, restart vCenter ONCE then try again and fail vPod if no success
Foreach ($url in $($URLs.Keys)) {
	$isVC = $false
	$VCrestarted = $false
    Foreach ( $vcserver in $vCenters ) {
		If ( $url.Contains( $vcserver ) ) { 
			$isVC = $true
			Break
		}
	}
	Do { 
		Test-URL $url $URLs[$url] ([REF]$result)
		If ( ($isVC) -And ($result -ne "success") ) {
			$currentRunningSeconds = Get-RuntimeSeconds $VCstartTime[$vcserver]
			$currentRunningMinutes = $currentRunningSeconds / 60
			If( ($currentRunningMinutes -gt $ngcBootMinutes ) -And !($VCrestarted) ) { 
				# try restarting vCenter to fix the issue
				Write-Output "Restarting vCenter $vcserver" 
				Restart-VC $vcserver ([REF]$VCrestarted)
				If ($VCrestarted -eq "success") { 
					$maxMinutesBeforeFail += $ngcBootMinutes
					$VCstartTime[$vcserver] = $(Get-Date)  # record the reboot for this VC
					$currentRunningSeconds = Get-RuntimeSeconds $VCstartTime[$vcserver]
					$currentRunningMinutes = $currentRunningSeconds / 60
				} Else {
					LabFail "Cannot restart vCenter $vcserver.  Failing lab."
				}
			}
			If ( ($currentRunningMinutes -gt $ngcBootMinutes ) -And ($VCrestarted -eq "success" ) ) {
				LabFail "Failing the lab after restarting vCenter $vcserver"
			}
		}		
		LabStartup-Sleep $sleepSeconds
	} Until ($result -eq "success")
}


#Write-Progress "Doing My Thing" 'GOOD-4'
## Any final checks here. Maybe you need to check something after the
## services are started/restarted.

# example RunWinCmd (Note this is commented out!)
<# 

$wcmd = "ipconfig"
Do { 
		$output = RunWinCmd $wcmd ([REF]$result)
		ForEach ($line in $output) {
		    Write-Host $line
		}
		Start-Sleep 5
	} Until ($result -eq "success")

#>

#Write-Progress "Finished Doing My Thing" 'GOOD-5'


#Report Final State
Write-Progress "Ready" 'READY'
Write-Output $( "$(Get-Date) LabStartup Finished - runtime was {0:N0} minutes." -f  ((Get-RuntimeSeconds $startTime) / 60) )
##############################################################################
