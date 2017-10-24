<#
.SYNOPSIS
Performs  tasks to ensure that a vPod is ready to run, providing feedback to the user 
via DesktopInfo and the HOL management system via the IP address on vpodrouter NIC eth5.

.DESCRIPTION
Checks storage, connects to vCenter(s), powers up vVMs/vApps, waits for availability of services 
on TCP ports or via URLs. Records detailed progress to a log file and simple status into a file 
for consumption by DesktopInfo. Modifies 6th NIC on vpodrouter to report status upstream.

.NOTES
LabStartup.ps1 - version 2.0 - 25 September 2017

.EXAMPLE
LabStartup.ps1
.EXAMPLE
C:\WINDOWS\system32\windowspowershell\v1.0\powershell.exe -windowstyle hidden "& 'c:\HOL\LabStartup.ps1'"
#>

#Disable name validation until we have a chance to update everything
$LabStartupModulePath = 'C:\HOL\LabStartupFunctions.psm1'
If( Test-Path $LabStartupModulePath ) { Import-Module $LabStartupModulePath -DisableNameChecking }
#Run the module's Init function (sets global $startTime value to NOW)
Init
Write-Output "$startTime beginning LabStartup"

#ATTENTION: Remove the next three lines when you implement this script for your pod
Set-Content -Value "Implement LabStartup" -Path $statusFile
Write-Output "LabStartup script has not been implemented yet. Please ask for assistance if you need it."
Exit

##############################################################################
##### User Variables
##############################################################################

# You must update this variable to the co-op ID of your lab.
# For example, "HOL-1910"
$vPodSKU = 'HOL-BADSKU'

# Credentials used to login to vCenters
# vcuser could be "root" if using ESXi host only
$vcuser = 'Administrator@corp.local'
$password = 'VMware1!'

# Credentials used to login to Linux machines
$linuxuser = 'root'
$linuxpassword = 'VMware1!'

#must be defined in order to pass as reference for looping
$result = ''

##############################################################################
### Populate the following with values appropriate to your lab
##############################################################################

# these arrays are populated with values stored in files in C:\HOL\Resources
$theArrays = ("VCENTERS","ESXIHOSTS","DATASTORES",
				"WINDOWSSERVICES","LINNUXSERVICES",
				"VMS","VAPPS",
				"TCPSERVICES","PINGS","URLS" )

$theArrays | % {
	Set-Variable -Name $_ -Value $(Read-FileIntoArray $_) -Scope Global
}

##############################################################################
##### Preliminary Tasks
##############################################################################

###
# Record whether this is a first run or a LabCheck execution
$LabCheck = Test-LabCheck $args[0]

###
#Perform some cleanup. Uses the LabCheck variable to ensure these happen at pod startup only
If( -not $LabCheck ) {
    CleanFirefoxAnnoyFile
    ResetModuleSwitcherState
}

###
# Use the configured Lab SKU to configure eth5 on vpodrouter
# A bad SKU is a hard failure
Parse-LabSKU $vPodSKU

#Lack of PowerCLI is fatal: DO NOT UNINSTALL POWERCLI FROM THE VPOD
Test-PowerCLI

##############################################################################
##### Main LabStartup
##############################################################################

If ( $labcheck ) {
	Write-Host "`n$(Get-Date)LabCheck is active. Skipping Start-AutoLab."
} Else {
	#Please leave this line here to enable scale testing automation 
	If( Start-AutoLab ) { Exit } Write-Output "No autolab.ps1 found, continuing."
}

#Report Initial State
# Write-Output writes to the C:\HOL\Labstartup.log file
# Write-VpodProgress writes to the DesktopInfo
Write-Output "`n$(Get-Date) Beginning Main script"
Write-VpodProgress "Not Ready" 'STARTING'

##############################################################################
##### Lab Startup - STEP #1 (Infrastructure) 
##############################################################################

###
#Testing that vESXi hosts are online: all hosts must respond before continuing
Write-VpodProgress "Checking vESXi" 'STARTING'
Foreach ($ESXihost in $ESXiHosts) {
	#check all on port 22
	Do {
		Test-TcpPortOpen $ESXiHost 22 ([REF]$result)
		LabStartup-Sleep $sleepSeconds
	} Until ($result -eq "success")
}

###
# Attempt to connect to each vCenter. Restart if no connection within $vcBootMinutes
# only ONE vCenter restart will be attempted then the lab will fail.
# this could be an ESXi host although no restart will be attempted.
Write-VpodProgress "Connecting vCenters" 'STARTING'
$maxMins = 0
Connect-Restart-vCenter $vCenters ([REF]$maxMins)
$maxMinutesBeforeFail = $maxMins

###
# Check the FreeNAS datastores and reboot storage if necessary
# a reboot is rare and typically only needed for NFS share failure
Foreach ($dsLine in $datastores) {
	Do { 
		Check-Datastore $dsLine ([REF]$result)
		LabStartup-Sleep $sleepSeconds
	} Until ($result -eq "success")
}

##############################################################################
##### Lab Startup - STEP #2 (Starting Nested VMs and vApps) 
##############################################################################

###
# Use the Start-Nested function to start batches of nested VMs and/or vApps
# Create additional arrays for each batch of VMs and/or vApps
# Insert a LabStartup-Sleep as needed if a pause is desired between batches
# Or include additional tests for services after each batch and before the next batch

Write-VpodProgress "Starting vVMs" 'GOOD-1'
Write-Output "$(Get-Date) Starting vApps"
Start-Nested $vApps
Write-Output "$(Get-Date) Starting vVMs"
Start-Nested $VMs

###
# Disconnect from vCenters
# Do not do this here if you need to perform other actions within vCenter
#  in that case, move this block later in the script. Need help? Please ask!

Foreach ($entry in $vCenters) {
	($vcserver,$type) = $entry.Split(":")
	Write-Output "$(Get-Date) disconnecting from $vcserver ..."
	Disconnect-VIServer -Server $vcserver -Confirm:$false
}

##############################################################################
##### Lab Startup - STEP #3 (Testing Pings) 
##############################################################################

###
# Wait here for all hosts in the $Pings array to respond before continuing
Write-VpodProgress "Waiting for pings" 'GOOD-2'
Foreach ($ping in $Pings) {
	Do { 
		Test-Ping $ping ([REF]$result)
		LabStartup-Sleep $sleepSeconds
	} Until ($result -eq "success")
}

##############################################################################
##### Lab Startup - STEP #4 (Start/Restart/Stop/Query Services and test ports) 
##############################################################################

###
# Manage Windows services on local or remote Windows machines
Write-VpodProgress "Manage Win Svcs" 'GOOD-3'
StartWindowsServices $windowsServices
Write-Output "$(Get-Date) Finished start Windows services"

###
# Manage Linux services on remote machines
Write-VpodProgress "Manage Linux Svcs" 'GOOD-3'
# options are "start", "restart", "stop" or "query"
$action = "start"
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

###
#Ensure services in the $TCPServices array are answering on specified ports 
Write-VpodProgress "Testing TCP ports" 'GOOD-3'
Foreach ($service in $TCPservices) {
	($server,$port) = $service.Split(":")
	Do { 
		Test-TcpPortOpen $server $port ([REF]$result)
		LabStartup-Sleep $sleepSeconds
	} Until ($result -eq "success")
}
Write-Output "$(Get-Date) Finished testing TCP ports"

##############################################################################
##### Lab Startup - STEP #5 (Testing URLs) 
##############################################################################

###
#Testing URLs
# Uncomment "-Verbose" to see the HTML returned for pattern matching
Write-VpodProgress "Checking URLs" 'GOOD-4'
Foreach ($entry in $URLs) {
	($url,$response) = $entry.Split(",")
	Do { 
		Test-URL $url $response ([REF]$result) # -Verbose
		LabStartup-Sleep $sleepSeconds
	} Until ($result -eq "success")
}

##############################################################################
##### Lab Startup - STEP #6 (Final validation) 
##############################################################################

###
# Add final checks here that are required for your vPod to be marked READY
# Maybe you need to check something after the services are started/restarted.

Write-VpodProgress "Starting Additional Tests" 'GOOD-5'

Write-Output "$(Get-Date) Running Additional Tests"

Write-VpodProgress "Finished Additional Tests" 'GOOD-5'

###
# create the Scheduled Task to run LabStartup at the interval indicated and record initial ready time
If ( -Not $LabCheck ) {
	Write-Host "Creating Windows Scheduled Task to run LabStartup every $LabCheckInterval hours..."
	$LabCheckTask = Create-LabCheckTask $LabCheckInterval
	# Since vPodRouter might be rebooted, record initial ready time for LabCheck
	$readyTime = [Math]::Round( (Get-RuntimeSeconds $startTime) / 60)
	Set-Content -Value ($readyTime) -Path $readyTimeFile
}

###
# EXPERIMENTAL
# try to determine current cloud using vPodRouter guestinfo
$cloudInfo = Get-CloudInfo
Write-Host $cloudInfo

###
# Report Ready state and duration of run
# NOTE: setting READY marks the DesktopInfo badge GREEN
Write-VpodProgress "Ready" 'READY'
Write-Output $( "$(Get-Date) LabStartup Finished - runtime was {0:N0} minutes." -f  ((Get-RuntimeSeconds $startTime) / 60) )

##############################################################################
