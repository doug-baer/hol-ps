#
# ReportDiskChains.ps1 - v1.0.2 - 05 July 2017
#
#Report on disk chain lengths
$cloudkey = 'HOL-DEV'
$sysUser = "c_us04_vcore3_nee"
$DevOrg = "us04-3-hol-dev-d"
$WipCatalog = "_WorkInProgress"
$ChainLengthWarn = 10

Write-Host "/// HOL vCD Disk Chain Length Reporter ///"

if( ($Global:DefaultCIServers).Length -gt 0 ) {
	Write-Host -ForegroundColor Yellow "Disconnecting from all clouds"
	Disconnect-CiServer * -Confirm:$false | Out-Null
}

#get system credential and log in as sysadmin (so we can see the chain lengths)
$cloud = (Get-CloudInfoFromKey -Key $cloudkey)[0]
$c = Get-Credential $sysUser
Connect-CIserver $cloud -org system -Credential $c | Out-Null
$c = $null

Write-Host -ForegroundColor Green "`n/// Analyzing deployed vApps in $DevOrg at $(Get-Date)`n"

get-org $DevOrg | get-civm "Main Console" | ? { 
	$($_.ExtensionData.VCloudExtension.any.VirtualDisksMaxChainLength -as [int]) -gt $ChainLengthWarn } | select name, vapp, `
	@{N='Owner id';E={$_.vapp.owner}},  `
	@{N='Chain Length';E={$_.ExtensionData.VCloudExtension.any.VirtualDisksMaxChainLength} 
} | Sort-Object -Property "Chain Length" -Descending | ft -auto


Write-Host -ForegroundColor Green "`n/// Analyzing templates in catalog $WipCatalog at $(Get-Date)`n"

Get-CIVAppTemplate -Catalog $WipCatalog | Get-CIVMTemplate -Name "Main Console" | ? { 
	$($_.ExtensionData.VCloudExtension.any.VirtualDisksMaxChainLength -as [int]) -gt $ChainLengthWarn } | select name, vapptemplate, `
	@{N='Owner id';E={$_.vapptemplate.owner}},  `
	@{N='Chain Length';E={$_.ExtensionData.VCloudExtension.any.VirtualDisksMaxChainLength} 
}  | Sort-Object -Property "Chain Length" -Descending | ft -auto

Write-Host "/// End $(Get-Date)"

Disconnect-CiServer * -Confirm:$false
