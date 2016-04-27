#
#  Module03.ps1 - Module 3 Start/Stop Script SHELL
#

#Path to HOL directory in the vPod (to get LabStartupFunctions.ps1)
$holPath = 'C:\HOL'
#This script's module number and the lab's SKU -- for output clarity and reusability
$moduleNumber = 3
$labSKU = 'HOL-1700-MBL-1'
#some of the LabStartupFunctions need a temp variable to communicate status
$result = ''

#### VARIABLES

#EXAMPLE: lists of services, files vVMs, etc. that may be acted upon by both
#  START and STOP actions.

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
	
	
	Start-Sleep -Seconds 5
	
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

	Start-Sleep -Seconds 5
	
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
