# disable HOL-Dev accounts with exceptions

$cloud = 'vcore1-us03.oc.vmware.com'
$devOrgName = 'HOL-Dev'
$devUser = 'scriptuser'
$pass = 'XXXXXXX'

Try {
	Disconnect-CIServer * -Confirm:$false
} Catch {}

Connect-CIServer $cloud -org $devOrgName -user $devUser -password $pass

$keep = @{
	# technical marketing
	'ahald' = $true
	'bbazan' = $true
	'bcall' = $true
	'bcall-test' = $true
	'dbaer' = $true
	'devpodman' = $true
	'dmischak' = $true
	'drollins' = $true
	'hmourad' = $true
	'hstagner' = $true
	'joeyd' = $true
	'joeyd-local' = $true
	'jschnee' = $true
	'kgleed' = $true
	'nee-dev' = $true
	'nee-prod' = $true
	'rnoth' = $true
	'scriptuser' = $true
	'sqlworkshopdev' = $true
	'testinguser' = $true
	# approved captains/principals
	'jschulman' = $true
	'ksteil' = $true
	'jlafollette' = $true
	'sray' = $true
	'kluck' = $true
	'jsilvagi' = $true
	'gparsons' = $true
	'smomber' = $true
}

Write-Host "Retrieving user accounts from $devOrgName..."
$ciUsers = Get-CIUser -Org $devOrgName -name 'bcall-test' # only testing
#$ciUsers = Get-CIUser -Org $devOrgName # this is the real call

Foreach ($ciUser in $ciUsers) {
	#Write-Host $ciUser.Name
	If ( $keep[$ciUser.Name] ) {
		Write-Host "found $ciUser in keep array so will NOT disable"
	} Else {
		If ( $ciUser.Enabled ) { # because UpdateServerData() takes some time only disable if needed
			Write-Host "disabling $ciUser..."
			$ciUser.ExtensionData.IsEnabled = $false
			$tmp = $ciUser.ExtensionData.UpdateServerData()
		} Else {
			Write-Host "$ciUser is already disabled."
		}
	}
}

Disconnect-CIServer * -Confirm:$false

###END