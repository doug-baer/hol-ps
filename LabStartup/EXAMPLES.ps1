<#
EXAMPLE 1
	Use RunWinCmd to run a command on a Windows machine
#>

$wcmd = "ipconfig /all"
Do { 
		# optionally include a remote machine name.
		# by default it uses $vcuser and $password but a non-domain administrator user and password can be specified
		# PowerShell scripts cannot be run remotely. Call the PS script from a bat.
		$output = RunWinCmd $wcmd ([REF]$result) # remoteServer remoteServer\Administrator VMware1!
		ForEach ($line in $output) {
		    Write-Output $line
		}
		LabStartup-Sleep 5
	} Until ($result -eq "success")


<#
EXAMPLE 2
	example copy a file to or from Linux machine using pscp.exe
	you must have pscp.exe in the location specified by $pscpPath

	use the pscp conventions for source and destination files
	remote to remote is not allowed
	source must be a regular file and not a folder
	destination can be a folder
#>

$source = 'full-sles-01a.corp.local:/tmp/linuxfile.log'
$dest =  Join-Path $labStartupRoot 'linuxfile.log'
Write-Output "Copying $source to $dest..."
$msg = Invoke-Pscp -login $linuxUser -passwd $linuxPassword -sourceFile $source -destFile $dest
Write-Output $msg
