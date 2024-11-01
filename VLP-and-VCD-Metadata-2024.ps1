#
# VCD Metadata management from October/November 2024 - Updated for new VCD API 
#
# Code works and had been used, but has not been cleaned up for general consumption yet.
# 
# In progress, pending completion of VMware Explore 2024/Barcelona
#
# Some of this is based on earlier work from Alan Renouf, but updated fo reflect new VCD API
#



#create a report of current metadata
$report = @()
foreach ($vp in $pods ) {
  $data = Get-CIMetaData -CIObject $vp
  $line = "" | Select-Object Pod,Catalog,networkTag1,vappNetwork1
  $line.pod = $vp.Name
  $line.catalog = $vp.Catalog.Name
  $nettag = $data | where { $_.Key -eq "networkTag1" }
  if( $nettag ) { $line.networkTag1 = $nettag.Value }
  $vappnet = $data | where { $_.Key -eq "vappNetwork1" }
  if( $vappnet ) { $line.vappNetwork1 = $vappnet.Value }
  $report += $line
} ; $report


#Set the two metadata items used by the VMware Lab Platform to automatically connect deployed vApps to the network
foreach ($vp in $pods ) {
	$vappNet = Get-vAppNetName -CiObject $vp
	New-CIMetaData -CIObject $vp -Key 'vappNetwork1' -Value $vappNet
	New-CIMetaData -CIObject $vp -Key 'networkTag1' -Value 'default'
}


# Used by the above loop to get the name of the vApp Network (filters based on known HOL primary vApp network names)
Function Get-vAppNetName {
	param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
            [PSObject[]]$CIObject
        )
	Process {
		$sections = $CIObject.ExtensionData.Section
		foreach( $s in $sections ) {
			if ($s.Network) { 
				foreach( $network in $s.Network ) {
					# Match for HOL-Specific "primary" network names
					if( $network.Name -match 'vAppNet' -Or $network.Name -match 'lab_builder_net' -Or $network.Name -match 'VCF-NET' ) {
						return $network.Name
					}
				} 
			}
		}
	}
}

#####

Function New-CIMetaData {
    <#
    .SYNOPSIS
        Creates a Metadata Key/Value pair.
    .DESCRIPTION
        Creates a custom Metadata Key/Value pair on a specified vCloud object
    .PARAMETER  Key
        The name of the Metadata to be applied.
    .PARAMETER  Value
        The value of the Metadata to be applied.
    .PARAMETER  CIObject
        The object on which to apply the Metadata.
    .EXAMPLE
        PS C:\> New-CIMetadata -Key "Owner" -Value "Alan Renouf" -CIObject (Get-Org Org1)
    #>
     [CmdletBinding(
         SupportsShouldProcess=$true,
        ConfirmImpact="High"
    )]
    param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
            [PSObject[]]$CIObject,
            $Key,
            $Value
        )
    Process {
        Foreach ($Object in $CIObject) {
            $Metadata = New-Object VMware.VimAutomation.Cloud.Views.Metadata
            $Metadata.MetadataEntry = New-Object VMware.VimAutomation.Cloud.Views.MetadataEntry
            $Metadata.MetadataEntry[0].Key = $Key
            # $Metadata.MetadataEntry[0].Value = $Value
            $Metadata.MetadataEntry[0].TypedValue = New-Object VMware.VimAutomation.Cloud.Views.MetadataStringValue
            $Metadata.MetadataEntry[0].TypedValue.Value = $Value
            $Object.ExtensionData.CreateMetadata($Metadata)
            ($Object.ExtensionData.GetMetadata()).MetadataEntry | Where {$_.Key -eq $key } | Select @{N="CIObject";E={$Object.Name}}, Key, @{N="Value";E={$_.TypedValue.Value}}
        }
    }
}

#####

Function Get-CIMetaData {
    <#
    .SYNOPSIS
        Retrieves all Metadata Key/Value pairs.
    .DESCRIPTION
        Retrieves all custom Metadata Key/Value pairs on a specified vCloud object
    .PARAMETER  CIObject
        The object on which to retrieve the Metadata.
    .PARAMETER  Key
        The key to retrieve.
    .EXAMPLE
        PS C:\> Get-CIMetadata -CIObject (Get-Org Org1)
    #>
    param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
            [PSObject[]]$CIObject,
            $Key
        )
    Process {
        Foreach ($Object in $CIObject) {
            If ($Key) {
                #($Object.ExtensionData.GetMetadata()).MetadataEntry | Where {$_.Key -eq $key } | Select @{N="CIObject";E={$Object.Name}}, Key, Value
                ($Object.ExtensionData.GetMetadata()).MetadataEntry | where {$_.key -eq "networkTag1"} | Select @{N="CIObject";E={$Object.Name}}, Key, @{N="Value";E={$_.TypedValue.Value}}
            } Else {
                ($Object.ExtensionData.GetMetadata()).MetadataEntry | Select @{N="CIObject";E={$Object.Name}}, Key, @{N="Value";E={$_.TypedValue.Value}}
            }
        }
    }
}

#####

Function Remove-CIMetaData {
    <#
    .SYNOPSIS
        Removes a Metadata Key/Value pair.
    .DESCRIPTION
        Removes a custom Metadata Key/Value pair on a specified vCloud object
    .PARAMETER  Key
        The name of the Metadata to be removed.
    .PARAMETER  CIObject
        The object on which to remove the Metadata.
    .EXAMPLE
        PS C:\> Remove-CIMetaData -CIObject (Get-Org Org1) -Key "Owner"
    #>
     [CmdletBinding(
         SupportsShouldProcess=$true,
        ConfirmImpact="High"
    )]
    param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
            [PSObject[]]$CIObject,
            $Key
        )
    Process {
        $CIObject | Foreach {
            $metadataValue = ($_.ExtensionData.GetMetadata()).GetMetaDataValue($Key)
            If($metadataValue) { $metadataValue.Delete() }
        }
    }
}

#####

Function Remove-CIMetaDataDuplicate {
    <#
    
    HACK
    
    It is possible to have two metadata items with the same name if one is read-only and the other is R/W
    it may have to do with one being in the "system" domain and being managed by the sysadmin
    This should remove the duplicate that is R/W 
    
    The command takes two parameters: the VCD object (template) and the name of the metadata key to look for and remove duplicate
    #>
    param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
            [PSObject[]]$CIObject,
            $Key
        )
    Process {
        Foreach ($Object in $CIObject) {
            If ($Key) {
                $matches = ($Object.ExtensionData.GetMetadata()).MetadataEntry | Where {$_.Key -eq $key }
                If( $matches.Length -ge 2 ) {
                	Write-Host "`t Duplicate found. Deleting R/W entry from $($Object.Name)"
                	Remove-CIMetaData -CIObject $Object -Key $Key
                	#foreach ($entry in $matches) {
                	#	if( -not $entry.Domain ) {
                	#		Write-Host "`t deleting R/W entry from $($Object.Name)"
                	#		$entry.Delete()
                	#	}
                	#}
                }
            } Else {
                Write-Host "NEED A KEY"
            }
        }
    }
}