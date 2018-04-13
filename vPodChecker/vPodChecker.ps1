<#

.SYNOPSIS			This script is intended to run some standard config validation
							checks for Hands-on Labs vPods. It also attempts to remediate
							some simple and common misconfigurations like uuid.action and
							keyboard.typematicMinDelay on Linux vVMs as well as CPU and Memory
							reservations.

.DESCRIPTION	Check vPod configuration and remediate some misconfigurations

.NOTES				Requires PowerCLI and LabStartupFunctions.psm1
							Version 1.04 - 27 February 2018 (pulls in LabStartupFunctions module and URLs, vCenters)
							Version 1.05 - 10 April 2018 tweaks and better error capture and license reporting
							Version 1.06 - 11 April 2018 sorting and better output formatting

.EXAMPLE			.\vPodChecker.ps1

.INPUTS				None, but uses C:\HOL\Resources\URLS.txt and VCENTERS.txt

.OUTPUTS			Interactive: all output is written to console

#>

$LabStartupModulePath = 'C:\HOL\LabStartupFunctions.psm1'
If( Test-Path $LabStartupModulePath ) { 
	Import-Module $LabStartupModulePath -DisableNameChecking 
} Else {
	Write-Host "Unable to check vPod: missing LabStartupFunctions module"
	EXIT
}

#####Check SSL certificates on PROVIDED links: using URLS file from C:\HOL\Resources\

Set-Variable -Name "URLS" -Value $(Read-FileIntoArray "URLS")
$urlsToTest = @()
Foreach ($entry in $URLs) {
	($url,$response) = $entry.Split(",")
	 if( $url -match 'https' ) { 
	 	$urlsToTest += $url
	 } 
}

#FQDN(s) of vCenter server(s): also from VCENTERS file in C:\HOL\Resources
Set-Variable -Name "VCENTERS" -Value $(Read-FileIntoArray "VCENTERS")
$vcsToTest = @()
Foreach ($entry in $vCenters) {
	($vc,$type) = $entry.Split(":")
	 $vcsToTest += $vc 
}
# Credentials used to log in to all vCenters 
# (in vSphere 6, account with 'license administrator' privilege must be used)
$vcuser = 'administrator@vsphere.local'
$password = 'VMware1!'

$sleepSeconds = 10

# calculating ending year based on today's date
$a = Get-Date
If ( $a.Month -lt 5 )  { # Spring Release dev cycle (Jan to April)
	$minYear = $a.Year # end of this year
} Else { # VMworld dev cycle so end of next year
	$minYear = $a.Year + 1
}
$maxYear = $minYear + 1
# HOL licenses should NOT expire before this date
$chkDateMin = Get-Date "01/01/$minYear 12:00:00 AM"
Write-Host "HOL licenses should NOT expire before $chkDateMin"

# HOL licenses should expire before this date
$chkDateMax = Get-Date "01/28/$maxYear 12:00:00 AM"
Write-Host "HOL licenses should expire before $chkDateMax"

$input = Read-Host -Prompt "If these dates are acceptable, press a key to continue"

$licensePass = $true

#must be defined in order to pass as reference for looping during connect
$result = ''

#Certificate Validation
$minValidDate = [datetime]"12/31/$minYear"
$ExtraCertDetails = $false

Write-Host "HOL SSL Certifcates should NOT expire before $minValidDate"

##############################################################################

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

Foreach ($vcserver in $vcsToTest) {
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

	If( $url -like "https*" ) {
		#write-host $url
		$h = [regex]::Replace($url, "https://([a-z\.0-9\-]+).*", '$1')
		If( ($url.Split(':') | Measure-Object).Count -gt 2 ) {
			$p = [regex]::Replace($url, "https://[a-z\.0-9\-]+\:(\d+).*", '$1')
		} Else { $p =	443 }
		#Write-Host $h on port $p

		If( $ExtraCertDetails ) {
			$item = "" | select HostName, PortNum, CertName, Thumbprint, Issuer, EffectiveDate, ExpiryDate, DaysToExpire
		} Else {
			$item = "" | select HostName, PortNum, CertName, ExpiryDate, DaysToExpire, Issuer
		}

		$item.HostName = $h
		$item.PortNum = $p

		If (Test-TcpPort $h $p ) {
			#Get the certificate from the host
			$wr = [Net.WebRequest]::Create("https://$h" + ':' + $p)
		
			#The following request usually fails for one reason or another:
			# untrusted (self-signed) cert or untrusted root CA are most common...
			# we just want the cert info, so it usually doesn't matter
			Try { 
				$response = $wr.GetResponse() 
				#This sometimes results in an empty certificate... probably due to a redirection
				If( $wr.ServicePoint.Certificate ) {
					If( $ExtraCertDetails ) {
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
					If( $validTime.Days -lt 0 ) {
						$item.DaysToExpire = "$validTime.Days - *** EXPIRES EARLY *** "
					} Else {
						$item.DaysToExpire = $validTime.Days
					}
				}
			}
			Catch{
				Write-Host "Unable to get certificate for $h on $port"
			}
			Finally {
				if( $response ) {
					$response.Close()
					Remove-Variable response
				}
			}
			$sslReport += $item
		}
	}
}
$sslReport | Sort -Property HostName | FT -AutoSize
Write-Host "=========================="


##############################################################################
##### Check Host Settings
##############################################################################
Write-Host "==== HOST CONFIGURATION - NTP ===="
$hostReport = @()

##### NTP is configured

$allhosts = Get-VMHost | Sort -Property Name
foreach ($h in $allhosts) {
	$row = "" | Select HOSTNAME, NTPDRUNNING, NTPDPOLICY, NTPSERVER
	$row.HOSTNAME = $h.name
	$ntpData = Get-VMHostService -VMHost $h	| where { $_.key -eq 'ntpd' }
	$row.NTPDRUNNING =	$ntpData.Running
	$row.NTPDPOLICY	=	$ntpData.Policy
	$row.NTPSERVER	 =	Get-VMHostNtpServer -VMHost $h
	$hostReport += $row
}
$hostReport | ft -auto
If  ( $row) { Remove-Variable row }
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
		try {
			Write-Host "Creating " $vm.Name " UUID.action=keep..." -backgroundcolor "green"
			New-AdvancedSetting -en $vm -name uuid.action -value 'keep' -Confirm:$false -ErrorAction 1 | Out-Null
			$row.UUIDACTION = "was BLANK"
		} catch {
			Write-Host -Fore Red	"Failed to create UUID.action on $($vm.name)"
			$row.UUIDACTION = "FIXMANUAL"
			if( $($vm.name) -match "NSX" ) {
				Write-Host -Fore Red "`tThis is typical for NSX"
				$row.TYPEDELAY = "GOODLUCK"
			}
		}
	} else {
		try {
			Write-Host "Setting " $vm.Name " UUID.action=keep..." -backgroundcolor "green"
			Set-AdvancedSetting $currentUuidAction -value 'keep' -Confirm:$false -ErrorAction 1
			$row.UUIDACTION = "was $currentUuidActionValue"
		} catch {
			Write-Host -Fore Red	"Failed to set UUID.action on $($vm.name)"
			Write-Host -Fore Red	"	value remains: $((Get-AdvancedSetting -en $vm -name uuid.action).value)"
			$row.UUIDACTION = "FIXMANUAL"
		}
	}
	
	##### Report/correct typematic delay... for Linux machines only
	
	$row.OSTYPE = $vm.GuestId
	if( $vm.GuestId -match 'linux|ubuntu|debian|centos|sles|redhat|photon|rhel|other' ) {
		$currentTypeDelay = Get-AdvancedSetting -en $vm -name keyboard.typematicMinDelay
		$currentTypeDelayValue = $currentTypeDelay.Value
		if( $currentTypeDelayValue -eq 2000000 ) {
			$row.TYPEDELAY = $currentTypeDelayValue
		} elseif(! $currentTypeDelay ) {
			try {
				Write-Host "Creating " $vm.Name " keyboard.typematicMinDelay..." -backgroundcolor "green"
				New-AdvancedSetting -en $vm -name keyboard.typematicMinDelay -value 2000000 -Confirm:$false -ErrorAction 1 | Out-Null
				$row.TYPEDELAY = "was BLANK"
			} catch {
				Write-Host -Fore Red	"Failed to create keyboard.typematicMinDelay on $($vm.name)"
				$row.TYPEDELAY = "FIXMANUAL"
				if( $($vm.name) -match "NSX" ) {
					Write-Host -Fore Red "`tThis is typical for NSX"
					$row.TYPEDELAY = "GOODLUCK"
				}
			}

		} else {
			try {
				Write-Host "Setting " $vm.Name " keyboard.typematicMinDelay..." -backgroundcolor "green"
				Set-AdvancedSetting $currentTypeDelay -value 2000000 -Confirm:$false -ErrorAction 1
				$row.TYPEDELAY = "was $currentTypeDelayValue"
			} catch {
				Write-Host -Fore Red "Failed to set keyboard.typematicMinDelay on $($vm.name)"
				Write-Host -Fore Red	"	value remains: $((Get-AdvancedSetting -en $vm -name keyboard.typematicMinDelay).value)"
				$row.TYPEDELAY = "FIXMANUAL"
			}
		}
	}
	$vmReport += $row
}

$vmReport | ft
If  ( $row) { Remove-Variable row }
Write-Host "=========================="

##############################################################################
##### Check vVM Resource Settings
##############################################################################
Write-Host "==== L2 RESOURCE CONFIGURATION ===="
Write-Host ""
$vmReport = @()

foreach ($vm in $allvms) {
	$row = "" | Select VMNAME,CpuReservationMhz,MemReservationGB,CpuSharesLevel,MemSharesLevel
	$row.VMNAME = $vm.name
	$row.CpuReservationMhz = $vm.VMResourceConfiguration.CpuReservationMhz
	$row.MemReservationGB = $vm.VMResourceConfiguration.MemReservationGB
	$row.CpuSharesLevel = $vm.VMResourceConfiguration.CpuSharesLevel
	$row.MemSharesLevel = $vm.VMResourceConfiguration.MemSharesLevel
	
	If ( $vm.VMResourceConfiguration.CpuReservationMhz ) {
		Write-Host "Setting " $vm.Name " CPU reservation to 0 per HOL standards..." -backgroundcolor "green"
		try {
			$vm | Get-VMResourceConfiguration | Set-VMResourceConfiguration -CPUReservationMhz 0 -ErrorAction 1
			$row.CpuReservationMhz = "was " + $vm.VMResourceConfiguration.CpuReservationMhz
		}
		catch {
			Write-Host -Fore Red "Failed to remove CPU reservation on $($vm.name)"
			$row.CpuReservationMhz = $vm.VMResourceConfiguration.CpuReservationMhz		
		}
	}
	If ( $vm.VMResourceConfiguration.MemReservationGB ) {
		Write-Host "Setting " $vm.Name " memory reservation to 0 per HOL standards..." -backgroundcolor "green"
		try {
			$vm | Get-VMResourceConfiguration | Set-VMResourceConfiguration -MemReservationMB 0 -ErrorAction 1
			$row.MemReservationGB = "was " + $vm.VMResourceConfiguration.MemReservationGB
		}
		catch {
			Write-Host -Fore Red "Failed to remove memory reservation on $($vm.name)"
			$row.MemReservationGB = $vm.VMResourceConfiguration.MemReservationGB
		}
	}
	If ( $vm.VMResourceConfiguration.CpuSharesLevel -ne "Normal" ) {
		#Write-Host "Notification only: " $vm.Name " CPU Shares are: " $vm.VMResourceConfiguration.CpuSharesLevel
	}
	If ( $vm.VMResourceConfiguration.MemSharesLevel -ne "Normal" ) {
		#Write-Host "Notification only: " $vm.Name " CPU Shares are: " $vm.VMResourceConfiguration.MemSharesLevel
	}
	$vmReport += $row
}

$vmReport | ft
If  ( $row) { Remove-Variable row }
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
				$row.STATUS = 'UNASSIGNED'
				if( $Name -match "NSX for vSphere - Enterprise" ) {
					Write-Host "License $Name is UNASSIGNED, but this one always shows UNASSIGNED." -backgroundcolor "yellow"
				} else {
					Write-Host "License $Name is UNASSIGNED and should be removed." -backgroundcolor "yellow"
					$licensePass = $false
				}
			}
		} else {
			if( ! $expDate ) {
				if( $Name -match "NSX for vShield Endpoint" ) {
					Write-Host "License $Name $lKey NEVER expires, but it usually does not." -backgroundcolor "yellow"
				} else {
					Write-Host "License $Name $lKey NEVER expires!!" -foregroundcolor "red"
					$licensePass = $false
				}
			} else {
				Write-Host "License $Name $lKey is BAD. It expires $expDate"
				$row.STATUS = 'EXPIRING'
				$licensePass = $false
			}
		}
		# need to make certain expDate is AFTER chkDate
	}
	$licenseReport += $row
}

$licenseReport | ft

if( $licensePass ) {
	Write-Host "Well done! Final result of license check is PASS" -backgroundcolor "green"
}
else {
	Write-Host "Final result of license check is FAIL" -foregroundcolor "red"
}
Remove-Variable row
Write-Host "=========================="

##### Disconnect from all vCenters

Foreach( $vcserver in $vcsToTest ) {
	Write-Output "$(Get-Date) disconnecting from $vcserver ..."
	Disconnect-VIServer -Server $vcserver -Confirm:$false
}


###### END ######
