
Function Create-VcenterSslCertificates
{
<#
  Create a batch of SSL certificates **for vCenter Server Appliance**

  Requires openssl.exe and direct access to CA
  Requires CA certificate exported (.CER) to path specified in $CA_Certificate

  This function outputs a set of certificates suitable for use on VCSA 5.1 and 5.5
#>
  PARAM(
    # The short name of the vCenter Server
    $VC_SHORTNAME = $(throw "need -VC_SHORTNAME"),
    # The DNS name of the vCenter Server
    $VC_FQDN = "$VC_SHORTNAME.corp.local",
    # The IP address of the vCenter Server
    $VC_IPv4 = $(throw "need -VC_IPv4"),
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
    $WorkingDir = "c:\hol\ssl\vCenter\$VC_SHORTNAME"
    # An array of the services we will generate the certificates for
    $Services = @("AutoDeploy","vCenterSSO","InventoryService","LogBrowser")
    # The path to the openssl executable
    $OpenSSLExe =  "c:\hol\ssl\ssl-certificate-updater-tool-1308332\tools\openssl\openssl.exe"
  
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
  
    ForEach ($Service in $Services) {
      if(!(Test-Path $Service)) {
        New-Item $Service -Type Directory
      }
    
      Set-Location $Service
    
      Write-Debug "$Service : Writing Template"
      $Out = ((((($RequestTemplate -replace "FQDNREPLACE", $VC_FQDN) -replace "SHORTNAMEREPLACE", $VC_SHORTNAME) -replace "ORGNAMEREPLACE", $Service) -replace "ADMINEMAILREPLACE", $AdminEmail) -replace "IPv4ADDRESSREPLACE", $VC_IPv4) | Out-File "$WorkingDir\$Service\$Service.cfg" -Encoding Default -Force
    
      Write-Debug "$Service : Generating CSR"
      OpenSSL req -new -nodes -out "$WorkingDir\$Service\$Service.csr" -keyout "$WorkingDir\$Service\rui-orig.key" -config "$WorkingDir\$Service\$Service.cfg"
    
      Write-Debug "$Service : Converting Private Key to RSA"
      OpenSSL rsa -in "$WorkingDir\$Service\rui-orig.key" -out "$WorkingDir\$Service\rui.key"
    
      Write-Debug "$Service : Submitting to $CA_Name"
      certreq -submit -attrib $CA_Template -config "$CA_Name" "$Service.csr" "$WorkingDir\$Service\rui.crt"
    
      Write-Debug "$Service : Generating PFX"
      OpenSSL pkcs12 -export -in "$WorkingDir\$Service\rui.crt" -inkey "$WorkingDir\$Service\rui.key" -certfile "$CA_Certificate" -name "rui" -passout pass:testpassword -out "$WorkingDir\$Service\rui.pfx"
    
      Set-Location $WorkingDir
    }
  }
} #Create-VcenterSslCertificates

###############################################################################

Function New-VcenterSslCertificatesWin
{
<#
  Create a batch of SSL certificates for vCenter Server on Windows

  Requires openssl.exe and direct access to CA
  
  Requires set of keys and CSRs created and named with SSL Automaton Tool
  
  Requires request directories copied to C:\HOL\SSL\vCenter\$VC_SHORTNAME

  Requires CA certificate exported (.CER) to path specified in $CA_Certificate
#>
  PARAM(
    # The short name of the vCenter Server
    $VC_SHORTNAME = $(throw "need -VC_SHORTNAME"),
    # The CA's certificate
    $CA_Certificate = "c:\hol\ssl\CA-W12.cer"
	)
  PROCESS {
    # The Certificate Authority Name
    $CA_Name = "controlcenter.corp.local\CONTROLCENTER-CA"
    # The name of the Certificate template to use
    $CA_Template = "CertificateTemplate:VMwareCertificate"
    # Administrative email to use in the certificate
    $AdminEmail = "administrator@corp.local"
    # A working directory under which the certificates and folders will be created
    $WorkingDir = "c:\hol\ssl\vCenter\$VC_SHORTNAME"
    # An array of the services we will generate the certificates for
    $Services = @("vCenterSSO-$VC_SHORTNAME","vCenterServer-$VC_SHORTNAME","vCenterInventoryService-$VC_SHORTNAME","vCenterLogBrowser-$VC_SHORTNAME","vCenterWebClient-$VC_SHORTNAME")
    # The path to the openssl executable
    $OpenSSLExe =  "c:\hol\ssl\ssl-certificate-updater-tool-1308332\tools\openssl\openssl.exe"
   
    if (!(Test-Path $OpenSSLExe)) {throw "$OpenSSLExe required"}
    if (!(Get-Alias OpenSSL -EA 0)) {
      New-Alias -Name OpenSSL $OpenSSLExe
    }
    
    if (!(Test-Path $CA_Certificate)) {throw "CA_Certificate required"}

    if(!(Test-Path $WorkingDir)) {
      New-Item $WorkingDir -Type Directory
    }
   
    Set-Location $WorkingDir
   
    ForEach ($Service in $Services) {
      if(!(Test-Path $Service)) {
        New-Item $Service -Type Directory
      }
     
      Set-Location $Service
          
      Write-Debug "$Service : Converting Private Key to RSA"
      Copy "$WorkingDir\$Service\rui.key" "$WorkingDir\$Service\rui-orig.key"
      OpenSSL rsa -in "$WorkingDir\$Service\rui-orig.key" -out "$WorkingDir\$Service\rui.key"
     
      Write-Debug "$Service : Submitting to $CA_Name"
      certreq -submit -attrib $CA_Template -config "$CA_Name" "$WorkingDir\$Service\rui.csr" "$WorkingDir\$Service\rui.crt"
     
      Write-Debug "$Service : Generating PEM / Cert chain"
      Copy-Item "$WorkingDir\$Service\rui.crt" "$WorkingDir\$Service\rui.pem"
	  Get-Content "$CA_Certificate" | Out-file -Append -Encoding ASCII  "$WorkingDir\$Service\rui.pem"

      Write-Debug "$Service : Generating PFX"
      OpenSSL pkcs12 -export -in "$WorkingDir\$Service\rui.crt" -inkey "$WorkingDir\$Service\rui.key" -certfile "$CA_Certificate" -name "rui" -passout pass:testpassword -out "$WorkingDir\$Service\rui.pfx"
     
      Set-Location $WorkingDir
    }
  }
} #New-VcenterSslCertificatesWin


Function Create-HostSslCertificate6
{
<#
  Create an SSL certificate for ESXi host

  Requires openssl.exe and direct access to CA
  Requires CA certificate exported (.CER) to path specified in $CA_Certificate

  
  This one wants both IPv4 and IPv6 addresses for the host
#>
  PARAM(
    # The short name of the vCenter Server
    $HOST_SHORTNAME = $(throw "need -HOST_SHORTNAME"),
    # The DNS name of the ESXi host
    $HOST_FQDN = "$HOST_SHORTNAME.corp.local",
    # The IP address of the ESXi host
    $HOST_IPv4 = $(throw "need -HOST_IPv4"),
    # The IPv6 address of the ESXi host
    $HOST_IPv6 = $(throw "need -HOSTIPv6"),
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
    $WorkingDir = "c:\hol\ssl\ESXi\$HOST_SHORTNAME"
    #Our Service Name
    $Service = "Hands-on Labs"
    # The path to the openssl executable
    $OpenSSLExe =  "c:\hol\ssl\ssl-certificate-updater-tool-1308332\tools\openssl\openssl.exe"
  
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
    subjectAltName = DNS:SHORTNAMEREPLACE, IP: IPv4ADDRESSREPLACE, IP:IPv6ADDRESSREPLACE, DNS: FQDNREPLACE
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
    $Out = (((((($RequestTemplate -replace "FQDNREPLACE", $HOST_FQDN) -replace "SHORTNAMEREPLACE", $HOST_SHORTNAME) -replace "ORGNAMEREPLACE", $Service) -replace "ADMINEMAILREPLACE", $AdminEmail) -replace "IPv4ADDRESSREPLACE", $HOST_IPv4) -replace "IPv6ADDRESSREPLACE", $HOST_IPv6) | Out-File "$WorkingDir\$HOST_SHORTNAME.cfg" -Encoding Default -Force
  
    Write-Debug "$HOST_SHORTNAME : Generating CSR"
    OpenSSL req -new -nodes -out "$WorkingDir\$HOST_SHORTNAME.csr" -keyout "$WorkingDir\rui-orig.key" -config "$WorkingDir\$HOST_SHORTNAME.cfg"
  
    Write-Debug "$HOST_SHORTNAME : Converting Private Key to RSA"
    OpenSSL rsa -in "$WorkingDir\rui-orig.key" -out "$WorkingDir\rui.key"
  
    Write-Debug "$HOST_SHORTNAME : Submitting to $CA_Name"
    certreq -submit -attrib $CA_Template -config "$CA_Name" "$HOST_SHORTNAME.csr" "$WorkingDir\rui.crt"
  
    Write-Debug "$HOST_SHORTNAME : Generating PFX"
    OpenSSL pkcs12 -export -in "$WorkingDir\rui.crt" -inkey "$WorkingDir\rui.key" -certfile "$CA_Certificate" -name "rui" -passout pass:testpassword -out "$WorkingDir\rui.pfx"
  
    Set-Location $WorkingDir
  }

  Write-Host "Finished"
  Write-Host "NOTE: The password on the PFX is 'testpassword'"

} #Create-HostSslCertificate6


###############################################################################

Function Create-SrmSslCertificate
{
<#

  Create SSL certificate for one SRM server
  Requires openssl.exe and direct access to CA
  
  SRM has some 'special' requirements when it comes to certificates
  Documented here: http://kb.vmware.com/kb/1008390

#>
  PARAM(
    # The short name of the SRM Server (all lowercase, please)
    $SRM_SHORTNAME = "",
    # The DNS name of the vCenter Server (defaults to SHORTNAME@corp.local)
    $SRM_FQDN = "$SRM_SHORTNAME.corp.local",
    # The IP address of the vCenter Server
    $SRM_IPv4 = "",
    # The name of the Org *must match in all certs: BOTH vCenter Server certs and BOTH SRM certs*
    $OrgName = "",
    # The name of the Org Unit *must match in all certs: BOTH vCenter Server certs and BOTH SRM certs*
    $OrgUnitName = ""
  )
  PROCESS {
  #SRM is case sensitive here... use lowercase, please!
  $SRM_SHORTNAME = $SRM_SHORTNAME.ToLower()
  $SRM_FQDN = $SRM_FQDN.ToLower()
    # The Certificate Authority Name
    $CA_Name = "controlcenter.corp.local\CONTROLCENTER-CA"
    # The name of the Certificate template to use
    $CA_Template = "CertificateTemplate:VMwareCertificate"
    # Administrative email to use in the certificate
    $AdminEmail = "administrator@corp.local"
    # A working directory under which the certificates and folders will be created
    $WorkingDir = "c:\hol\ssl\SRM\$SRM_SHORTNAME"
    # The path to the openssl executable
    $OpenSSLExe =  "c:\hol\ssl\ssl-certificate-updater-tool-1308332\tools\openssl\openssl.exe"
  
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
    0.organizationName = ORGNAMEREPLACE
    organizationalUnitName = OUNAMEREPLACE
    commonName = SRM
    "
    if(!(Test-Path $WorkingDir)) {
      New-Item $WorkingDir -Type Directory
    }
    
    Set-Location $WorkingDir
      
    Write-Debug "SRM : Writing Template"
    $Out = (((((($RequestTemplate -replace "FQDNREPLACE", $SRM_FQDN) -replace "SHORTNAMEREPLACE", $SRM_SHORTNAME) -replace "ORGNAMEREPLACE", $OrgName) -replace "ADMINEMAILREPLACE", $AdminEmail) -replace "IPv4ADDRESSREPLACE", $SRM_IPv4) -replace "OUNAMEREPLACE", $OrgUnitName) | Out-File "$WorkingDir\SRM.cfg" -Encoding Default -Force

    Write-Debug "SRM : Generating CSR"
    OpenSSL req -new -nodes -out "$WorkingDir\SRM.csr" -keyout "$WorkingDir\rui-orig.key" -config "$WorkingDir\SRM.cfg"

    Write-Debug "SRM : Converting Private Key to RSA"
    OpenSSL rsa -in "$WorkingDir\rui-orig.key" -out "$WorkingDir\rui.key"

    Write-Debug "SRM : Submitting to $CA_Name"
    certreq -submit -attrib $CA_Template -config "$CA_Name" "$WorkingDir\SRM.csr" "$WorkingDir\rui.crt"

    Write-Debug "$Service : Generating P12"
    OpenSSL pkcs12 -export -in "$WorkingDir\rui.crt" -inkey "$WorkingDir\rui.key" -name "rui" -passout pass:testpassword -out "$WorkingDir\rui.p12"

    Set-Location $WorkingDir
  }
} #Create-SrmSslCertificate