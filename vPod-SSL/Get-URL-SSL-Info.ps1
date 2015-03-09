#URLs to be checked for specified text in response
## pull these from the labStartup file
$URLs = @{
	'https://vcsa-01a.corp.local:9443/vsphere-client/' = 'vSphere Web Client'
	'http://stga-01a.corp.local/account/login' = 'FreeNAS'
	'https://psc-01a.corp.local/' = 'Platform'
	}

#Certificate Validation
$minValidDate = [datetime]"12/01/2015"
$ExtraCertDetails = $false
#Look at port 443 on everything on 192.168.110.0/24, except the vpodrouter
$startIP = 3
$endIP = 254

###############################################################################

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
}#End Test-TcpPort

###############################################################################

#Disable SSL certificate validation checks... it's a Lab!
$scvc = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

#Build my own list - start by pinging, then Test-TCP on 443, then grab certs
$cIP = $startIP
$myPingList = @()
$mySslList = @()
While( $cIP -lt $endIP ){
	$server = "192.168.110.$cIP"
	Write-Host "Pinging $server"
	If ( Test-Connection -ComputerName $server -Count 2 -Quiet -TimeToLive 5) {
		$myPingList += $server
		If( Test-TcpPort $server 443 ) {
			$mySslList += "https://$server/"
		}
	}
	$cIP++
}

#Add the scanned list to the provided list
$urlsToTest = $URLs.Keys + $mySslList

$report = @()
foreach( $url in $urlsToTest ) {

	If( $url -like "https*" ) {
		#write-host $url
		$h = [regex]::Replace($url, "https://([a-z\.0-9\-]+).*", '$1')
		If( ($url.Split(':') | Measure-Object).Count -gt 2 ) {
			$p = [regex]::Replace($url, "https://[a-z\.0-9\-]+\:(\d+).*", '$1')
		} Else { $p =  443 }
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
			$report += $item
		}
	}
}
Write-Host "==== SSL CERTIFICATES ===="
$report | FT -AutoSize


#Write-Host ("The error was '{0}'." -f $variable)