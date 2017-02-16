#Fixup the Lab Status color to Red
$desktopInfo = 'C:\DesktopInfo\desktopinfo.ini'
(Get-Content $desktopInfo) | % { 
	$line = $_
	If( $line -match 'Lab Status' ) {
		$line = $line -replace '55CC77','3A3AFA'
	}
	$line
} | Out-File -FilePath $desktopInfo -encoding "ASCII"

# Empty recycle bin for current user
$Shell = New-Object -ComObject Shell.Application
$RecBin = $Shell.Namespace(0xA)
If( $RecBin.Items().Count -gt 0 ) {
	$RecBin.Items() | %{ Remove-Item $_.Path -Recurse -Confirm:$false }
}

#clear out the startup_status file
$startup_status = 'C:\HOL\startup_status.txt'
Set-Content -Path $startup_status -Value "STARTING" -Force -Confirm:$false

# unregister the LabCheck scheduled Task (LabStartup will create at boot)
$result = UnRegister-ScheduledTask -TaskName "LabCheck" -Confirm:$false