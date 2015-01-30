# starts the nested VMs or vApps
Function Start-Nested ( [array] $records ) {

	ForEach ($record in $records) {
		# separate out the vVM name and the owning vCenter
		($name,$vcenter) = $record.Split(":")
		# If blank, default to the first/only vCenter
		If( $vcenter -eq $null ) { $vcenter = $vCenters[0] }
		
		# start vApps
		If( $vApp = Get-VApp -Name $name -Server $vcenter -ea 0 ) {
			$powerState = [string]$vApp.Status
			Write-Output $("Checking vApp {0} power state: {1}" -f $vApp.Name, $powerState )
			While ( !($powerState.Contains("Started")) ) {
				If ( !($powerState.Contains("Starting")) ) {
					Write-Output $("Starting vApp {0} on {1}" -f $vApp.Name, $vcenter )
					$task = Start-VApp -VApp $vApp -RunAsync -Server $vcenter	
				}
				LabStartup-Sleep $sleepSeconds
				$task = Get-Task -Id $task.Id -Server $vcenter
				$vApp = Get-VApp $name -Server $vcenter
				$powerState = [string]$vApp.Status
				If ($task.State -eq "Error") {
						Write-Progress "FATAL ERROR" 'FAIL-2'  
						$currentRunningSeconds = Get-RuntimeSeconds $startTime
						$currentRunningMinutes = $currentRunningSeconds / 60
						Write-Output $("FAILURE: labStartup ran for {0:N0} minutes and has been terminated."  -f $currentRunningMinutes )
						Write-Output $("Cannot start vApp {0} on {1}" -f $vApp.Name, $vcenter )
						Write-Output $("Error task Id {0} task state: {1}" -f $task.Id, $task.State )
						Exit
				}
				Write-Output $("Current vApp {0} power state: {1}" -f $vApp.Name, $powerState )
				Write-Output $("Current task Id {0} task state: {1}" -f $task.Id, $task.State )
			}
		} ElseIf( $vm = Get-VM -Name $name -Server $vcenter -ea 0 ) {
			$powerState = [string]$vm.PowerState
			Write-Output $("Checking vVM {0} power state: {1}" -f $vm.Name, $powerState )
			While ( !($powerState.Contains("PoweredOn")) ) {
				If ( !($powerState.Contains("Starting")) ) {
					Write-Output $("  Starting vVM {0} on {1}" -f $vm.Name, $vcenter )
					$task = Start-VM -VM $vm -RunAsync -Server $vcenter
					$tasks = Get-Task -Server $vcenter
					ForEach ($task in $tasks) {
						If ($task.ObjectId -eq $vm.Id) { Break }
					}
					LabStartup-Sleep $sleepSeconds
					$vm = Get-VM $name -Server $vcenter
					$task = Get-Task -Id $task.Id -Server $vcenter
					$powerState = [string]$vm.PowerState
					Write-Output $("Current vVM {0} power state: {1}" -f $vm.Name, $powerState )
					Write-Output $("Current task Id {0} task state: {1}" -f $task.Id, $task.State )
					If ($task.State -eq "Error") {
						Write-Progress "FATAL ERROR" 'FAIL-2'  
						$currentRunningSeconds = Get-RuntimeSeconds $startTime
						$currentRunningMinutes = $currentRunningSeconds / 60
						Write-Output $("FAILURE: labStartup ran for {0:N0} minutes and has been terminated."  -f $currentRunningMinutes )
						Write-Output $("Cannot start vVM {0} on {1}" -f $vm.Name, $vcenter )
						Write-Output $("Error task Id {0} task state: {1}" -f $task.Id, $task.State )
						Exit
					}
				}
			}
		} Else {
			Write-Output $("ERROR: Unable to find entity {0} on {1}" -f $name, $vcenter )
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

Function Write-Progress ([string] $msg, [string] $code) {
	$myTime = $(Get-Date)
	If( $code -eq 'READY' ) {
		$dateCode = "{0:D2}/{1:D2} {2:D2}:{3:D2}" -f $myTime.month,$myTime.day,$myTime.hour,$myTime.minute
		Set-Content -Value ([byte[]][char[]] "$msg $dateCode") -Path $statusFile -Encoding Byte
	} Else {
		$dateCode = "{0:D2}:{1:D2}" -f $myTime.hour,$myTime.minute
		Set-Content -Value ([byte[]][char[]] "$dateCode $msg ") -Path $statusFile -Encoding Byte
	}
	Report-VpodStatus $code
} #End Write-Progress