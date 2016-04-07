##version 1.1 - April 7, 2016

Function Set-ScsiLunFlags {
<#
.SYNOPSIS
	Modifies ESXi LUN flags for a specified SCSI LUN.

.DESCRIPTION
	The Set-ScsiLunFlags function uses the ESXCLI to update the SATP claim rule for the specified SCSI LUN. Please note there is a few second delay for the claim rules to run and for the data store to show up as SSD, HDD, or Flash Capacity SSD.
	 
.PARAMETER  ScsiLun
	Use this parameter to specify the SCSI LUN you wish to enable/disable the specified option. The default option is "enable_ssd"
	
.PARAMETER  FlashCapacity
	Use this parameter to specify the SCSI LUN you wish to designate as "flash capacity". The options set are "enable_ssd enable_capacity_flash" -- this is needed by all-flash VSAN configurations

.PARAMETER  ExplicitHDD
	Use this parameter to specify the SCSI LUN you wish to explicitly flag as NOT SSD. The option set is "disable_ssd"

.PARAMETER  Disabled
	Used to clear all flags on the specified LUN.

.PARAMETER  CustomFlags
	Use this parameter to specify a custom set of flags for the SCSI LUN. options might be "enable_local enable_ssd"
 
.PARAMETER  ReClaimOnly
	It's possible to end up in a situation where the claim rule has been added or removed, but for whatever reason the claim process does not complete successfully. This can be caused by running this function several times in a row. Using this switch will just rerun the claim process. If you run the Set-ScsiLunFlags function and the change does not take effect, you may want to try running with the ReClaimOnly switch.  
 
.EXAMPLE
	C:\PS> Set-ScsiLunFlags -ScsiLun $SCSILUN
	 
	Enables the SSD option for $SCSILUN
	 
.EXAMPLE
	C:\PS> Set-ScsiLunFlags -ScsiLun $SCSILUN -ExplicitHDD
	 
	Explicitly disables the SSD option for $SCSILUN
	 
.EXAMPLE
	C:\PS> Set-ScsiLunFlags -ScsiLun $SCSILUN -FlashCapacity
	 
	Explicitly enables the SSD option and the Flash Capacity for $SCSILUN 
	(required for all-flash VSAN)

.EXAMPLE
	C:\PS> Set-ScsiLunFlags -ScsiLun $SCSILUN -CustomFlags "enable_ssd enable_local"
	 
	Explicitly enables the provided string as flags on $SCSILUN 
	 
.EXAMPLE
	C:\PS> Set-ScsiLunFlags -ScsiLun $SCSILUN -Disabled
	 
	Disables all options for $SCSILUN
 
.Example
	C:\PS> Get-VMHost | Get-ScsiLun -CanonicalName $SCSILUN | Set-ScsiLunFlags
	 
	Enables the SSD option for all hosts with a SCSI LUN matching the Canonical Name of $SCSILUN (e.g. mpx.vmhba1:C0:T1:L0)

.EXAMPLE
	C:\PS> Get-Datastore | where { $_.name -like "*HostCache*" } | Get-ScsiLun | Set-ScsiLunFlags
	 
	Enables the SSD option for all LUNs that belong to data stores with "HostCache" as part of thier name.

.NOTES
	Only tested with vSphere 6.0 and only tested for local disks.
		
	Thanks to Joe Keegan for the idea and base code

.LINK
	http://blogs.vmware.com/hol
#>
 
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$True,ValueFromPipeline=$True)]
	$ScsiLun,
	[Switch]
	$FlashCapacity,
	[Switch]
	$ExplicitHDD,
	[Switch]
	$Disabled,
	[Switch]
	$ReClaimOnly,
	$CustomFlags = ''
)
 
BEGIN {}
 
PROCESS {
 
	if ( ($ScsiLun.GetType()).name -eq "String" ) {
		$ScsiLun = Get-ScsiLun -CanonicalName $ScsiLun
	}
 
	$LUN_CName = $ScsiLun.CanonicalName
 
	$VMHost = Get-VMhost -name $ScsiLun.VMHost
	$ESXCLI = $VMHost | Get-EsxCli
	$SATP = ($ESXCLI.storage.nmp.device.list($LUN_CName))[0].StorageArrayType
	$ClaimRules = $ESXCLI.storage.nmp.satp.rule.list()
 
 	if( $CustomFlags -ne '' ) {
 		$ruleString = $CustomFlags
 	}
 	else {
		$ruleString = 'enable_ssd'
		if( $ExplicitHDD -eq $True ) { $ruleString = 'disable_ssd' }
		if( $FlashCapacity -eq $True ) { $ruleString = 'enable_ssd enable_capacity_flash' }
		if( $Disabled -eq $True ) { $ruleString = '' }
	}

	if ( $ReClaimOnly -eq $False ) {
		if ( $Disabled -eq $True ) {
			foreach ( $Rule in $ClaimRules ) {
				if ( $Rule.Device -eq $LUN_CName ) {
					$ESXCLI.storage.nmp.satp.rule.remove($FALSE,$null,$null,$LUN_CName,$null,$null,$null,$null,$null,$SATP,$null,$null,$null) | Out-Null
					$ESXCLI.storage.core.claiming.reclaim($LUN_CName)
				}
			}
		} elseif ( $Disabled -eq $False ) {
			foreach ( $Rule in $ClaimRules ) {
				if ( $Rule.Device -eq $LUN_CName ) {
					$RuleExists = $True
					break
				}
			}
			if ( $RuleExists ) {
				#if there is an existing rule, remove the rule and rebuild it
				$ESXCLI.storage.nmp.satp.rule.remove($FALSE,$null,$null,$LUN_CName,$null,$null,$null,$null,$null,$SATP,$null,$null,$null) 
			}
			# $ESXCLI.storage.nmp.satp.rule.add($FALSE,"","",$LUN_CName,"",$FALSE,"",$ruleString,"","",$SATP,"","","") | Out-Null
			$ESXCLI.storage.nmp.satp.rule.add($FALSE,$null,$null,$LUN_CName,$null,$FALSE,$null,$ruleString,$null,$null,$SATP,$null,$null,$null) | Out-Null
			$ESXCLI.storage.core.claiming.reclaim($LUN_CName)
		}
	} elseif ( $ReClaimOnly ) {
		$ESXCLI.storage.core.claiming.reclaim($LUN_CName)
	}
$ScsiLun
}
 
END {}
}

Function Get-ScsiLunFlags {
<#
	.SYNOPSIS
		Report which flags are set on which SCSI LUNs.
 
	.DESCRIPTION
		The Get-ScsiLunFlags function outputs the flags set on each of the passed SCSI LUNs. 
		To keep the list tidy, if no flags are set, no output is printed for that LUN
 
	.PARAMETER  ScsiLun
		Use this parameter to specify which LUN should be reported.
 
	.EXAMPLE
		C:\PS> Get-VMHost | Get-ScsiLun -CanonicalName $SCSILUN | Get-ScsiLunFlags 
		 
		Outputs to the flags configured for all hosts with a SCSI LUN matching the Canonical Name of $SCSILUN (e.g. mpx.vmhba2:C0:T0:L0)
		 
	.NOTES  
		Function has only been tested with vSphere 6.0, should work with vSphere 5.x.
		
		Thanks to Joe Keegan for the idea and base code
 
	.LINK
		http://blogs.vmware.com/hol
#>
 
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$True,ValueFromPipeline=$True)]
	$ScsiLun
)
 
BEGIN {}
 
PROCESS {

	$LUN_CName = $ScsiLun.CanonicalName

	$VMHost = get-vmhost -name $ScsiLun.VMHost
	$ESXCLI = $VMHost | get-EsxCli
	$SATP = ($ESXCLI.storage.nmp.device.list($LUN_CName))[0].StorageArrayType
	$ClaimRules = $ESXCLI.storage.nmp.satp.rule.list()

	$report = @()
	foreach ( $Rule in $ClaimRules ) {
		if ( $Rule.Device -eq $LUN_CName ) {
			$line = ""| select Hostname, Device, Options, IsSSD
			$line.Device = $Rule.Device
			$line.Options = $Rule.Options
			$line.HostName = $VMHost.Name
			$line.IsSSD = (Get-ScsiLUN -CanonicalName $LUN_CName -VMhost $VMHost).ExtensionData.Ssd 
			$report += $line
		}
	}
	$report
}

END {}
}
