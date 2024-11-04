function Show-DownloadEnabled ()
{
	[CmdletBinding()]
	param ( [Parameter (ValueFromPipeline)]
		$catalogName
	)

	process
	{
		$catalog = Get-Catalog -Name $catalogName
		$vapps = Get-CIVappTemplate -Catalog $catalog
		$enabledTemplates = @()
		
		foreach ($p in $vapps) { 
			$pv = Get-CIView $p
			$dlHref = $pv.Link | Where-Object {$_.Rel -eq "download:identity"}
			Write-Verbose "$($p.name) --- $($dlHref.href)"
			if( $dlHref.href -like "http*" ) {
				write-Verbose "ENABLED: $($p.name)"
				$enabledTemplates += $p.Name
			}
		}
		return $enabledTemplates
	}
}

