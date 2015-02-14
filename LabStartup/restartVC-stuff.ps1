# number of minutes it takes vCenter to boot before API connection
$vcBootMinutes = 10
# number of minutes it takes for vSphere Web Client URL
$ngcBootMinutes = 15

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


Write-Progress "Connecting vCenter" 'STARTING'
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

#Testing URLs
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
