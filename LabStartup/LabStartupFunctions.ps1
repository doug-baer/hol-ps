<#
	LabStartup Functions - 2016-11-22
#>

# Bypass SSL certificate verification (testing)
add-type @"
	using System.Net;
	using System.Security.Cryptography.X509Certificates;
	public class TrustAllCertsPolicy : ICertificatePolicy {
		public bool CheckValidationResult(
			ServicePoint srvPoint, X509Certificate certificate,
			WebRequest request, int certificateProblem) {
			return true;
		}
	}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

# Windows vCenter services
# services start top to bottom (services are dependent on the services above them)
# this adds about 5 minutes to startup time if starting all of these services
# think of this more as documentation - the key services to start are vpxd and vspherewebclientsvc
$windowsvCenterServices = @(
	'MSSQLSERVER' # Microsoft SQL Server
	'SQLSERVERAGENT' # Microsoft SQL Server Agent
	'vmware-cis-config' # VMware vCenter Configuration Service
	'VMWareAfdService'  # VMware Afd Service
	'rhttpproxy'  # VMware HTTP Reverse Proxy
	'VMwareComponentManager' # VMware Component Manager
	'VMwareServiceControlAgent' # VMware Service Control Agent
	'vapiEndpoint' # VMware vAPI Endpoint
	'vmwarevws' # VMware System and Hardware Health Manager
	'invsvc' # VMware Inventory Service
	#'mbcs' # VMware Message Bus Config Service (ok to leave commented out)
	'vpxd' # VMware VirtualCenter Server
	'vimPBSM' # VMware vSphere Profile-Driven Storage Service
	'vmSyslogCollector' # VMware Syslog Collector
	'vdcs' # VMware Content Library Service
	'EsxAgentManager' # VMware ESX Agent Manager
	'vmware-vpx-workflow' # VMware vCenter workflow manager
	'VServiceManager' # VMware vService Manager
	'vspherewebclientsvc' # vSphere Web Client'
	'vmware-perfcharts' # VMware Performance Charts
)

Function Start-AutoLab () {
<#
	Please leave this function here to enable scale testing automation:
	If there is media in the CD/DVD drive and it contains "autolab.ps1"
	run that script - enables vpod automation for scale testing
#>
	If ( $labcheck ) { 
		Write-Host "Labcheck is active. Skipping Start-AutoLab"
		Return $FALSE 
	}
	$cd = (Get-WmiObject win32_LogicalDisk -filter 'DriveType=5')|%{$_.DeviceID}
	If( $cd ) {
		Write-Host "Testing $cd\autolab.ps1"
		If( Test-Path -Path "$cd\autolab.ps1" ) {
			Write-Host "Executing $cd\autolab.ps1"
			Write-VpodProgress "Ready: Executing $cd\autolab.ps1" 'AUTOLAB'
			Start-Process powershell -ArgumentList "-command $cd\autolab.ps1"
			Write-Host "Finished with $cd\autolab.ps1"
			Write-VpodProgress "Finished with $cd\autolab.ps1" 'AUTOLAB'
			Return $TRUE
		}
	}
	Return $FALSE
} #End Start-AutoLab

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
	'LABCHECK' = 105
	'READY'    = 200
	'AUTOLAB'  = 201
	'STARTING' = 202
	'TIMEOUT'  = 203
	'FIREWALL' = 204
	'ALERT'    = 205
}

Function Invoke-Plink ([string]$remoteHost, [string]$login, [string]$passwd, [string]$command) {
<#
	This function executes the specified command on the remote host via SSH
#>
	Invoke-Expression "Echo Y | $plinkPath -ssh $remoteHost -l $login -pw $passwd $command"
} #End Invoke-Plink

Function Invoke-PlinkKey ([string]$puttySession, [string]$command) {
<#
	This function executes the specified command on the remote host via SSH
	utilizing key-based authentication and a saved PuTTY session name rather than 
	a username/password combination
#>
	Invoke-Expression "Echo Y | $plinkPath -ssh -load $puttySession $command"
} #End Invoke-PlinkKey

Function Invoke-Pscp ([string]$login, [string]$passwd, [string]$sourceFile, [string]$destFile) {
<#
	This function uses pscp.exe to copy a file from or to a remote destination.
	The source and destination conventions of pscp.exe must be followed.
	Remote to remote is not allowed.
	The source file must be a regular file.
#>
   
	Invoke-Expression "$pscpPath -l $login -pw $passwd $sourceFile $destFile"
 
} #End Invoke-Pscp

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

Function Report-VpodStatus ([string] $newStatus) {
	$server = 'router.corp.local'
	If ( -Not $labcheck ) { # record cold start runtime minutes on first octet if not labcheck
		[decimal] $coldStartMin = [math]::Round((Get-RuntimeSeconds $startTime) / 60)
	}
	If ( $coldStartMin -lt 1 ) { $coldStartMin = 1}
	$IPNET = "$coldStartMin.$YEAR.$SKU"
	$newIP = "$IPNET." + $statusTable[$newStatus]
	If ($labcheck) {
		If ( ($statusTable[$newStatus] -gt 202 ) `
		     -or ($statusTable[$newStatus] -eq 101) `
			 -or ($statusTable[$newStatus] -eq 102) `
			 -or ($statusTable[$newStatus] -eq 103) `
			 -or ($statusTable[$newStatus] -eq 104) ) {
				$newIP = "$IPNET." + $statusTable['LABCHECK']
				# Delete the Windows Scheduled Task so it doesn't run again before remediation
				Write-Host "Disabling LabCheck task..."
				Disable-ScheduledTask -TaskName "LabCheck"
			}
	}
	$bcast = "$IPNET." + "255"
	#replace the IP address on the vpodrouter's 6th NIC with our indicator code
	$lcmd = "sudo /sbin/ifconfig eth5 broadcast $bcast netmask 255.255.255.0 $newIP"
	
	#need retry code here to allow for vPodRouter reboot events due to cloud info
	$wcmd = "Echo Y | $plinkPath -ssh router.corp.local -l holuser -pw VMware1! $lcmd  2>&1"
	$errorVar = "junk" # initialize errorVar for While loop
	While ( $errorVar.Length -gt 0 ) { # errorVar.length should be 0 if success
		$output = Invoke-Expression -Command $wcmd -ErrorVariable errorVar
		If ( $errorVar.Length -gt 0  ) { 
			Write-Host $errorVar
			LabStartup-Sleep $sleepSeconds
		}
	}
	$currentStatus = $newStatus
} #End Report-VpodStatus

Function Write-VpodProgress ([string] $msg, [string] $code) {
	$myTime = $(Get-Date)
	If ( -Not $labcheck ) {
	  If( $msg -eq 'Ready' ) {
		$dateCode = "{0:D2}/{1:D2} {2:D2}:{3:D2}" -f $myTime.month,$myTime.day,$myTime.hour,$myTime.minute
		Set-Content -Value ([byte[]][char[]] "$msg $dateCode") -Path $statusFile -Encoding Byte
		#also change text color to Green (55cc77) in desktopInfo
		(Get-Content $desktopInfoIni) | % { 
			$line = $_
			If( $line -match 'Lab Status' ) {
				$line = $line -replace '3A3AFA','55CC77'
			}
			$line
		} | Out-File -FilePath $desktopInfoIni -encoding "ASCII"
		} Else {
		$dateCode = "{0:D2}:{1:D2}" -f $myTime.hour,$myTime.minute
		Set-Content -Value ([byte[]][char[]] "$dateCode $msg ") -Path $statusFile -Encoding Byte
	  }
	}
	Report-VpodStatus $code
} #End Write-VpodProgress

Function Get-CloudInfo {
# try to determine current cloud using vPodRouter guestinfo
	$lcmd = "/usr/sbin/vmtoolsd --cmd '''info-get guestinfo.ovfenv'''" # passing single quote is tricky
	$msg = Invoke-Expression "Echo Y | $plinkPath -ssh router.corp.local -l holuser -pw VMware1! $lcmd  2>&1"
	Try {
		$cloud = (([xml]$msg).Environment.PropertySection.Property | where {$_.key -eq 'cloud'}).value
		Return $cloud
	} Catch {
		Return "Cannot determine cloud at this time."
}

} #End Get-CloudInfo


Function Connect-vCenter ( [array] $vCenters ) {
	Foreach ($entry in $vCenters) {
		($vcserver,$type) = $entry.Split(":")
		Do {
			Connect-VC $vcserver $vcuser $password ([REF]$result)
			LabStartup-Sleep $sleepSeconds
		} Until ($result -eq "success")
	}
} #End Connect-vCenter

Function Connect-Restart-vCenter ( [array]$vCenters, [REF]$maxMins ) {
	
	$waitSecs = '30' # seconds to wait for service startup/shutdown
	$action = 'start'
	Foreach ($entry in $vCenters) {
		($vcserver,$type) = $entry.Split(":")
		$NGCclient = "false"
		$VCrestarted = $false
		$VCstartTime = $startTime
		# do a ping test first
		Do {
			LabStartup-Sleep $sleepSeconds
			Test-Ping $vcserver ([REF]$result)
		} Until ($result -eq "success" )
		If ( $type -eq "windows" ) {
			Do {
				ManageWindowsService $action $vcserver 'vpxd' $waitSecs ([REF]$result)
			} Until ($result -eq "success")
		}
		If ( $type -eq "esx" ) { $VCrestarted = $true }
		Do {
			Connect-VC $vcserver $vcuser $password ([REF]$result)
			LabStartup-Sleep $sleepSeconds
			$currentRunningSeconds = Get-RuntimeSeconds $VCstartTime
			$currentRunningMinutes = $currentRunningSeconds / 60
			If ( $result -eq "success" ) { Continue } # if success continue on to next part.
			If ( $currentRunningMinutes -gt $vcBootMinutes ) {
				If ( $VCrestarted -eq $false ) {  # try restarting vCenter to fix the issue
					Write-Output "Restarting vCenter $vcserver" 
					Restart-VC $entry ([REF]$VCrestarted)
					If ($VCrestarted -eq "success") { 
						$VCstartTime = $(Get-Date)  # record the reboot for this VC
						# add more time before fail due to VC reboot
						$maxMinutesBeforeFail = $maxMinutesBeforeFail + $vcBootMinutes
						# reset the currentRunningMinutes
						$currentRunningSeconds = Get-RuntimeSeconds $VCstartTime
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
		# make certain the NGC service is started
		If ( $type -eq "windows" ) {
			Do {
				ManageWindowsService $action $vcserver 'vspherewebclientsvc' $waitSecs ([REF]$result)
			} Until ($result -eq "success")
		}
		If ( $type -eq "linux" ) {
			Do {
				ManageLinuxService $action $vcserver 'vsphere-client' $waitSecs ([REF]$result)
			} Until ($result -eq "success")
		}
	}
	$maxMins.value = $maxMinutesBeforeFail
} #End Connect-Restart-vCenter

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

Function Restart-VC ([string]$entry, [REF]$result){
	($server,$type) = $entry.Split(":")
	If ( $type -eq "linux" ) {
		# reboot Platform Services Controller first if present
		$psc = 'psc-01a.corp.local'
		$pingResult = ''
		Test-Ping $psc ([REF]$pingResult)
		If ($pingResult -eq "success") {
			Write-Host "Trying Platform Services Controller reboot..."
			$lcmd = "init 6 2>&1"
			$msg = Invoke-Plink -remoteHost $psc -login $linuxuser -passwd $linuxpassword -command $lcmd
			If ( $msg -eq $null ) { 
				Write-Host "Pausing 60 seconds for Platform Services Controller to reboot..."
				LabStartup-Sleep 60
				Do { 
					Test-Ping $psc ([REF]$pingResult)
					LabStartup-Sleep $sleepSeconds
				} Until ($pingResult -eq "success")
			}
		}
		# now reboot vCenter appliance
		Write-Host "Trying vCenter appliance reboot..."
		$lcmd = "init 6 2>&1"
		$msg = Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmd
		If ( $msg -eq $null ) { $result.Value = "success" }
		Else { $result.Value = "fail" }
	} ElseIf ( $type -eq "windows") {
		# try Windows
		Write-Host "Trying Windows vCenter reboot..."
		$wresult = ""
		$wcmd = "shutdown /m \\$server /r /t 0"
		$msg = RunWinCmd $wcmd ([REF]$wresult)
		$result.Value = $wresult
	}
} #End Restart-VC

# need a global to keep track of previous nested item power state so pause can be skipped if in LabCheck
$previousPowerState = ""

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
		If ( $vcenter -eq $null ) { ($vcenter,$type) = $vCenters[0].Split(":") }
		If ( $name -eq "Pause" ) {
			If ( !($labcheck) ) {  # always pause if not LabCheck regardless of previousPowerState
				Write-Host "Pausing for $vcenter seconds..."
				LabStartup-Sleep $vcenter
				Continue
			 # no need to pause if Labcheck and previous nested item was already on.
			} ElseIf (($previousPowerState -eq "Started") -or ($previousPowerState -eq "PoweredOn")) {
				Write-Host "Skipping $vcenter second pause since previous powerstate was $previousPowerState and LabCheck is active."
				Continue
			} Else { # if LabCheck and previous nested item was started
				Write-Host "Pausing for $vcenter seconds during LabCheck..."
				LabStartup-Sleep $vcenter
				Continue
			}
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
		
		$previousPowerState = $powerState
		
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
				# Because we have checked storage, we will not fail the lab but merely note the issue starting the L2 VM or vApp
				#Write-VpodProgress "FATAL ERROR" 'FAIL-2'  
				#$currentRunningSeconds = Get-RuntimeSeconds $startTime
				#$currentRunningMinutes = $currentRunningSeconds / 60
				#Write-Output $("FAILURE: labStartup ran for {0:N0} minutes and has been terminated."  -f $currentRunningMinutes )
				Write-Output $("Cannot start {0} {1} on {2}" -f $type, $name, $vcenter )
				Write-Output $("Error task Id {0} task state: {1} task status: {2}" -f $task.Id, $task.State, $task.Status )
				#Exit
			}
			If (($task.State -eq "Queued" ) -or ($task.State -eq "Running" )) {
				Write-Output $("{0} power-on task is {1}.  Moving on..." -f $name, $task.State )
				Break
			}
			Write-Output $("Current {0} {1} power state: {2}" -f $type, $name, $powerState )
			Write-Output $("Current task Id {0} task state: {1}" -f $task.Id, $task.State )
		}
	}
} #End Start-Nested

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

Function ManageLinuxService ([string]$action, [string]$server, [string]$service, [int]$waitsec, [REF]$result) {
<#
	This function manages (start/stop/restart/query) the specified service on the specified server
	The service must respond within $waitsec seconds or the function reports 'fail'
#>
	$lcmd1 = "service $service $action"
	$lcmd2 = "service $service status"
	
	Try {
		#find Photon-based VCSA and act differently
		$msg = Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command 'uname -v'
		If( $msg -match 'photon' ) {
			Write-Host "Operating System is Photon"
			If( $action -eq 'query' ) {
				$msg = ManageVcsaService 'status' $server $service  ([REF]$result)
			} Else {
				$msg = ManageVcsaService $action $server $service  ([REF]$result)
			}
			return $msg
		}
	}
	Catch {
		Write-Host "Failed to run uname on $server : $msg"
		$result.value = "fail"
	}

	
	Try {
		If ($action -ne "query") {
			$msg = Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmd1
			LabStartup-Sleep $waitsec
		}
		$msg = Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmd2
		If (( $action -eq "start" ) -or ( $action -eq "restart") -or ( $action -eq "query" )) {
			If( $msg -match "is running" ) {
				$result.value = "success"
				If ($action -eq "query") { Return "Running" }
			}
		} ElseIf (( $action -eq "stop" ) -or ( $action -eq "query" )) {
				If( $msg -match "is not running" ) {
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

Function StartWindowsServices ( [array] $winServices ) {

	$action = "start"
	$maxWinSvcTries = 20
	$waitSecs = '30' # seconds to wait for service startup/shutdown
	$ccRebootFlag = 'C:\hol\CCrebooted.txt'

	# Manage Windows services on remote machines
	Foreach ($service in $winServices) {
		$ctr = 0
		($wserver,$wservice) = $service.Split(":")
		Write-Output "Performing $action $wservice on $wserver"
		Do {
			$status = ManageWindowsService $action $wserver $wservice $waitSecs ([REF]$result)
			$ctr = $ctr + 1
			If ( $ctr -eq $maxWinSvcTries ) {
				$message = "$(Get-Date) Cannot start $wservice on $wserver after $ctr attempts."
				If ( Test-Path $ccRebootFlag) { LabFail "$message ControlCenter rebooted." }
				Else {
					Set-Content -Value "$message rebooting ControlCenter" -Path $ccRebootFlag
					Restart-Computer ControlCenter
				}
			}
		} Until ($result -eq "success")
	}
}  # end StartWindowsServices 
###

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
		LabStartup-Sleep $waitsec  # pause even if Try fails
		$result.value = "fail"
	}
} #End ManageWindowsService

Function Test-URL { 
	[CmdletBinding()] 
	PARAM([string]$url, [string]$lookup, [REF]$result)
	PROCESS {
<#
	This function tries to access the specified URL and looks for the string
	specified in the resulting HTML
	It sets the $result variable to 'success' or 'fail' based on the result 
#>
		$sp = [System.Net.ServicePointManager]::SecurityProtocol
			
		#ADD TLS1.2 to the default (SSLv3 and TLSv1)
		[System.Net.ServicePointManager]::SecurityProtocol = ( $sp -bor [System.Net.SecurityProtocolType]::Tls12 )
		
		#Disable SSL validation (usually a BAD thing... but this is a LAB)
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
		
		Try {
			$wc = (New-Object Net.WebClient).DownloadString($url)
			If( $wc -match $lookup ) {
				Write-Output "Successfully connected to $url"
				$result.value = "success"
			} Else {
				Write-Output "Connected to $url but lookup ( $lookup ) did not match"
				Write-Verbose $wc
				$result.value = "fail"
			}
		}
		Catch {
			Write-Output "URL $url not accessible"
			Write-Output "Error occured: $_"
			$result.value = "fail"
		}
		#Reset default SSL validation behavior
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
	}

} #End Test-URL

Function ManageVcsaService {
<#
	This function manages (start/stop/restart/status) the specified service on the specified VCSA server (6.0 or 6.5)
	
.EXAMPLE
	ManageVcsaService 'status' 'vcsa-01a.corp.local' 'vsphere-client'  ([REF]$result)
.EXAMPLE
	ManageVcsaService 'status' 'vcsa-01a.corp.local' 'vsphere-client'  ([REF]$result) -Verbose
#>
	[CmdletBinding()]

	PARAM (
		[string]$action, 
		[string]$server, 
		[string]$service, 
		[REF]$result
	)

	$action = $action.ToLower()
	$validActions = ('restart','start','status','stop')
	
	If( $validActions.Contains($action) ) {
		Try {
			# Execute a stop or restart action (which is stop, then start)
			If( ($action -eq "stop") -or ($action -eq "restart") ) {
				$lcmdStop = "service-control --stop $service"
				# this blocks until the stop completes
				Write-Verbose "Stopping $service on $server"
				Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmdStop | Out-Null
				Write-Verbose "Stopped $service on $server"			
				#LabStartup-Sleep $waitsec
			}
	
			If( ($action -eq "start") -or ($action -eq "restart") ) {
				$lcmdStart = "service-control --start $service"
				# this blocks until the start completes
				Write-Verbose "Starting $service on $server"
				Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmdStart | Out-Null
				Write-Verbose "Started $service on $server"
				#LabStartup-Sleep $waitsec
			}
			
			# get the state of the service
			$lcmdStatus = "service-control --status $service"
			Write-Verbose "Querying status of $service on $server"
			$msg = Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmdStatus
	
			#parse the result of the "status" command
			If( ($action -eq "start") -or ($action -eq "restart") -or ( $action -eq "status") ) {
				Write-Verbose "Start/Restart/Status returned`n`t$msg"
				If( ($msg -match "Running").Count -ge 1 ) {
					$result.value = "success"
					If( $action -eq "status" ) { Return "Running" }
				}
			} ElseIf( ($action -eq "stop") -or ($action -eq "status") ) {
				Write-Verbose "Stop/Status returned`n`t$msg"
					If( ($msg -match "Stopped").Count -ge 1 ) {
						$result.value = "success"
						If( $action -eq "status" ) { Return "Stopped" }
					}
			}
	
			return $msg
		}
		Catch {
			Write-Host "Failed to $action $service on $server -- $msg"
			$result.value = "fail"
		}
	}
	Else {
		Write-Host "Invalid action: $action"
		$result.value = "fail"
	}
} #End ManageVcsaService


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
	Write-VpodProgress "FAIL - TIMEOUT" 'TIMEOUT'
	Write-Output $("FAILURE: labStartup ran for {0:N0} minutes and has been terminated."  -f $currentRunningMinutes )
	Exit
} #End LabFail

Function Check-Datastore ([string] $dsline, [REF]$result ) 
{
	($server,$datastoreName) = $dsline.Split(":")

	Do {
		Try{ 
			$ds = Get-Datastore $datastoreName -ErrorAction 1
		}
		Catch {
			#rescan on each host
			Write-Host "-> $datastoreName not found, attempting rescan"
			Get-VMHost | Get-VMhostStorage -RescanAllHba -RescanVmfs | Out-Null
			LabStartup-Sleep 10
		}
	} Until ( $ds -ne $null )
	
	If ( $ds.Type -eq "VMFS" ) { # rescan for VMFS LUNs since iSCSI on FreeNAS needs it.
		Get-VMHost | Get-VMhostStorage -RescanAllHba -RescanVmfs | Out-Null
	}

	If ( $ds.State -eq "Available" ) {
		Try {
			New-PSDrive -Name "ds" -PsProvider VimDatastore -Root "\" -Datastore $ds | Out-Null
			$check = ((Get-ChildItem ds: -ErrorAction 1 | Measure-Object).Count -gt 0)
			Get-PSDrive "ds" | Remove-PSDrive
			$result.value = "success"
			Write-Host "Datastore $datastoreName on $server looks ok."
		}
		Catch {
			Write "Datastore $datastoreName on $server is not looking good."
			$result.value = "fail"
			# fail lab at this point?
		}
	} Else {  
		If( $ds.Type -eq "NFS") {  # reboot FreeNAS only if NFS
			Write-Output "NFS $datastoreName is not available. Rebooting $server..."
			$lcmd = "init 6 2>&1"
			$msg = Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmd
			If ( $msg -eq $null ) { 
				Write-Host "Pausing 60 seconds for $server to reboot..."
				LabStartup-Sleep 60
				$pingResult = ''
				Do { 
						Test-Ping $server ([REF]$pingResult)
						LabStartup-Sleep $sleepSeconds
				} Until ($pingResult -eq "success")
			}
		}
		# how long does it take for this to succeed after storage reboot?
		Write-Host "Pausing another 60 seconds for $server $datastoreName to come up..."
		LabStartup-Sleep 60

		Do { 
			Write-Host "Datastore $datastoreName not available yet..."
			$ds = Get-Datastore $datastoreName
			If ( $ds.Type -eq "VMFS" ) {
				Get-VMHost | Get-VMhostStorage -RescanAllHba -RescanVmfs | Out-Null
			}
			LabStartup-Sleep $sleepSeconds
		} Until ($ds.State -eq "Available")
		
		Write-Host "Datastore $datastoreName appears to be available now..."
		
		Try {
			New-PSDrive -Name "ds" -PsProvider VimDatastore -Root "\" -Datastore $ds
			((Get-ChildItem ds: -ErrorAction 1 | Measure-Object).Count -gt 0)
			Get-PSDrive "ds" | Remove-PSDrive
			$result.value = "success"
		}
		Catch {
			Write-VpodProgress "FATAL ERROR" 'FAIL-2'  
			$currentRunningSeconds = Get-RuntimeSeconds $startTime
			$currentRunningMinutes = $currentRunningSeconds / 60
			Write-Output $("FAILURE: labStartup ran for {0:N0} minutes and has been terminated."  -f $currentRunningMinutes )
			Write-Output $("Datastore {0} is not looking good after reboot of {1}" -f $datastoreName, $server )
			Exit
		}
	}
} #End Check-Datastore


Function Get-URL {
	[CmdletBinding()] 
	PARAM ( [string]$url, [string]$lookup ) 
	PROCESS {
		#enable TLS 1.2
		$sp = [System.Net.ServicePointManager]::SecurityProtocol
		#[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
			
		#Alternative: ADD TLS1.2 to the default (SSLv3 and TLSv1)
		[System.Net.ServicePointManager]::SecurityProtocol = ( $sp -bor [System.Net.SecurityProtocolType]::Tls12 )
		
		#Disable SSL validation (usually a BAD thing... but this is a LAB)
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
		
		Try {
			$wc = (New-Object Net.WebClient).DownloadString($url)
			If( $wc -match $lookup ) {
				Write-Output "Successfully connected to $url"
			} Else {
				Write-Output "Connected to $url but lookup ( $lookup ) did not match"
				Write-Verbose $wc
			}
		}
		Catch {
			Write-Output "URL $url not accessible"
		}
		
		#Reset default SSL validation behavior
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null

	}
} #End Get-URL



# Small Function to execute a REST operation and return the JSON response
Function Http-rest-xml
{
	<#
	.SYNOPSIS
		This function establishes a connection to the NSX API
	.DESCRIPTION
		This function establishes a connection to	NSX API
	.PARAMETER method
		Specify the REST Method to use (GET/PUT/POST/DELETE)"
	.PARAMETER uri
		Specify the REST URI that identifies the resource you want to interact with
	.PARAMETER body
		Specify the body content if required (PUT/POST)
	.INPUTS
		String: Target IP/hostname
		String: REST Method to use.
		String: URI that identifies the resource
		String: username (optional)
		String: password (optional)
		String: etag (if required)
		String: Body (if required)
	.OUTPUTS
		JsonObject: Request result in JSON
	.LINK
		None.
	#>

	[CmdletBinding()]
	PARAM(
		[
			parameter(
				Mandatory = $true,
				HelpMessage = "Specify the target host IP or DNS name",
				ValueFromPipeline = $false
			)
		]
		[String]
		$target,
		[
			parameter(
				Mandatory = $true,
				HelpMessage = "Specify the REST Method to use (GET/PUT/POST/DELETE)",
				ValueFromPipeline = $false
			)
		]
		[String]
		$method,
		[
			parameter(
				Mandatory = $true,
				HelpMessage = "Specify the REST URI that identifies the resource you want to interact with",
				ValueFromPipeline = $false
			)
		]
		[String]
		$uri,
		[
			parameter(
				Mandatory = $false,
				HelpMessage = "User name, if required",
				ValueFromPipeline = $false
			)
		]
		[String]
		$username = '',
		[
			parameter(
				Mandatory = $false,
				HelpMessage = "Password, if required",
				ValueFromPipeline = $false
			)
		]
		[String]
		$password = '',
		[
			parameter(
				Mandatory = $false,
				HelpMessage = "Look up the etag, if required for resource matching",
				ValueFromPipeline = $false
			)
		]
		[Switch]
		$etag,
		[
			parameter(
				Mandatory = $false,
				HelpMessage = "Specify the body content if required (PUT/POST)",
				ValueFromPipeline = $false
			)
		]
		[String]
		$body = $null
	)

	BEGIN {
		# Build Url from supplied uri parameter
		$Url = "https://$target" + $uri

	}

	PROCESS {
		
		if( $username -ne '' -and $password -ne '') {
			# Create authentication header with base64 encoding
			$EncodedAuthorization = [System.Text.Encoding]::UTF8.GetBytes($username + ':' + $password)
			$EncodedPassword = [System.Convert]::ToBase64String($EncodedAuthorization)

			# Construct headers with authentication data + expected Accept header (xml / json)
			$headers = @{"Authorization" = "Basic $EncodedPassword"}
			$headers.Add("Accept", "application/xml")
			if( ($method -eq 'PUT') -and $etag ) {
				$wr = Invoke-WebRequest -Uri $Url -Headers $headers
				$etagVal = $wr.headers.etag
				Write-Verbose "Etag retreived: $etagVal"
				if( $etagVal -ne '' ) {
					$headers.Add("If-Match", $etagVal)
				}
			}
			#$headers.Add("Accept", "application/json")
		} else {
			$headers = ''
		}

		# Build Invoke-RestMethod request
		try
		{
			if (!$body) {
				$HttpRes = Invoke-RestMethod -Uri $Url -Method $method -Headers $headers
			}
			else {
				$HttpRes = Invoke-RestMethod -Uri $Url -Method $method -Headers $headers -Body $body -ContentType "application/xml"
			}
		}
		catch {
			Write-Host -ForegroundColor Red "Error connecting to $Url"
			Write-Host -ForegroundColor Red $_.Exception.Message
		}

		# If the response to the HTTP request is OK,
		if ($HttpRes) {
			return $HttpRes
		}
	}
	END {
			# What to do here ?
	}
} # End Http-rest-xml

# create a repeating Windows Scheduled Task in PowerShell to run LabCheck
Function Create-LabCheck-Task
{
	<#
	.SYNOPSIS
		This function creates a Windows Scheduled Task for the LabCheck use case from XML due to PS bug with -RunOnlyIfIdle
	.DESCRIPTION
		This function creates a Windows Scheduled Task for the LabCheck use case from XML due to PS bug with -RunOnlyIfIdle
	.INPUTS
		Integer: interval (LabCheck interval in hours which must be longer than $maxMinutesBeforeFail)
	.OUTPUTS
		Windows Scheduled Task object.
	.LINK
		None.
	#>
	[CmdletBinding()]
	PARAM(
		[
			parameter(
				Mandatory = $true,
				HelpMessage = "Specify the LabCheck run interval must be longer than maxMinutesBeforeFail",
				ValueFromPipeline = $false
			)
		]
		[int]
		$interval
	)
		BEGIN {
		# verify that the LabChek interval is longer than $maxMinutesBeforeFail
		If ( $interval -lt ($maxMinutesBeforeFail / 60) ) { 
			Write-Host "LabCheck interval ($interval hours) must be longer than maxMinutesBeforeFail ($maxMinutesBeforeFail minutes)"
			Exit
		}
		# Build the variables needed for the Task XML
		$xmlInterval = "PT" + $interval + "H" # how often should LabCheck run?
		# set the task to run for a year. A prepop should not be around anywhere near this long.
		$taskDuration = 365
		$xmlDuration = "P" + $taskDuration + "D"
		# $taskStart is offset from current time by $interval
		$taskStart =(Get-Date -DisplayHint time).AddMinutes($interval*60)
		#Write-Host $taskStart
		$xmlStart = '{0:yyyy}-{0:MM}-{0:dd}T{0:HH}:{0:mm}:{0:ss}' -f $taskStart
	}

	PROCESS {
		# build the Task XML
		$taskXML = "<?xml version=`"1.0`" encoding=`"UTF-16`"?>
<Task version=`"1.3`" xmlns=`"http://schemas.microsoft.com/windows/2004/02/mit/task`">
  <RegistrationInfo>
    <Author>CORP\Administrator</Author>
    <Description>LabCheck</Description>
  </RegistrationInfo>
  <Triggers>
    <TimeTrigger>
      <Repetition>
        <Interval>$xmlInterval</Interval>
        <Duration>$xmlDuration</Duration>
        <StopAtDurationEnd>true</StopAtDurationEnd>
      </Repetition>
      <StartBoundary>$xmlStart</StartBoundary>
      <Enabled>true</Enabled>
    </TimeTrigger>
  </Triggers>
  <Principals>
    <Principal id=`"Author`">
      <RunLevel>LeastPrivilege</RunLevel>
      <UserId>CORP\Administrator</UserId>
      <LogonType>InteractiveToken</LogonType>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <Duration>PT10M</Duration>
      <WaitTimeout>PT9H30M</WaitTimeout>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>true</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>P3D</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context=`"Author`">
    <Exec>
      <Command>C:\hol\LabCheck.bat</Command>
    </Exec>
  </Actions>
</Task>"
		$registeredTask = Register-ScheduledTask -Xml "$taskXML" -Force -TaskName "LabCheck"
	}
	
	END {
		return $registeredTask
	}

} # End Create-LabCheck-Task
