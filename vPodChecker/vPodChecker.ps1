<#

.SYNOPSIS

.DESCRIPTION

.NOTES
 
.EXAMPLE

.INPUTS

.OUTPUTS

#>

##############################################################################
##### User Variables
##############################################################################

# It would be nice to read vCenters, etc. from the LabStartup.ps1 but it is pretty tricky to do.
# If we separate out the arrays into a PS Module then it would be much easier
#$labStartup = 'C:\hol\LabStartup.ps1'

# Credentials used to login to vCenters (in vSphere 6 special license administrator privilege must be used)
$vcuser = 'administrator@vsphere.local'
$password = 'VMware1!'

$sleepSeconds = 10


# HOL licenses should not expire before this date
$chkDate2 = Get-Date "12/31/2015 12:00:00 AM"

# HOL licenses should expire before this date
$chkDate2 = Get-Date "01/02/2016 12:00:00 AM"

$licensePass = $true

#must be defined in order to pass as reference for looping
$result = ''

##############################################################################


#FQDN of vCenter server(s)
$vCenters = @(
	'vcsa-01a.corp.local'
	#'vcsa-02a.corp.local'
)

##############################################################################

#Load the VMware PowerCLI tools
Try {
  Add-PSSnapin VMware.VimAutomation.Core -ErrorAction 1
  Add-PSSnapin VMware.VimAutomation.License -ErrorAction 1  
} 
Catch {
	Write-Host "No PowerCLI found, unable to continue."
	Exit
}

Function Connect-VC ([string]$server, [string]$username, [string]$password, [REF]$result) {
<#
	This function attempts once to connect to the specified vCenter 
	It sets the $result variable to 'success' or 'fail' based on the result
#>
	Try {
		Connect-ViServer -server $server -username $username -password $password -ea 1
		Write-Host "Connection Successful"
		$result.value = "success"
	}
	Catch {
		Write-Host "Failed to connect to server $server"
#		Write-Host $_.Exception.Message
		$result.value = $false
	}
} #End Connect-VC

##############################################################################
##### Main Script - Base vPod
##############################################################################

# connect to each vCenter and then evaluate licensing
# 

Foreach ($vcserver in $vCenters) {
	Do {
		Connect-VC $vcserver $vcuser $password ([REF]$result)
		Start-Sleep $sleepSeconds
	} Until ($result -eq "success")
	
	#check for evaluation licenses in use
	$LM= Get-view LicenseManager
    $LAM= Get-View $LM.LicenseAssignmentManager 
    $param = @($null)
    $assets = $LAM.GetType().GetMethod("QueryAssignedLicenses").Invoke($LAM,$param)

	Foreach ($asset in $assets) {
	    if ( $asset.AssignedLicense.LicenseKey -eq '00000-00000-00000-00000-00000' ) {
		  # special case - make certain nothing is in evaluation mode
		    $name = $asset | Select-Object -ExpandProperty EntityDisplayName
		    Write-Host "Please check EVALUATION assignment on $name!" -foregroundcolor "red"
			$licensePass = $false
		}
	}
	
	# query the license expiration
	Foreach ($License in ($LM | Select -ExpandProperty Licenses)) {
	    if ( !($License.LicenseKey -eq '00000-00000-00000-00000-00000') ) {
		  $VC = ([Uri]$LM.Client.ServiceUrl).Host
		  $Name = $License.Name
		  $lKey = $License.LicenseKey
		  $used = $License.Used
		  $labels = $License.Labels | Select -ExpandProperty Value
		  $expDate = $License.Properties | Where-Object {$_.Key -eq "expirationDate"} | Select-Object -ExpandProperty Value
		  if ( ($expDate -ge $chkDate1) -and ($expDate -le $chkDate2) ) {
             #Write-Host "License $Name $lKey is good and expires $expDate"
			 if ( $used -eq 0 ) {
			   Write-Host "License $Name is UNASSIGNED and MUST be removed." -foregroundcolor "red"
			   $licensePass = $false
			 }
		  } else {
		     Write-Host "License $Name $lKey is BAD. It expires $expDate"
			 $licensePass = $false
		  }
		  # need to make certain expDate is AFTER chkDate
		}
	}
}

Foreach ($vcserver in $vCenters) {
	Write-Output "$(Get-Date) disconnecting from $vcserver ..."
	Disconnect-VIServer -Server $vcserver -Confirm:$false
}

If ( $licensePass ) {
    Write-Host "Well done!  Final result of license check is PASS" -foregroundcolor "green"
}
Else {
    Write-Host "Final result of license check is FAIL" -foregroundcolor "red"
}