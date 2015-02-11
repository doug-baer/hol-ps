# Empty recycle bin for current user
$Shell = New-Object -ComObject Shell.Application
$RecBin = $Shell.Namespace(0xA)
If( $RecBin.Items().Count -gt 0 ) {
	$RecBin.Items() | %{Remove-Item $_.Path -Recurse -Confirm:$false}
}
