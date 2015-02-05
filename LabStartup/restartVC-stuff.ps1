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
	$msg = ''
	If ($server.Contains("vcsa") ) {
		# vSphere 6 appliance is most likely
		Write-Host "Trying appliance vCenter 6 reboot..."
		$lcmd = "shutdown reboot -r now 2>&1"
		$msg = Invoke-Plink -remoteHost $server -login $linuxuser -passwd $linuxpassword -command $lcmd
		If ( $msg.Contains("The system is going down for reboot NOW!") ) { $result.Value = "success" }
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
Foreach ($vcserver in $vCenters) {
	$VCrestarted = $false
	$ctr = 0
	Do {
		Connect-VC $vcserver $vcuser $password ([REF]$result)
		LabStartup-Sleep $sleepSeconds
		$ctr++
		If ( $ctr -eq 60 ) { 
			If ( $VCrestarted -eq $false ) {  # try restarting vCenter to fix the issue
				Write-Output "Restarting vCenter $vcserver" 
				Restart-VC $vcserver ([REF]$VCrestarted)
				If ($VCrestarted -eq "success") { 
					$maxMinutesBeforeFail = $maxMinutesBeforeFail + 10
					$ctr = 0
				} Else {
					LabFail "Cannot restart vCenter $vcserver.  Failing lab."
				}
			} 
		}
		If ( ($ctr -eq 60) -And ($VCrestarted -eq "success" ) ) {
			$currentRunningSeconds = Get-RuntimeSeconds $startTime
			$currentRunningMinutes = $currentRunningSeconds / 60
			LabFail "Failing the lab after restarting vCenter $vcserver"
		}
	} Until ($result -eq "success")
}

#Testing URLs
Foreach ($url in $($URLs.Keys)) {
	$isVC = $false
	$VCrestarted = $false
	$ctr = 0
    Foreach ( $vc in $vCenters ) {
		If ( $url.Contains( $vc ) ) { $isVC = $true}
	}
	Do { 
		Test-URL $url $URLs[$url] ([REF]$result)
		LabStartup-Sleep $sleepSeconds
		If ( ($ctr -eq 60) -And ($isVC) ) { 
			If ( $VCrestarted -eq $false ) {  # try restarting vCenter to fix the issue
				Write-Output "Restarting vCenter $vcserver" 
				Restart-VC $vcserver ([REF]$VCrestarted)
				If ($VCrestarted -eq "success") { 
					$maxMinutesBeforeFail = $maxMinutesBeforeFail + 10
					$ctr = 0
				} Else {
					LabFail "Cannot restart vCenter $vcserver.  Failing lab."
				}
			} 
		}
		If ( ($ctr -eq 60) -And ($VCrestarted -eq "success" ) -And ($isVC) ) {
			$currentRunningSeconds = Get-RuntimeSeconds $startTime
			$currentRunningMinutes = $currentRunningSeconds / 60
			LabFail "Failing the lab after restarting vCenter $vcserver"
		}
	} Until ($result -eq "success")
}
