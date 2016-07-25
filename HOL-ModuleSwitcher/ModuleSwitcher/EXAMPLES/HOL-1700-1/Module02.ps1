#
#  Module02.ps1 - Module 2 Start/Stop Script EXAMPLE
#

#Path to HOL directory in the vPod (to get LabStartupFunctions.ps1)
$holPath = 'C:\HOL'
#This script's module number and the lab's SKU -- for output clarity and reusability
$moduleNumber = 2
$labSKU = 'HOL-1700-MBL-1'
#some of the LabStartupFunctions need a temp variable to communicate status
$result = ''

#### VARIABLES

#EXAMPLE: prepare an array of vVMs to start or stop, along with the vCenter that owns each
#  these are defined outside of the functions because it is expected that the same set
#  will be acted upon by both START and STOP
$thisModuleVMs = ('db-01a:vcsa-01a.corp.local','web-01a:vcsa-01a.corp.local')	


<#
	ModuleStart is the function called by the START action, encapsulated 
	within a function to simplify the main logic
#>
Function ModuleStart {
	$startTime = $(Get-Date)
	Write-Host "Beginning $labSKU Module $moduleNumber START @ $StartTime"
	
	LoadPowerCLI
	#Load LabStartupFunctions
	$InvocationPath = Join-Path $holPath 'LabStartupFunctions.ps1'
	if( Test-Path $InvocationPath ) {
		Write-Host -ForegroundColor Green "Loading functions from $InvocationPath"
		. $InvocationPath
	} else {
		Write-Host -ForegroundColor Red "ERROR: Unable to find $InvocationPath"
		Break
	}
		
	#TODO: Write your Module START code here

	Connect-VC 'vcsa-01a.corp.local' 'administrator@corp.local' 'VMware1!' ([REF]$result)

	foreach( $record in $thisModuleVMs ) {
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
	
	#EXAMPLE: Send output to the console for the user
	Write-Host -ForegroundColor Green "Activating the Chaos Monkey..."
	#You can do other things you need here like starting/stopping services
	#  deleting or copying files, killing time, or even configuring VSAN
	
	Start-Sleep -Seconds 5
	
	Write-Host "Disconnecting from vCenter(s)"
	Disconnect-Viserver * -Confirm:$false
	
	Write-Host $( "$(Get-Date) Finished. Runtime was {0:N0} minutes." -f  ((Get-RuntimeSeconds $startTime) / 60) )
	
} #ModuleStart

##########################################################################

<#
	ModuleStop is the function called by the STOP action, encapsulated 
	within a function to simplify the main logic
#>
Function ModuleStop {
	$startTime = $(Get-Date)
	Write-Host "Beginning $labSKU Module $moduleNumber STOP @ $StartTime"

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
	
	Connect-VC 'vcsa-01a.corp.local' 'administrator@corp.local' 'VMware1!' ([REF]$result)

	foreach( $record in $thisModuleVMs ) {
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

	#EXAMPLE: Send output to the console for the user
	Write-Host -ForegroundColor Green "Deactivating the Chaos Monkey... whew!"
	#You can UNdo other things here like starting/stopping services
	#  deleting or copying files, killing time, or even nuking your VSAN

	Start-Sleep -Seconds 5
	
	Write-Host "Disconnecting from vCenter(s)"
	Disconnect-Viserver * -Confirm:$false

	Write-Host $( "$(Get-Date) Finished. Runtime was {0:N0} minutes." -f  ((Get-RuntimeSeconds $startTime) / 60) )

} #ModuleStop

##########################################################################
### Nothing that follows requires modification
##########################################################################

## Supporting Functions

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


## Main program logic

if( $args[0] -eq 'START' ) {
	ModuleStart
} else {
	ModuleStop
}
#Pause at the end so that the user can see any messages and control the exit
PAUSE
