Function Get-ImportStatus {
<#
.SYNOPSIS
		Report the status of an upload into VCD
.DESCRIPTION
		Watch the per-file upload of a template
.PARAMETER  Template
		The name of the vApp Template to be monitored.
.PARAMETER  Catalog
		The name of the catalog where Template is being uploaded.
.PARAMETER  ShowAll
		Switch to show all remaining files or only those in progress.
.EXAMPLE
		PS C:\> Get-ImportStatus -Catalog "2025-Labs" -Template "HOL-2540-v0.20"
#>
	[CmdletBinding()]
	param(
			[parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
					$Template,
					$Catalog,
					[switch]$ShowAll,
					[switch]$SummaryOnly
			)
	Process {
		$BYTES_PER_GB = [Math]::Pow(1024,3)
		Foreach ($t in $Template) {
			if( $catalog ) {
				$cat = Get-catalog $Catalog
				$catalog_name = $Catalog
				$pods = Get-civapptemplate -Name $Template -Catalog $cat
			} else {
				$pods = Get-civapptemplate -Name $Template
			}
			foreach( $vp in $pods ) {
				if( $vp.Catalog.Name ) {
					$catalog_name = $vp.Catalog.Name
				}
				else {
					$catalog_name = "NONE"
				}
				Write-Verbose "read $template from $catalog_name"
				$all_stats = $vp.ExtensionData.Files.File | Select-Object Name, Size, @{N="SizeGB";E={$_.Size/$BYTES_PER_GB}},BytesTransferred, @{N="TransferredGB";E={$_.BytesTransferred/$BYTES_PER_GB}}
				$remaining_stats = $all_stats| Where-Object { $_.Size -ne $_.BytesTransferred }
				if( $all_stats.Length -gt 0 ) {
					$total_gb_to_transfer = ($all_stats | Measure-Object -Property SizeGB -sum).Sum
					$total_gb_remaining = ($remaining_stats | Measure-Object -Property SizeGB -sum).Sum
					$total_gb_transferred = ($all_stats | Measure-Object -Property TransferredGB -sum).Sum
					#$percent_remaining = 100*($remaining_stats | Measure-Object -property Size -sum).sum / ($vp.ExtensionData.Files.File | Measure-Object -property Size -sum).Sum
					Write-Host -ForegroundColor DarkBlue "=== $template in $catalog_name ==================================="
					$outline = "Remaining {0:N0} of {1:N0} files, {2:F2} / {3:F2} GB. Finished: ({4:P1})" -f $remaining_stats.Length,($vp.ExtensionData.Files.File).Length,$total_gb_remaining,$total_gb_to_transfer,($total_gb_transferred/$total_gb_to_transfer)
					Write-Output $outline
					if( -Not $SummaryOnly ) {
						if( $ShowAll ) {
							$all_stats | Sort-Object -Property "SizeGB" -Descending | Format-Table -AutoSize
						} 
						else {
							$remaining_stats | Where-Object { $_.BytesTransferred -ne 0 } | Format-Table -AutoSize
						}
					}
				}
				else {
					#check for in-flight vdcUploadOvfContents task
					$import_tasks = $vp.ExtensionData.Tasks.Task | Where-Object {($_.OperationName -eq "vdcUploadOvfContents") -Or ($_.OperationName -eq "vdcCopyTemplate")} | Select-Object Operation, Status, Progress, StartTime
					if( $import_tasks ) {
						Write-Host -ForegroundColor Blue "=== $template in $catalog_name ==================================="
						foreach ( $import_task in $import_tasks ) {
							$outline = "Completed upload; {0} is '{1}' and {2:N0}% complete " -f $import_task.Operation, $import_task.Status, $import_task.Progress
							Write-Output $outline
							Write-Verbose "Start Time: $($import_task.StartTime)"
							$task_duration = $(Get-Date) - $import_task.StartTime
							Write-Output $("`tTask has been running for {0:dd} days, {0:hh} hrs, {0:mm} minutes" -f $task_duration)
						}
					}
					else {
						Write-Output "`n No upload, import or copy in progress for $Template in $catalog_name"
					}
				}
			}
		}
	}
}

