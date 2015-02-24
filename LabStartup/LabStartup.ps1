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


# include the LabStartup functions
. ".\LabStartupFunctions.ps1"

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

# Virtual Machines to be powered on
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

##############################################################################
##### Preliminary Tasks
##############################################################################

#Remove the file that causes a "Reset" message in Firefox
$userProfilePath = (Get-Childitem env:UserProfile).Value
$firefoxProfiles = Get-ChildItem (Join-Path $userProfilePath 'AppData\Roaming\Mozilla\Firefox\Profiles')
ForEach ($firefoxProfile in $firefoxProfiles) {
	$firefoxLock = Join-Path $firefoxProfile.FullName 'parent.lock'
	If(Test-Path $firefoxLock) { Remove-Item $firefoxLock | Out-Null }
}

# Determine the Lab SKU by parsing the desktopinfo.ini file
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

#Load the VMware PowerCLI tools
Try {
  Add-PSSnapin VMware.VimAutomation.Core -ErrorAction 1 
} 
Catch {
	Write-Host "No PowerCLI found, unable to continue."
	Write-Progress "FAIL - No PowerCLI" 'FAIL-1'
	Exit
}

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

# use the simple function to connect to vCenters if vC is reliable
#Connect-vCenter $vCenters

# or attempt to connect to each vCenter and restart if no connection by $vcBootMinutes
# also verifies NGC URL is available and restart if no connection by $ngcBootMinutes
# only ONE vCenter restart will be attempted then the lab will fail.
Connect-Restart-vCenter $vCenters

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
		    Write-Host $line
		}
		Start-Sleep 5
	} Until ($result -eq "success")

#>

#Write-Progress "Finished Additional Tests" 'GOOD-5'


#Report Final State
Write-Progress "Ready" 'READY'
Write-Output $( "$(Get-Date) LabStartup Finished - runtime was {0:N0} minutes." -f  ((Get-RuntimeSeconds $startTime) / 60) )
##############################################################################
