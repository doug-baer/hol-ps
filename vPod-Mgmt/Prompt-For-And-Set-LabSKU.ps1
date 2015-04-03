[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null

$desktopInfo = 'C:\DesktopInfo\desktopinfo.ini'

If( Test-Path $desktopInfo ) {
	$TMP = Select-String $desktopInfo -pattern "^COMMENT=active:1"
	$TMP = $TMP.Line.Split(":")
	$currentSku = $TMP[5]

	$message = "Enter your lab's full SKU"
	While( $currentSku -match "XXX" ) {
		$labSku = $currentSku
		$labSku = [Microsoft.VisualBasic.Interaction]::InputBox($message, "Lab SKU", $labSku)
		$labSku = $labsku.ToUpper()
		If( $labSku -match "HOL-[HMPS][BDR][CDLT]-16\d\d" ) {
			write-host "Replace $currentSku with $labSku"
			###
			(Get-Content $desktopInfo) | % { 
				$line = $_
				If( $line -match $currentSku ) {
					$line = $line -replace $currentSku,$labSku
				}
				$line
			} | Out-File -FilePath $desktopInfo -encoding "ASCII"
			$currentSku = $labSku
		} Else {
			$message = "Please try again`n`nEnter your lab's FULL SKU:"
		}
	}
}