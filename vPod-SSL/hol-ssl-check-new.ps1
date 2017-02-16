#URLs to be checked for specified text in response
## pull these from the labStartup file
$URLs = @{
	'https://vcsa-01a.corp.local' = 'vSphere Web Client'
	'https://vcsa-01a.corp.local:9443/vsphere-client/' = 'vSphere Web Client'
	'http://stga-01a.corp.local/account/login' = 'FreeNAS'
	'https://mirage-01a.corp.local:7443/' = 'Platform'
	'https://h7cs-01a.corp.local/' = 'xx'
	'https://UNKNOWN.corp.local/' = 'xx'
	'https://stgb-01a.corp.local/' = 'Platform'
	}

#######

$urlsToTest = $URLs.Keys | Sort
$DefaultSslPort = 443
$minValidDate = [datetime]"12/31/2018"

#print verbose
#$VerbosePreference = "continue"
#do not print
$VerbosePreference = "SilentlyContinue"

$ID=0
Write-Host "# Host/Port			IssuedTo		Expires (Remaining)		Issuer"

foreach( $url in $urlsToTest ) {

	if( $url -like "https*" ) {
		Write-Verbose "HTTPS url found: $url"
		$h = [regex]::Replace($url, "https://([a-z\.0-9\-]+).*", '$1')
		if( ($url.Split(':') | Measure-Object).Count -gt 2 ) {
			$p = [regex]::Replace($url, "https://[a-z\.0-9\-]+\:(\d+).*", '$1')
		} else { 
			$p =  $DefaultSslPort
		}
		Write-Verbose "Checking $h on port $p"

		$ID+=1		
		try {
			$HostConnection = New-Object System.Net.Sockets.TcpClient($h,$p) 
			try {
				$Stream = New-Object System.Net.Security.SslStream($HostConnection.GetStream(),$false, {
					param($sender, $certificate, $chain, $sslPolicyErrors) 
					return $true 
				})
				$Stream.AuthenticateAsClient($h)
			
				$sslCertificate = $Stream.Get_RemoteCertificate()
				$CN=(($sslCertificate.Subject -split "CN=")[1] -split ",")[0]
				$Issuer=$sslCertificate.Issuer
				$validTo = [datetime]::Parse($sslCertificate.GetExpirationDatestring())

				$validTime = New-Timespan -Start $minValidDate -End $ValidTo 				
				If( $validTime.Days -lt 0 ) {
					#To distinguish from "Error Red"
					$MyFontColor="DarkRed"
				} Else {
					$MyFontColor="DarkGreen"
				}
				$validDays = $validTime.Days

				Write-Host "$ID $h $p`t$CN`t$validTo ($validDays)`t$Issuer" -ForegroundColor $MyFontColor
			}

			catch { throw $_ }
			finally { $HostConnection.close() }
		}
	
		catch {
			#Write-Host "$ID	$WebsiteURL	" $_.exception.innerexception.message -ForegroundColor red
			#unroll the exception
			$e = $_.Exception
			$msg = $e.Message
			while ($e.InnerException) {
			  $e = $e.InnerException
			  $msg += ">" + $e.Message
			}
			Write-Host "$ID	$h	" $msg -ForegroundColor Red
		}
	}
}