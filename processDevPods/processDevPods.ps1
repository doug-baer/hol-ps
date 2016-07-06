
Function Add-CIVAppShadows {
<#
Takes a list of vApps and a list of OrgVDCs
Provisions one copy of a vApp on each OrgVdc simultaneously (asynchronously)
Named <vAppName>_shadow_<OrgvdcName>
With 5 hour storage and Runtime leases -- should cleanup themselves
Waits for the last of the vApps to finish deploying before moving to the next template

$vApps = @()
$vAppNames | % { $vApps += (Get-CIVAppTemplate $_ -Catalog MY_CATALOG) } 
$orgVDCs = @()
$orgVdcNames | % { $orgVDCs += (Get-OrgVDC $_) }
#>
PARAM (
	$vApps=$(throw "need -vApps"), 
	$OrgVDCs=$(throw "need -OrgVdcs"),
	$SleepTime=30,
	$Debug=$false
)
PROCESS {
	$fiveHr = New-Object System.Timespan 5,0,0

	foreach( $vApp in $vApps ) {

		#create one shadow on each orgvdc
		Write-Host -fore Green "Beginning shadows for $($vApp.Name) at $(Get-Date)"
		foreach( $orgVDC in $OrgVDCs ) { 
			$shadowName = $($($vApp.Name) + "_shadow_" + $($orgVDC.Name))
			#New-CIVApp -Name $shadowName -OrgVdc $orgVDC -VAppTemplate $vApp -RuntimeLease $fiveHr -StorageLease $fiveHr -RunAsync | Out-Null
			New-CIVApp -Name $shadowName -OrgVdc $orgVDC -VAppTemplate $vApp -RunAsync | Out-Null
			Write-Host "==> Creating $shadowName"
		}
		#If I pull the "Status" from the object returned by New-vApp it isn't right. This works.
		$shadows = @{}
		$shadowPattern = $($vApp.Name) + "_shadow_*"
		if( $Debug ) { Write-Host -Fore Yellow "DEBUG: looking for $shadowPattern" }
		Foreach ($shadow in $(Get-CIVApp $shadowPattern)) { 
			$shadows.Add( $shadow.Name , $(Get-CIView -CIObject $shadow) )
		}

		#wait for all shadows of this template to complete before starting on next one
		while( $shadows.Count -gt 0 ) {
			#working around a Powershell quirk related to enumerating and modification
			$keys = $shadows.Clone().Keys

			foreach( $key in $keys ) {
				$shadows[$key].UpdateViewData()
 
				if( $shadows[$key].Status -ne 0 ) { 
					#has completed (usually status=8), remove it from the waitlist
					Write-Host "==> Finished $key with status $($shadows[$key].Status), $($shadows.count - 1) to go." 
					$shadows.Remove($key)
				}
			}

			#sleep between checks
			if( $shadows.Count -gt 0 ) {
				Write-Host -Fore Yellow "DEBUG: Sleeping $SleepTime sec at $(Get-Date)" 
				Sleep -sec $SleepTime
			}
		}
		Write-Host -fore Green "Finished shadows for $($vApp.Name) at $(Get-Date)"
	}
}
} #Add-CIVAppShadows


Function Add-CIVAppShadowsWait {
<#
Wait for a single template to be "Resolved" then kick off shadows
Quick and dirty... no error checking.. can go infinite if the import fails
#>
PARAM (
	$vApp=$(throw "need -vApps"), 
	$OrgVDCs=$(throw "need -OrgVdcs"),
	$SleepTime=300
)

PROCESS {
	while ($vApp.status -ne "Resolved") {
		write-host "$($vApp.status) : $(($vApp.ExtensionData.Tasks).Task[0].Progress)% complete"
		Sleep -sec $SleepTime
		$vApp = Get-civapptemplate $vApp.name -catalog $vApp.catalog
	}
	Add-CIVAppShadows -o $OrgVDCs -v $vApp
}
} #Add-CIVAppShadowsWait

#Import-Module shadow.psm1

<#
#Load the VMware PowerCLI tools
Try {
	#v5.x
	#  Add-PSSnapin VMware.VimAutomation.Core -ErrorAction 1
	#v6.x
	#C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1
	$PowerCliInit = 'C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1'
	. $PowerCliInit
} 
Catch {
	Write-Host "No PowerCLI found, unable to continue."
	Write-Progress "FAIL - No PowerCLI" 'FAIL-1'
	Exit
}
#>

# BEGIN HERE

# Change these appropriately

$cloud = 'vcore1-us03.oc.vmware.com'
$devOrgName = 'HOL-Dev'
$devUser = 'bcall'
$wipCatalogName = 'HOL-Staging'
$wipCatalogName = '_WorkInProgress'
$stageCatalogName = 'HOL-Staging'
#$stageCatalogName = 'Dell Staging ONLY'
#$stageCatalogName = 'HOL 2016 Released Labs'
$prodOrgName = 'HOL'
$prodUser = 'bcall-local'
$prodCatalogName = 'HOL-Masters'

$input = Get-Content $args[0]
# TODO: set your secret password here
$pass = "CHANGEME"

Try {
	Disconnect-CIServer * -Confirm:$false
} Catch {}

For ($i=0; $i -lt $input.Count; $i++) {

	# PowerShell fun with input lines (if only one line it's a special case. sigh)
	If ( $input.Count -eq 1 ) { $vPodName = $input }
	Else  { $vPodName = $input[$i] }
	
	# move vPod from _WorkInProgress to HOL-Staging in HOL-Dev
	Connect-CIServer $cloud -org $devOrgName -user $devUser -password $pass

	$wipCatalog = Get-Catalog $wipCatalogName
	$stageCatalog = Get-Catalog $stageCatalogName
	Try {
		$vpod = Get-CIVAppTemplate -Name $vPodName -ErrorAction 1
	} Catch {
		Write-Host "No such vApp Template $vPodName exists - skipping..."
		Continue
	}
	
	If ($vpod.length -gt 1 ) {
		Write-Host "More than one $vPodName vApp Template exists - skipping..."
		Continue
	}
	
	If ( $vpod.CustomizeOnInstantiate ) {
		Write-Host "$vpod is NOT set to make identical - skipping..."
		Continue
	} Else {
		Write-Host "$vpod is set to make identical and will be processed..."
	}
	
	# check each VM for suspended VMs.
	$VMs = Get-CIVMTemplate -VApp $vpod
	$skip = $False
	Foreach ($vm in $VMs) {
		If ($vm.Status -ne 'PoweredOff') {
				Write-Host "$vpod $vm.Name is not powered off"
				$skip = $True
				Continue
		}
	}
	
	If ( $skip ) {
		Write-Host "$vpod has a VM that is not powered off - skipping..."
		Continue
	} Else {
		Write-Host "$vpod VMs are all powered off.  Ready to process..."
	}
	
	$description = $vpod.Description
	
	$catalogItem =  $wipCatalog.ExtensionData.CatalogItems.CatalogItem | where { $_.Name -eq $vPodName }
	$ref = New-Object VMware.VimAutomation.Cloud.Views.Reference
	$ref.name = "this is a reference to the catalog Item we want to move"
	$ref.Href = $catalogItem.Href
	$ref.id = $catalogItem.id
	$ref.type = $catalogItem.type
	
	If ( $vpod.Catalog.Name -eq $wipCatalogName ) {

		Write-Host "Moving $vPodName from $wipCatalogName to $stageCatalogName..."
		$stageCatalog.ExtensionData.Move( $ref, $vPodName, $description )
	
	}
	Disconnect-CIServer * -Confirm:$false
	
	# copy vPod from public HOL-Staging to HOL-Masters in WDC1 HOL
	Connect-CIServer $cloud -org $prodOrgName -user $prodUser -password $pass
	$stageCatalog = Get-Catalog $stageCatalogName
	$prodCatalog = Get-Catalog $prodCatalogName
	
	$catalogItem =  $stageCatalog.ExtensionData.CatalogItems.CatalogItem | where { $_.Name -eq $vPodName }
	$ref = New-Object VMware.VimAutomation.Cloud.Views.Reference
	$ref.name = "this is a reference to the catalog Item we want to copy"
	$ref.Href = $catalogItem.Href
	$ref.id = $catalogItem.id
	$ref.type = $catalogItem.type

	Write-Host "Copying $vPodName from $stageCatalogName to $prodCatalogName..."
	$prodCatalog.ExtensionData.Copy( $ref, $vPodName, $description )

	
	# shadow vPod in WDC1
	Write-Host "Shadowing $vPodName..."
	$ov = get-orgvdc *ut* | where { $_.enabled -eq "True" }
	$shadowList = @()
	try {
		$vPod = Get-CIVAppTemplate $vpodName -catalog $prodCatalogName -ErrorAction 1
		Add-CIVAppShadowsWait -o $ov -v $vPod -sleep 30
		Get-civapp $($vpodName + '_shadow_*') | % {
			if( $_.Status -ne "PoweredOff" ) {
				Write-Host  -BackgroundColor Magenta -ForegroundColor Black "Bad Shadow:" $_.Name $_.Status
			}
			$shadowList += $_
		}
		Write-Host "Removing shadows for $vPodName"
		$shadowList | Remove-civapp -Confirm:$false
    } 
    catch {
      Write-Host -ForegroundColor Red "vPod $vPodName not found!"
    }
	Disconnect-ciserver * -Confirm:$false
}

###END

