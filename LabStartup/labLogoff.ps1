#Fixup the Lab Status color to Red
$desktopInfo = 'C:\DesktopInfo\desktopinfo.ini'
(Get-Content $desktopInfo) | % { 
	$line = $_
	If( $line -match 'Lab Status' ) {
		$line = $line -replace '55CC77','3A3AFA'
	}
	$line
} | Out-File -FilePath $desktopInfo -encoding "ASCII"

#Remove the file that causes the "Reset" message in Firefox
$userProfilePath = (Get-Childitem env:UserProfile).Value
$firefoxProfiles = Get-ChildItem (Join-Path $userProfilePath 'AppData\Roaming\Mozilla\Firefox\Profiles')
ForEach ($firefoxProfile in $firefoxProfiles) {
	$firefoxLock = Join-Path $firefoxProfile.FullName 'parent.lock'
	If(Test-Path $firefoxLock) { Remove-Item $firefoxLock | Out-Null }
}

# Empty recycle bin for current user
$Shell = New-Object -ComObject Shell.Application
$RecBin = $Shell.Namespace(0xA)
If( $RecBin.Items().Count -gt 0 ) {
	$RecBin.Items() | %{ Remove-Item $_.Path -Recurse -Confirm:$false }
}

# unregister the LabCheck scheduled Task (LabStartup will create at boot)
$result = UnRegister-ScheduledTask -TaskName "LabCheck" -Confirm:$false