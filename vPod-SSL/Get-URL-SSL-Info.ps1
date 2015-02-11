## pull these from the labStartup file

#URLs to be checked for specified text in response
$URLs = @{
	'https://store.apple.com/' = 'TESTING'
	'https://core.projectnee.com' = 'stuff'
	'https://vcore2-us20.oc.vmware.com' = 'xx'
	}

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
#$scvc = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
#[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

$report = @()
foreach( $url in $URLs.Keys ) {

	if( $url -like "https*" ) {
		#write-host $url
		$h = [regex]::Replace($url, "https://([a-z\.0-9\-]+).*", '$1')
		If( ($url.Split(':') | Measure-Object).Count -gt 2 ) {
			$p = [regex]::Replace($url, "https://[a-z\.0-9\-]+\:(\d+).*", '$1')
		} Else { $p =  443 }
		#Write-Host $h on port $p
	}

	$item = "" | select HostName, PortNum, CertName, Thumbprint, EffectiveDate, ExpiryDate
	$item.HostName = $h
	$item.PortNum = $p

	If (Test-TcpPort $h $p ) {
		#Get the certificate from the host
		$wr = [Net.WebRequest]::Create("https://$h" + ':' + $p)
	
		#The following request usually fails for one reason or another:
		# untrusted (self-signed) cert or untrusted root CA are most common...
		# we just want the cert info, so it usually doesn't matter
		try { 
			$response = $wr.GetResponse() 
			#Sometimes, this results in an empty certificate.. probably due to a redirection?
			If( $wr.ServicePoint.Certificate ) {
				$t = $wr.ServicePoint.Certificate.GetCertHashString()
				$SslThumbprint = ([regex]::matches($t, '.{1,2}') | %{$_.value}) -join ':'
				$n = $wr.ServicePoint.Certificate.GetName()
				$item.CertName = ($n.split("="))[-1]
				$item.Thumbprint = $SslThumbprint
				$item.EffectiveDate = $wr.ServicePoint.Certificate.GetEffectiveDateString()
				$item.ExpiryDate = $wr.ServicePoint.Certificate.GetExpirationDateString()
			}
		}
		catch{
			Write-Host "Unable to get certificate for $h on $port"
		}
		finally {
			if( $response ) {
				$response.Close()
				Remove-Variable $response
			}
		}
		$report += $item
	}
}
Write-Host "==== SSL CERTIFICATES ===="
$report 

#Write-Host ("The error was '{0}'." -f $variable)