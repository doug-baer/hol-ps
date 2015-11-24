<#

.SYNOPSIS
Performs various tasks to ensure that a vPod is ready to run, and then provides 
feedback to the user (via DesktopInfo) and HOL management system via vpodrouter NIC.

.DESCRIPTION
Checks storage, connects to vCenter(s), powers up vVMs/vApps, waits for availability of services 
on TCP ports or via URLs. Records progress into a log file and simple status into a file 
for consumption by DesktopInfo. Modifies 6th NIC on vpodrouter to report status upstream.

.NOTES
LabStartup.ps1 v4.1 - November 23, 2015 
* A majority of the functions are loaded via C:\HOL\LabStartupFunctons.ps1
* URLs must begin with http:// or https:// (with valid certificate)
* The IP address on the eth5 NIC of the vpodrouter is set using SSH (plink.exe) 
  and sudo (installed on the vpodrouter) using the holuser account. 
* NEW: set $vPodSKU variable to pod's SKU

.EXAMPLE
LabStartup.ps1
.EXAMPLE
C:\WINDOWS\system32\windowspowershell\v1.0\powershell.exe -windowstyle hidden "& 'c:\HOL\LabStartup.ps1'"

.INPUTS
NONE

.OUTPUTS
Log messages are written to the console or redirected to an output file and 
C:\HOL\startup_status.txt ($statusFile) is updated with periodic status for consumption by DesktopInfo.exe using the Write-Progress function.
The IP address of the 6th NIC on the vpodrouter (router.corp.local) is modified 
with an encoded status code as the script progresses.
Upon failure, whether explicit or via script timeout, the script will set the FAILURE 
indicator and halt
#>

# include the LabStartup functions from the same directory as LabStartup.ps1
$Invocation = (Get-Variable MyInvocation).Value
$InvocationPath = Join-Path (Split-Path $Invocation.MyCommand.Path) 'LabStartupFunctions.ps1'
If( Test-Path $InvocationPath ) {
	. $InvocationPath
	Write-Verbose "Loading functions from $InvocationPath"
} Else {
	Write-Verbose -Fore Red "ERROR: Unable to find $InvocationPath"
	Break
}

$startTime = $(Get-Date)
Write-Output "$startTime beginning LabStartup"

##############################################################################
##### User Variables
##############################################################################

#The SKU of this pod
$vPodSKU = 'HOL-XXX-1799'

# Credentials used to login to vCenters
$vcuser = 'Administrator@corp.local'
$password = 'VMware1!'

# Credentials used to login to Linux machines
$linuxuser = 'root'
$linuxpassword = 'VMware1!'

#Set the root of the script
$labStartupRoot = 'C:\HOL'
#this file is used to report status via DesktopInfo
$statusFile = Join-Path $labStartupRoot 'startup_status.txt'
# sleep time between checks
$sleepSeconds = 10
# number of minutes it takes vCenter to boot before API connection
$vcBootMinutes = 10
# if still running this long, fail the pod (pod Timeout)
$maxMinutesBeforeFail = 30
# path to Plink.exe -- for status & managing Linux
$plinkPath =  Join-Path $labStartupRoot 'Tools\plink.exe'
# path to pscp.exe -- for transferring files to Linux
# you must place pscp.exe in this path in order to use the Invoke-Pscp function
$pscpPath =  Join-Path $labStartupRoot 'Tools\pscp.exe'
# path to desktopInfo file for status reporting
$desktopInfoIni = 'C:\DesktopInfo\DesktopInfo.ini'
#must be defined in order to pass as reference for looping
$result = ''


##############################################################################
### Populate the following with values appropriate to your lab
##############################################################################

#FQDN(s) of vCenter server(s)
$vCenters = @(
	'vcsa-01a.corp.local'
)
# Will test ESXi hosts are responding on port 22
# be sure to enable SSH on all HOL vESXi hosts
$ESXiHosts = @(
	'esx-01a.corp.local:22'
	'esx-02a.corp.local:22'
)

# FreeNAS NFS datastore names in vCenter
$datastores = @(
	'stga-01a.corp.local:ds-site-a-nfs01'
)

#Windows Services to be checked / started
$windowsServices = @(
#	'controlcenter.corp.local:VMTools'
)

#Linux Services to be checked / started
$linuxServices = @(
#	'router.corp.local:vmware-tools'
#	'vcsa-01a.corp.local:vsphere-client'
)

# Nested Virtual Machines to be powered on
# if multiple vCenters, specify the FQDN of the owning vCenter after the colon
# optionally indicate a pause with the "Pause" record.  In this case the number 
#  after the colon is the number of seconds to wait before continuing.
$VMs = @(
#	'linux-base-01a'
#	'Pause:30'
#	'linux-desk-01a:vcsa-01a.corp.local'
	)

# as with vVMs, the format of these entries is VAPPNAME:VCENTER
$vApps = @(
#	'example vApp:vcsa-01a.corp.local'
)

#TCP Ports to be checked
$TCPservices = @(
#	'vcsa-01a.corp.local:443'
)

#URLs to be checked for specified text in response
$URLs = @{
	'https://vcsa-01a.corp.local/vsphere-client/' = 'vSphere Web Client'
	'http://stga-01a.corp.local/account/login' = 'FreeNAS'
	'https://psc-01a.corp.local/websso/' = 'Welcome'
	}

# IP addresses to be pinged
$Pings = @(
	'192.168.110.1'
)

##############################################################################
##### Preliminary Tasks
##############################################################################

#Remove the file that causes the "Reset" message in Firefox
$userProfilePath = (Get-Childitem env:UserProfile).Value
$firefoxProfiles = Get-ChildItem (Join-Path $userProfilePath 'AppData\Roaming\Mozilla\Firefox\Profiles')
Foreach ($firefoxProfile in $firefoxProfiles) {
	$firefoxLock = Join-Path $firefoxProfile.FullName 'parent.lock'
		Try {
			Remove-Item $firefoxLock -ErrorAction SilentlyContinue | Out-Null 
		}
		Catch {
			Write-Output "Firefox parent.lock not removed."
		}
} #END Fix Firefox Reset Message

# Use the configured Lab SKU to configure eth5 on vpodrouter
# bad SKU is a failure
$TMP = $vPodSKU.Split('-')
Try {
# the YEAR is the first two characters of the last field as an integer
	$YEAR = [int]$TMP[2].SubString(0,2)
	# the SKU is the rest of the last field beginning with the third character as an integer (no leading zeroes)
	$SKU = [int]$TMP[2].SubString(2)
	$IPNET = "192.$YEAR.$SKU"
}
Catch {
	# Problems: Use the default IP network and FAIL
	Write-Output "ERROR - malformed lab SKU: $TMP"
	$IPNET= '192.168.250'
	# fail the script 
	Write-Progress "FAIL-Bad Lab SKU" 'FAIL-1'
}


#Load the VMware PowerCLI tools - no PowerCLI is fatal. 
## DO NOT UNINSTALL POWERCLI FROM THE VPOD
Try {
	#For PowerCLI v6.x
	$PowerCliInit = 'C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1'
	. $PowerCliInit
} 
Catch {
	Write-Host "No PowerCLI found, unable to continue."
	Write-Progress "FAIL - No PowerCLI" 'FAIL-1'
	Break
} 

##############################################################################
##### Main LabStartup
##############################################################################

#Please leave this line here to enable scale testing automation 
If( Start-AutoLab ) { Exit } Write-Output "No autolab.ps1 found, continuing."

#ATTENTION: Remove the next three lines when you implement this script for your pod
Set-Content -Value "Implement LabStartup" -Path $statusFile
Write-Output "LabStartup script has not been implemented yet. Please ask for assistance if you need it."
Exit


#Report Initial State
# Write-Output writes to the C:\HOL\Labstartup.log file
# Write-Progress writes to the DesktopInfo
Write-Output "$(Get-Date) Beginning Main script"
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

<<<<<<< HEAD
# attempt to connect to each vCenter and restart if no connection by $vcBootMinutes
=======
# Attempt to connect to each vCenter. Restart if no connection within $vcBootMinutes
# also verifies NGC URL is available and restarts if no connection by $ngcBootMinutes
>>>>>>> origin/master
# only ONE vCenter restart will be attempted then the lab will fail.
$maxMins = 0
Connect-Restart-vCenter $vCenters ([REF]$maxMins)
$maxMinutesBeforeFail = $maxMins

# check the FreeNAS NFS datastores and reboot storage if necessary 
Foreach ($dsLine in $datastores) {
	Do { 
		Check-Datastore $dsLine ([REF]$result)
		LabStartup-Sleep $sleepSeconds
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
##### Lab Startup - STEP #3 (Testing Pings & Ports) 
##############################################################################

Write-Progress "Testing TCP ports" 'GOOD-3'

# Wait for hosts in the $Pings array to respond
Foreach ($ping in $Pings) {
	Do { 
		Test-Ping $ping ([REF]$result)
		LabStartup-Sleep $sleepSeconds
	} Until ($result -eq "success")
}

#Ensure services in the $TCPServices array are answering on specified ports 
Foreach ($service in $TCPservices) {
	($server,$port) = $service.Split(":")
	Do { 
		Test-TcpPortOpen $server $port ([REF]$result)
		LabStartup-Sleep $sleepSeconds
	} Until ($result -eq "success")
}

##############################################################################
##### Lab Startup - STEP #4 (Start/Restart/Stop/Query Services) 
##############################################################################

Write-Progress "Manage Win Svcs" 'GOOD-4'

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
##### Lab Startup - STEP #5 (Testing URLs) 
##############################################################################

Write-Progress "Checking URLs" 'GOOD-5'

#Testing URLs
Foreach ($url in $($URLs.Keys)) {
	Do { 
		Test-URL $url $URLs[$url] ([REF]$result)
		LabStartup-Sleep $sleepSeconds
	} Until ($result -eq "success")
}


#Write-Progress "Starting Additional Tests" 'GOOD-5'
## Any final checks here. Maybe you need to check something after the
## services are started/restarted.

# example RunWinCmd (Note this is commented out!)
<# 

$wcmd = "ipconfig"
Do { 
		$output = RunWinCmd $wcmd ([REF]$result)
		ForEach ($line in $output) {
		    Write-Output $line
		}
		LabStartup-Sleep 5
	} Until ($result -eq "success")

#>

# example copy a file to or from Linux machine using pscp.exe
# you must have pscp.exe in the location specified by $pscpPath
# Note this example is commented out!

# use the pscp conventions for source and destination files
# remote to remote is not allowed
# source must be a regular file and not a folder
# destination can be a folder
<#

$source = 'full-sles-01a.corp.local:/tmp/linuxfile.log'
$dest =  Join-Path $labStartupRoot 'linuxfile.log'
Write-Output "Copying $source to $dest..."
$msg = Invoke-Pscp -login $linuxUser -passwd $linuxPassword -sourceFile $source -destFile $dest
Write-Output $msg

#>

Write-Progress "Finished Additional Tests" 'GOOD-5'


#Report final state and duration
Write-Progress "Ready" 'READY'
Write-Output $( "$(Get-Date) LabStartup Finished - runtime was {0:N0} minutes." -f  ((Get-RuntimeSeconds $startTime) / 60) )

##############################################################################
