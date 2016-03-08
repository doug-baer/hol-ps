#
#  Module02.ps1 - Module 2 Start/Stop Script
#

#Path to HOL directory in the vPod
$holPath = 'C:\HOL'
#This module number -- for output clarity
$moduleNumber = 2

Function ModuleStart {
	$startTime = $(Get-Date)
	Write-Host "Beginning Module $moduleNumber START @ $StartTime"
	
	LoadPowerCLI

	# include the HOL LabStartupFunctions
	$InvocationPath = Join-Path $holPath 'LabStartupFunctions.ps1'
	if( Test-Path $InvocationPath ) {
		. $InvocationPath
		Write-Verbose "Loading functions from $InvocationPath"
	} else {
		Write-Verbose -Fore Red "ERROR: Unable to find $InvocationPath"
		Break
	}
	
	#TODO: Write your Module START code here
	
	Write-Host $( "$(Get-Date) Finished. Runtime was {0:N0} minutes." -f  ((Get-RuntimeSeconds $startTime) / 60) )
	
} #ModuleStart

##########################################################################

Function ModuleStop {
	$startTime = $(Get-Date)
	Write-Host "Beginning Module $moduleNumber STOP @ $StartTime"

	LoadPowerCLI
	
	#TODO: Write your Module STOP code here

	Write-Host $( "$(Get-Date) Finished. Runtime was {0:N0} minutes." -f  ((Get-RuntimeSeconds $startTime) / 60) )

} #ModuleStop

##########################################################################
# supporting functions

Function LoadPowerCLI {
	Try {
		#For PowerCLI v6.x
		$PowerCliInit = 'C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1'
		. $PowerCliInit
	} 
	Catch {
		Write-Host "No PowerCLI found, unable to continue."
		Break
	} 
}

##########################################################################
# The main program logic

if( $args[0] -eq 'START' ) {
	ModuleStart
} else {
	ModuleStop
}
#Pause at the end so that the user can see any messages and control the exit
Pause
