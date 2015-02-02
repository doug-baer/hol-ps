# starts the nested VMs or vApps
Function Start-Nested ( [array] $records ) {

	ForEach ($record in $records) {
		# separate out the vVM name and the owning vCenter
		($name,$vcenter) = $record.Split(":")
		# If blank, default to the first/only vCenter
		If( $vcenter -eq $null ) { $vcenter = $vCenters[0] }
		
		If( $vApp = Get-VApp -Name $name -Server $vcenter -ea 0 ) {
			$type = "vApp"
			$startCMD = "Start-VApp -VApp $vApp -RunAsync -Server $vcenter"
			$getCMD = "Get-VApp $name -Server $vcenter"
			$powerState = [string]$vApp.Status
			$goodPower = "Started"
		} ElseIf( $vm = Get-VM -Name $name -Server $vcenter -ea 0 ) {
			$type = "vVM"
			$startCMD = "Start-VM -VM $vm -RunAsync -Server $vcenter"
			$getCMD = "Get-VM $name -Server $vcenter"
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
				$task = Invoke-Expression $startCMD
				If ( $type -eq "vVM" ) {
					$tasks = Get-Task -Server $vcenter
					ForEach ($task in $tasks) {
						If ($task.ObjectId -eq $vm.Id) { Break }
					}
				}
			}
			LabStartup-Sleep $sleepSeconds
			$task = Get-Task -Id $task.Id -Server $vcenter
			$entity = Invoke-Expression $getCMD
			If ( $type -eq "vApp") { $powerState = [string]$entity.Status }
			Else { $powerState = [string]$entity.PowerState }
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