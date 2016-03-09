#
#  Module02.ps1 - Module 2 Start/Stop Script EXAMPLE
#

#Path to HOL directory in the vPod
$holPath = 'C:\HOL'

#This script's module number -- for output clarity
$moduleNumber = 2

#some of the labstartup functions need a temp variable to communicate status
$result = ''

Function ModuleStart {
	$startTime = $(Get-Date)
	Write-Host "Beginning Module $moduleNumber START @ $StartTime"
	
	LoadPowerCLI
	#LoadLabStartupFunctions
	$InvocationPath = Join-Path $holPath 'LabStartupFunctions.ps1'
	if( Test-Path $InvocationPath ) {
		Write-Host -ForegroundColor Green "Loading functions from $InvocationPath"
		. $InvocationPath
	} else {
		Write-Host -ForegroundColor Red "ERROR: Unable to find $InvocationPath"
		Break
	}
		
	#TODO: Write your Module START code here

	$mod2VMs = ('db-01a:vcsa-01a.corp.local','web-01a:vcsa-01a.corp.local')
	
	Connect-VC 'vcsa-01a.corp.local' 'administrator@corp.local' 'VMware1!' ([REF]$result)

	foreach( $record in $mod2VMs ) {
		($name,$vcenter) = $record.Split(":")
		$vm = Get-VM $name -server $vcenter
		if( $vm.PowerState -eq 'PoweredOn' ) {
			Write-Host "VM $name is already running."
		} else {
			Write-Host "VM $name is starting."
			Start-VM -VM $vm -Server $vcenter -Confirm:$false -RunAsync | Out-Null
			Sleep -Sec 10
		}
	}
	
	Write-Host "Activating the Chaos Monkey..."
	#You can do other things you need here, too
	Start-Sleep -Seconds 5
	
	Write-Host "Disconnecting from vCenter(s)"
	Disconnect-Viserver * -Confirm:$false
	
	Write-Host $( "$(Get-Date) Finished. Runtime was {0:N0} minutes." -f  ((Get-RuntimeSeconds $startTime) / 60) )
	
} #ModuleStart

##########################################################################

Function ModuleStop {
	$startTime = $(Get-Date)
	Write-Host "Beginning Module $moduleNumber STOP @ $StartTime"

	LoadPowerCLI
	#LoadLabStartupFunctions
	$InvocationPath = Join-Path $holPath 'LabStartupFunctions.ps1'
	if( Test-Path $InvocationPath ) {
		Write-Host -ForegroundColor Green "Loading functions from $InvocationPath"
		. $InvocationPath
	} else {
		Write-Host -ForegroundColor Red "ERROR: Unable to find $InvocationPath"
		Break
	}
	
	#TODO: Write your Module STOP code here
	
	$mod2VMs = ('db-01a:vcsa-01a.corp.local','web-01a:vcsa-01a.corp.local')
	
	Connect-VC 'vcsa-01a.corp.local' 'administrator@corp.local' 'VMware1!' ([REF]$result)

	foreach( $record in $mod2VMs ) {
		($name,$vcenter) = $record.Split(":")
		$vm = Get-VM $name -server $vcenter
		if( $vm.PowerState -eq 'PoweredOff' ) {
			Write-Host "VM $name is already powered off."
		} else {
			if( $vm.ExtensionData.Guest.ToolsRunningStatus -eq 'guestToolsRunning' ) {
				Write-Host "VM $name is shutting down."
				Stop-VMGuest -VM $vm -Server $vcenter -Confirm:$false | Out-Null
				Sleep -Sec 20
			} else {
				Write-Host "VM $name is being powered off."
				Stop-VM -VM $vm -server $vcenter -RunAsync -Confirm:$false | Out-Null
			}
		}
	}

	Write-Host "Deactivating the Chaos Monkey..."
	#You can undo other things you need here, too
	Start-Sleep -Seconds 5
	
	Write-Host "Disconnecting from vCenter(s)"
	Disconnect-Viserver * -Confirm:$false

	Write-Host $( "$(Get-Date) Finished. Runtime was {0:N0} minutes." -f  ((Get-RuntimeSeconds $startTime) / 60) )

} #ModuleStop



##########################################################################
# supporting functions

Function LoadPowerCLI {
	Try {
		#For PowerCLI v6.x
		$PowerCliInit = 'C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1'
		Write-Host -ForegroundColor Green "Loading PowerCLI"
		. $PowerCliInit
	} 
	Catch {
		Write-Host -ForegroundColor Red "No PowerCLI found, unable to continue."
		Break
	} 
} #LoadPowerCLI

##########################################################################
# The main program logic

if( $args[0] -eq 'START' ) {
	ModuleStart
} else {
	ModuleStop
}
#Pause at the end so that the user can see any messages and control the exit
Pause
