<#

.SYNOPSIS			This script is intended to run some standard config validation
							checks for Hands-on Labs vPods. It also attempts to remediate
							some simple and common misconfigurations like uuid.action and
							keyboard.typematicMinDelay on Linux vVMs

.DESCRIPTION	Check vPod configuration and remediate some misconfigurations

.NOTES				Requires PowerCLI -- tested with v6.0u1
							Version 1.1 - 7 March 2016
 
.EXAMPLE			.\vPodChecker.ps1

.INPUTS				None

.OUTPUTS			Interactive: all output is written to console

#>

#####Check SSL certificates on PROVIDED links
## USER must provide this list based on what is in your pod
## Start by pulling this array from the labStartup file. We'll filter out non-https links
$URLs = @{
	'https://vcsa-01a.corp.local:9443/vsphere-client/' = 'vSphere Web Client'
	'http://stga-01a.corp.local/account/login' = 'FreeNAS'
	'https://psc-01a.corp.local/' = 'Platform'
	}

$urlsToTest = $URLs.Keys | where { $_ -match 'https' } 

#FQDN(s) of vCenter server(s)
$vCenters = @(
	'vcsa-01a.corp.local'
	#'vcsa-02a.corp.local'
)

# Credentials used to log in to all vCenters 
# (in vSphere 6, account with 'license administrator' privilege must be used)
$vcuser = 'administrator@vsphere.local'
$password = 'VMware1!'

$sleepSeconds = 10

# HOL licenses should NOT expire before this date
$chkDateMin = Get-Date "01/01/2016 12:00:00 AM"

# HOL licenses should expire before this date
$chkDateMax = Get-Date "01/28/2017 12:00:00 AM"

$licensePass = $true

#must be defined in order to pass as reference for looping during connect
$result = ''

#Certificate Validation
$minValidDate = [datetime]"12/31/2016"
$ExtraCertDetails = $false

#The NTP server we want configured
$ntpServer = '192.168.100.1'


#Automatically Remediate?
if($args[0] -eq '-Fix') {
	Write-Host -ForegroundColor Green "*** Remediation Active ***"
	$autoRemediate = $true
} else {
	Write-Host -ForegroundColor Yellow "*** Reporting Only ***"
	$autoRemediate = $false
}

##############################################################################

#Load the VMware PowerCLI tools - no PowerCLI is fatal. 
Try {
	#For PowerCLI v6.x
	$PowerCliInit = 'C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1'
	. $PowerCliInit
} 
Catch {
	Write-Host "No PowerCLI found, unable to continue."
	Break
} 

#Disable SSL certificate validation checks... it's a Lab!
$scvc = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

##############################################################################

Function Connect-VC ([string]$server, [string]$username, [string]$password, [REF]$result) {
<#
	This function attempts once to connect to the specified vCenter 
	It sets the $result variable to 'success' or 'fail' based on the result
#>
	Try {
		Connect-ViServer -server $server -username $username -password $password -ErrorAction 1 | Out-Null
		Write-Host "Connection Successful"
		$result.value = "success"
	}
	Catch {
		Write-Host "Failed to connect to server $server"
		Write-Host $_.Exception.Message
		$result.value = $false
	}
} #End Connect-VC


Function Test-TcpPort ([string]$server, [int]$port) {
	Try {
		$socket = New-Object Net.Sockets.TcpClient
		$socket.Connect($server,$port)
		if($socket.Connected) {
			Write-Host "Successfully connected to server $server on port $port"
			return $true
		}
	}
	Catch {
		Write-Host "Failed to connect to server $server on port $port"
		Return $false
	}
	$socket.Dispose()
} #End Test-TcpPort


##############################################################################
##### Connect to each vCenter
##############################################################################

Foreach ($vcserver in $vCenters) {
	Do {
		Connect-VC $vcserver $vcuser $password ([REF]$result)
		Start-Sleep $sleepSeconds
	} Until ($result -eq "success")
}

##############################################################################
##### Check and report SSL Certificates
##############################################################################
Write-Host "==== SSL CERTIFICATES ===="
$sslReport = @()

foreach( $url in $urlsToTest ) {

	if( $url -like "https*" ) {
		#write-host $url
		$h = [regex]::Replace($url, "https://([a-z\.0-9\-]+).*", '$1')
		if( ($url.Split(':') | Measure-Object).Count -gt 2 ) {
			$p = [regex]::Replace($url, "https://[a-z\.0-9\-]+\:(\d+).*", '$1')
		} else { $p =	443 }
		#Write-Host $h on port $p

		if( $ExtraCertDetails ) {
			$item = "" | select HostName, PortNum, CertName, Thumbprint, Issuer, EffectiveDate, ExpiryDate, DaysToExpire
		} else {
			$item = "" | select HostName, PortNum, CertName, ExpiryDate, DaysToExpire, Issuer
		}

		$item.HostName = $h
		$item.PortNum = $p

		if( Test-TcpPort $h $p ) {
			#Get the certificate from the host
			$wr = [Net.WebRequest]::Create("https://$h" + ':' + $p)
		
			#The following request usually fails for one reason or another:
			# untrusted (self-signed) cert or untrusted root CA are most common...
			# we just want the cert info, so it usually doesn't matter
			try {
				$response = $wr.GetResponse() 
				#This sometimes results in an empty certificate... probably due to a redirection
				if( $wr.ServicePoint.Certificate ) {
					if( $ExtraCertDetails ) {
						$t = $wr.ServicePoint.Certificate.GetCertHashString()
						$SslThumbprint = ([regex]::matches($t, '.{1,2}') | %{$_.value}) -join ':'
						$item.Thumbprint = $SslThumbprint
						$item.EffectiveDate = $wr.ServicePoint.Certificate.GetEffectiveDateString()
					}
					$cn = $wr.ServicePoint.Certificate.GetName()
					$item.CertName = $cn.Replace('CN=',';').Split(';')[-1].Split(',')[0]
					$item.Issuer = $wr.ServicePoint.Certificate.Issuer
					$item.ExpiryDate = $wr.ServicePoint.Certificate.GetExpirationDateString()
					$validTime = New-Timespan -End $item.ExpiryDate -Start $minValidDate
					if( $validTime.Days -lt 0 ) {
						$item.DaysToExpire = "$validTime.Days - *** EXPIRES EARLY *** "
					} else {
						$item.DaysToExpire = $validTime.Days
					}
				}
			}
			catch {
				$Exception = $Error[0].Exception.InnerException
				Write-Host "Unable to get certificate for $h on $p"
				Write-Host "Exception: $Exception"
			}
			finally {
				if( $response ) {
					$response.Close()
					Remove-Variable response
				}
			}
			$sslReport += $item
		}
	}
}
$sslReport | FT -AutoSize
Write-Host "=========================="


##############################################################################
##### Check Host Settings
##############################################################################
Write-Host "==== HOST CONFIGURATION - NTP ===="
$hostReport = @()

##### NTP is configured

$allhosts = Get-VMHost
foreach ($h in $allhosts) {
	$row = "" | Select HOSTNAME, NTPDRUNNING, NTPDPOLICY, NTPSERVER
	$row.HOSTNAME = $h.name
	$ntpData = Get-VMHostService -VMHost $h	| where { $_.key -eq 'ntpd' }
	$row.NTPDRUNNING =	$ntpData.Running
	$row.NTPDPOLICY	=	$ntpData.Policy
	$row.NTPSERVER	 =	Get-VMHostNtpServer -VMHost $h
	
	if( ($row.NTPSERVER -ne $ntpServer) -and $autoRemediate ) {
		Write-Host -ForegroundColor Green "Correcting NTP server"
		Add-VMhostNtpserver -vmhost $h -ntpserver $ntpServer
		Get-VMHostFirewallException  -vmh $h | where {$_.name -like "*NTP Client*" } | Set-VMHostFirewallException -Enabled:$true
	}
	
	if( ($row.NTPDPOLICY -ne 'on') -and $autoRemediate ) {
		Write-Host -ForegroundColor Green "Correcting NTP server policy"
		Get-VMHostService -vmhost $h | Where {$_.key -eq "ntpd"} | Start-VMHostService
		Get-VMHostService -vmhost $h | Where {$_.key -eq "ntpd"} | Set-VMHostService -policy 'on'
	}

	$ntpData = Get-VMHostService -VMHost $h	| where { $_.key -eq 'ntpd' }
	$row.NTPDRUNNING = "$($ntpData.Running) (was $($row.NTPDRUNNING))"
	$row.NTPDPOLICY	=	"$($ntpData.Policy) (was $($row.NTPDPOLICY))"
	$row.NTPSERVER	 =	"$(Get-VMHostNtpServer -VMHost $h) (was $($row.NTPSERVER))"

	$hostReport += $row
	
}
$hostReport | ft -auto
Remove-Variable row
Write-Host "=========================="


##############################################################################
##### Check vVM Settings
##############################################################################
Write-Host "==== L2 VM CONFIGURATION ===="
$vmReport = @()

##### Report/correct UUID.action setting on vVMs

$allvms = Get-VM
foreach ($vm in $allvms) {
	$row = "" | Select VMNAME,OSTYPE,UUIDACTION,TYPEDELAY
	$row.VMNAME = $vm.name
	
	$currentUuidAction = Get-AdvancedSetting -en $vm -name uuid.action
	$currentUuidActionValue = $currentUuidAction.Value
	if( $currentUuidActionValue -eq "keep" ) {
		$row.UUIDACTION = $currentUuidActionValue
	} elseif(! $currentUuidActionValue ) {
		if( $autoRemediate ) {
			Write-Host -ForegroundColor Green "Correcting vVM UUID.action"
			try {
				New-AdvancedSetting -en $vm -name uuid.action -value 'keep' -Confirm:$false -ErrorAction 1 | Out-Null
				$row.UUIDACTION = "was BLANK"
			} catch {
				Write-Host -Fore Red	"Failed to create UUID.action on $($vm.name)"
				$row.UUIDACTION = "FIXMANUAL"
			}
		}
	} else {
		if( $autoRemediate ) {
			Write-Host -ForegroundColor Green "Correcting vVM typematic setting"
			try {
				Set-AdvancedSetting $currentUuidAction -value 'keep' -Confirm:$false -ErrorAction 1
				$row.UUIDACTION = "was $currentUuidActionValue"
			} catch {
				Write-Host -Fore Red	"Failed to set UUID.action on $($vm.name)"
				Write-Host -Fore Red	"	value remains: $((Get-AdvancedSetting -en $vm -name uuid.action).value)"
				$row.UUIDACTION = "FIXMANUAL"
			}
		}
	}
	
	##### Report/correct typematic delay... for Linux machines only
	
	$row.OSTYPE = $vm.GuestId
	if( $vm.GuestId -match 'linux|ubuntu|debian|centos|sles|redhat|other' ) {
		$currentTypeDelay = Get-AdvancedSetting -en $vm -name keyboard.typematicMinDelay
		$currentTypeDelayValue = $currentTypeDelay.Value
		if( $currentTypeDelayValue -eq 2000000 ) {
			$row.TYPEDELAY = $currentTypeDelayValue
		} elseif(! $currentTypeDelay ) {
			if( $autoRemediate ) {
				try {
					New-AdvancedSetting -en $vm -name keyboard.typematicMinDelay -value 2000000 -Confirm:$false -ErrorAction 1 | Out-Null
					$row.TYPEDELAY = "was BLANK"
				} catch {
					Write-Host -Fore Red	"Failed to create keyboard.typematicMinDelay on $($vm.name)"
					$row.TYPEDELAY = "FIXMANUAL"
				}
			}
		} else {
			if( $autoRemediate ) {
				try {
					Set-AdvancedSetting $currentTypeDelay -value 2000000 -Confirm:$false -ErrorAction 1
					$row.TYPEDELAY = "was $currentTypeDelayValue"
				} catch {
					Write-Host -Fore Red "Failed to set keyboard.typematicMinDelay on $($vm.name)"
					Write-Host -Fore Red	"	value remains: $((Get-AdvancedSetting -en $vm -name keyboard.typematicMinDelay).value)"
					$row.TYPEDELAY = "FIXMANUAL"
				}
			}
		}
	}
	$vmReport += $row
}

$vmReport | ft
Remove-Variable row
Write-Host "=========================="



##############################################################################
##### Check Licensing
##############################################################################

Write-Host "==== VCENTER LICENSES ===="
$licenseReport = @()

#check for evaluation licenses in use
$LM = Get-View LicenseManager
$LAM = Get-View $LM.LicenseAssignmentManager 
$param = @($null)
$assets = $LAM.GetType().GetMethod("QueryAssignedLicenses").Invoke($LAM,$param)


foreach ($asset in $assets) {
	if ( $asset.AssignedLicense.LicenseKey -eq '00000-00000-00000-00000-00000' ) {
		# special case - make certain nothing is in evaluation mode
		$name = $asset | Select-Object -ExpandProperty EntityDisplayName
		Write-Host "Please check EVALUATION assignment on $name!" -foregroundcolor "red"
		$licensePass = $false
	}
}
	
# query the license expiration for all installed licenses

foreach( $License in ($LM | Select -ExpandProperty Licenses) ) {
	if ( !($License.LicenseKey -eq '00000-00000-00000-00000-00000') ) {
		$row = "" | Select LICENSENAME,LICENSEKEY,EXPIRATION,STATUS
		$VC = ([Uri]$LM.Client.ServiceUrl).Host
		$Name = $License.Name
		$lKey = $License.LicenseKey
		$used = $License.Used
		$labels = $License.Labels | Select -ExpandProperty Value

		$row.LICENSENAME = $Name
		$row.LICENSEKEY = $lKey
		
		$expDate = $License.Properties | Where-Object {$_.Key -eq "expirationDate"} | Select-Object -ExpandProperty Value

		if( $expDate ) { 
			$row.EXPIRATION = $expDate
		} else {
			$row.EXPIRATION = 'NEVER'
		}

		if( $expDate -and (($expDate -ge $chkDateMin) -and ($expDate -le $chkDateMax)) ) {
			#Write-Verbose "License $Name $lKey is good and expires $expDate"
			$row.STATUS = 'GOOD'
			if( $used -eq 0 ) {
				Write-Host "License $Name is UNASSIGNED and should be removed." -foregroundcolor "yellow"
				$row.STATUS = 'UNASSIGNED'
				$licensePass = $false
			}
		} else {
			if( ! $expDate ) {
				Write-Host "License $Name $lKey NEVER expires!!" -foregroundcolor "red"
			} else {
				Write-Host "License $Name $lKey is BAD. It expires $expDate"
				$row.STATUS = 'EXPIRING'
			}
			$licensePass = $false
		}
		# need to make certain expDate is AFTER chkDate
	}
	$licenseReport += $row
}

$licenseReport | ft

if( $licensePass ) {
	Write-Host "Well done! Final result of license check is PASS" -foregroundcolor "green"
}
else {
	Write-Host "Final result of license check is FAIL" -foregroundcolor "red"
}
Remove-Variable row
Write-Host "=========================="

##### Disconnect from all vCenters

Foreach ($vcserver in $vCenters) {
	Write-Output "$(Get-Date) disconnecting from $vcserver ..."
	Disconnect-VIServer -Server $vcserver -Confirm:$false
}


###### END ######
