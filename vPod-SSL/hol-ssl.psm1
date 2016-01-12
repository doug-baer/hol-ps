###
# HOL SSL Certificate Module
#
# Version 0.7 - 12 January 2016
#	 !! WARNING: VERY UGLY CODE PRESENT
#
# Doug Baer 
#

<#
	These functions are used in the VMware Hands-on Labs to create certificates from the in-pod Microsoft CA server. They may be generally useful, but the following conventions should be understood:
	
	1. C:\HOL\ssl is the root path for all SSL-related "stuff" on the CA
	2. These functions are designed to be run locally on the CA
	3. The domain is "CORP" or "corp.local"
	4. "controlcenter.corp.local" is the FQDN of the machine with the CA on it.
	5. C:\HOL\ssl\CA-Certificate.cer is a file containing the CA certificate. This can be obtained by issuing "certutil -ca.cert C:\HOL\ssl\CA-Certificate.cer" from the command line on the CA
	6. I install our "ssl-certificate-updater-tool" in "c:\hol\ssl\" in order to get openssl.exe for Windows. This can be downloaded from the vmware.com downloads page
	7. The CA has a certificate template called "VMwareCertificate" which has been created according to VMware KB #2062108 @ http://kb.vmware.com/kb/2062108
	
	Note that these functions are intended to be accelerators and can be run even without the Microsoft CA web interface loaded.
	
	Four Functions: 
		* Get-CaCertificate
		* New-HostSslCertificate
		* New-HostSslCertificateFromCsr
		* New-WildSslCertificate
#>


###############################################################################

Function Get-CaCertificate {
<#
	Extract the CA certificate from the local CA into a file
#>
	PARAM(
		$CA_Certificate = 'C:\HOL\SSL\CA-Certificate.cer',
		$OutFormat = 'PEM'
	)
	PROCESS {
		# The path to the openssl executable
		$OpenSSLExe =	"c:\hol\ssl\ssl-certificate-updater-tool-1308332\tools\openssl\openssl.exe"
		if (!(Test-Path $OpenSSLExe)) {throw "$OpenSSLExe required"}
		New-Alias -Name OpenSSL $OpenSSLExe

		if( $OutFormat -eq 'PEM' ) {
			$CA_CertificateTemp = $CA_Certificate + '.tmp'
			#Powershell does not seem to like the "." in the switch, so we run through CMD.EXE
			cmd /c "certutil -ca.cert $CA_CertificateTemp" | Out-Null
			#Convert it to PEM/ASCII from DER
			OpenSSL x509 -in $CA_CertificateTemp -inform DER -outform PEM -out $CA_Certificate
			Remove-Item $CA_CertificateTemp
		} else {
			cmd /c "certutil -ca.cert $CA_Certificate" | Out-Null
		}
		Write-Host "Complete. File is $CA_Certificate"
	}
} #Get-CaCertificate


###############################################################################
Function New-HostSslCertificate {
<#
	Create an SSL certificate for a generic host

	Requires openssl.exe and direct access to CA on "ControlCenter"
	Requires CA certificate exported (.CER) to path specified in $CA_Certificate
	NOTE: The password on the PFX is 'testpassword' 

	This one takes IPv4 addresses ONLY
#>
	PARAM(
	# The short name of the vCenter Server
	$HOST_SHORTNAME = $(throw "need -HOST_SHORTNAME"),
	# The DNS name of the ESXi host
	$HOST_FQDN = "$HOST_SHORTNAME.corp.local",
	# The IP address of the ESXi host
	$HOST_IPv4 = $(throw "need -HOST_IPv4"),
	# The path to the CA certificate
	$CA_Certificate = "c:\hol\ssl\CA-Certificate.cer"
	)
	PROCESS {
	# The Certificate Authority Name
	$CA_Name = "controlcenter.corp.local\CONTROLCENTER-CA"
	# The name of the Certificate template to use
	$CA_Template = "CertificateTemplate:VMwareCertificate"
	# Administrative email to use in the certificate
	$AdminEmail = "administrator@corp.local"
	# A working directory under which the certificates and folders will be created
	$WorkingDir = "c:\hol\ssl\host\$HOST_SHORTNAME"
	#Our Service Name
	$Service = "Hands-on Labs"
	# The path to the openssl executable
	$OpenSSLExe =	"c:\hol\ssl\ssl-certificate-updater-tool-1308332\tools\openssl\openssl.exe"
	
	if (!(Test-Path $OpenSSLExe)) {throw "$OpenSSLExe required"}
	New-Alias -Name OpenSSL $OpenSSLExe
	
	$RequestTemplate = "[ req ]
	default_md = sha512
	default_bits = 2048
	default_keyfile = rui.key
	distinguished_name = req_distinguished_name
	encrypt_key = no
	prompt = no
	string_mask = nombstr
	req_extensions = v3_req
	input_password = testpassword
	output_password = testpassword
	[ v3_req ]
	basicConstraints = CA:false
	keyUsage = digitalSignature, keyEncipherment, dataEncipherment
	extendedKeyUsage = serverAuth, clientAuth
	subjectAltName = DNS:SHORTNAMEREPLACE, IP: IPv4ADDRESSREPLACE, DNS: FQDNREPLACE
	[ req_distinguished_name ]
	countryName = US
	stateOrProvinceName = California
	localityName = Palo Alto
	0.organizationName = VMware
	organizationalUnitName = ORGNAMEREPLACE
	commonName = FQDNREPLACE
	emailAddress = ADMINEMAILREPLACE
	"
	if(!(Test-Path $WorkingDir)) {
		New-Item $WorkingDir -Type Directory
	}
	
	Set-Location $WorkingDir
	
	Write-Debug "$HOST_SHORTNAME : Writing Template"
	$Out = ((((($RequestTemplate -replace "FQDNREPLACE", $HOST_FQDN) -replace "SHORTNAMEREPLACE", $HOST_SHORTNAME) -replace "ORGNAMEREPLACE", $Service) -replace "ADMINEMAILREPLACE", $AdminEmail) -replace "IPv4ADDRESSREPLACE", $HOST_IPv4) | Out-File "$WorkingDir\$HOST_SHORTNAME.cfg" -Encoding Default -Force
	
	Write-Debug "$HOST_SHORTNAME : Generating CSR"
	OpenSSL req -new -nodes -out "$WorkingDir\$HOST_SHORTNAME.csr" -keyout "$WorkingDir\rui-orig.key" -config "$WorkingDir\$HOST_SHORTNAME.cfg"
	
	Write-Debug "$HOST_SHORTNAME : Converting Private Key to RSA"
	OpenSSL rsa -in "$WorkingDir\rui-orig.key" -out "$WorkingDir\rui.key"
	
	Write-Debug "$HOST_SHORTNAME : Submitting to $CA_Name"
	certreq -submit -attrib $CA_Template -config "$CA_Name" "$HOST_SHORTNAME.csr" "$WorkingDir\rui.crt"
	
	Write-Debug "$HOST_SHORTNAME : Generating PEM / Cert chain with Key"
	Copy-Item "$WorkingDir\rui.key" "$WorkingDir\rui.pem"
	Get-Content "$WorkingDir\rui.crt" | Out-File -Append -Encoding ASCII	"$WorkingDir\rui.pem"
	Get-Content "$CA_Certificate" | Out-File -Append -Encoding ASCII	"$WorkingDir\rui.pem"
	
	Write-Debug "$HOST_SHORTNAME : Generating PFX"
	OpenSSL pkcs12 -export -in "$WorkingDir\rui.crt" -inkey "$WorkingDir\rui.key" -certfile "$CA_Certificate" -name "rui" -passout pass:testpassword -out "$WorkingDir\rui.pfx"
	
	Set-Location $WorkingDir
	Write-Host "Finished"
	Write-Host "NOTE: The password on the PFX is 'testpassword'"
	}
} #New-HostSslCertificate

###############################################################################

Function New-HostSslCertificateFromCsr
{
<#
	Issue an SSL certificate from the provided CSR

	Requires openssl.exe and direct access to CA
	Requires CSR

#>
	PARAM(
	# The CSR File
	$CSR = $(throw "requires path to CSR file")
	)
	PROCESS {
	if (!(Test-Path $CSR)) {throw "$CSR not found"}
	$csrFile = Get-Item $CSR
	# A working directory under which the certificate will be created
	$WorkingDir = $CsrFile.DirectoryName
	# The Certificate Authority Name
	$CA_Name = "controlcenter.corp.local\CONTROLCENTER-CA"
	# The name of the Certificate template to use
	$CA_Template = "CertificateTemplate:VMwareCertificate"
	 
	if(!(Test-Path $WorkingDir)) {
		New-Item $WorkingDir -Type Directory
	}
	Set-Location $WorkingDir
	
	Write-Debug "Submitting to $CA_Name"
	$certFile = Join-Path $WorkingDir $($csrFile.BaseName + ".crt")
	certreq -submit -attrib $CA_Template -config "$CA_Name" $csrFile $certFile
	Write-Host "Finished"
	}
} #New-HostSslCertificateFromCsr

###############################################################################

###############################################################################

Function New-WildSslCertificate {
<#
	Create a wildcard SSL certificate

	Requires openssl.exe and direct access to CA
	Requires CA certificate exported (.CER) to path specified in $CA_Certificate

#>
	PARAM(
	# The DNS name of the ESXi host
	$WILD_FQDN = '*.corp.local',
	# The CA's certificate
	$CA_Certificate = "c:\hol\ssl\CA-Certificate.cer"
	)
	PROCESS {
	# The Certificate Authority Name
	$CA_Name = "controlcenter.corp.local\CONTROLCENTER-CA"
	# The name of the Certificate template to use
	$CA_Template = "CertificateTemplate:VMwareCertificate"
	# Administrative email to use in the certificate
	$AdminEmail = "administrator@corp.local"
	# A working directory under which the certificates and folders will be created
	$WorkingDir = "c:\hol\ssl\wild"
	#Our Service Name
	$Service = "Hands-on Labs"
	# The path to the openssl executable
	$OpenSSLExe =	"c:\hol\ssl\ssl-certificate-updater-tool-1308332\tools\openssl\openssl.exe"
	 
	if (!(Test-Path $OpenSSLExe)) {throw "$OpenSSLExe required"}
	New-Alias -Name OpenSSL $OpenSSLExe
	 
	$RequestTemplate = "[ req ]
	default_md = sha512
	default_bits = 2048
	default_keyfile = rui.key
	distinguished_name = req_distinguished_name
	encrypt_key = no
	prompt = no
	string_mask = nombstr
	req_extensions = v3_req
	input_password = testpassword
	output_password = testpassword
	[ v3_req ]
	basicConstraints = CA:false
	keyUsage = digitalSignature, keyEncipherment, dataEncipherment
	extendedKeyUsage = serverAuth, clientAuth
	subjectAltName = DNS:FQDNREPLACE
	[ req_distinguished_name ]
	countryName = US
	stateOrProvinceName = California
	localityName = Palo Alto
	0.organizationName = VMware
	organizationalUnitName = ORGNAMEREPLACE
	commonName = FQDNREPLACE
	emailAddress = ADMINEMAILREPLACE
	"
	if(!(Test-Path $WorkingDir)) {
		New-Item $WorkingDir -Type Directory
	}
	 
	Set-Location $WorkingDir 
	Write-Debug "$WILD_FQDN : Writing Template"
	$Out = ((($RequestTemplate -replace "FQDNREPLACE", $WILD_FQDN) -replace "ORGNAMEREPLACE", $Service) -replace "ADMINEMAILREPLACE", $AdminEmail)	| Out-File "$WorkingDir\wild.cfg" -Encoding Default -Force
		 
	Write-Debug "$WILD_FQDN : Generating CSR"
	OpenSSL req -new -nodes -out "$WorkingDir\wild.csr" -keyout "$WorkingDir\rui-orig.key" -config "$WorkingDir\wild.cfg"
	
	Write-Debug "$WILD_FQDN : Converting Private Key to RSA"
	OpenSSL rsa -in "$WorkingDir\rui-orig.key" -out "$WorkingDir\rui.key"
	
	Write-Debug "$WILD_FQDN : Submitting to $CA_Name"
	certreq -submit -attrib $CA_Template -config "$CA_Name" "wild.csr" "$WorkingDir\rui.crt"
	
	Write-Debug "$WILD_FQDN : Generating PFX"
	OpenSSL pkcs12 -export -in "$WorkingDir\rui.crt" -inkey "$WorkingDir\rui.key" -certfile "$CA_Certificate" -name "rui" -passout pass:testpassword -out "$WorkingDir\rui.pfx"
	
	Set-Location $WorkingDir

	Write-Host "Finished"
	Write-Host "NOTE: The password on the PFX is 'testpassword'"
	}
} #New-WildSslCertificate