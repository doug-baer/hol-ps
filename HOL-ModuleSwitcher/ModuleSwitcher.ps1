<#

.SYNOPSIS			Module Switcher panel for HOL vPods

.DESCRIPTION	

.NOTES				Version 1.01 - 09 March 2016
 
.EXAMPLE			.\ModuleSwitcher.ps1

.INPUTS				Provide scripts with names like "Module02.ps1" in the $ModuleSwitchDir
							** Note the two-digit value in the script names **
							Each provided script should take two parameters: "START" and "STOP"

.OUTPUTS			Each script is launched in its own PS console

#>

$ModuleSwitchDir = 'C:\HOL\ModuleSwitcher'
if( Test-Path $ModuleSwitchDir ) {
	$ModuleScripts = Get-ChildItem -Path $ModuleSwitchDir -Filter 'Module*.ps1' | Sort
	$numButtons = $ModuleScripts.Count
} else {
	Write-Host -ForegroundColor Red "ERROR - Unable to locate $ModuleSwitchDir"
	exit
}

# Initially, module 1 is the active module
$activeModule = 1

# Create a hashtable of Start buttons here
$StartButtons = @{}

#Initial size of the panel
$MainFormWidth = 450
$MainFormHeight = 500


########################################################################

Set-Variable BUTTON_WIDTH  -value 75 -option Constant
Set-Variable BUTTON_HEIGHT -value 25 -option Constant
Set-Variable GROUP_WIDTH   -value 85 -option Constant
Set-Variable GROUP_HEIGHT  -value 50 -option Constant

Set-Variable BUTTON_OFFSET_X -value 5 -option Constant
Set-Variable BUTTON_OFFSET_Y -value 20 -option Constant

Set-Variable NUM_COLUMNS -value 4 -option Constant

Set-Variable row1 -value 50  -option Constant
Set-Variable row2 -value 120 -option Constant
Set-Variable row3 -value 190 -option Constant
Set-Variable row4 -value 260 -option Constant
Set-Variable row5 -value 330 -option Constant
Set-Variable row6 -value 400 -option Constant

Set-Variable col1 -value 10  -option Constant
Set-Variable col2 -value 105 -option Constant
Set-Variable col3 -value 200 -option Constant
Set-Variable col4 -value 295 -option Constant

# the value of 20 is the offset from the edge
# the bottom gets an extra 30 for the height of the status bar + 10 extra

## Resize panel based on number of Module scripts available
$MainFormWidth = $col4 + $BUTTON_WIDTH + ($NUM_COLUMNS * 5) # 390 for all
$numRows = [math]::ceiling($numButtons / $NUM_COLUMNS)
if( $numRows -lt 7 ) {
	#Write-Host "Setting Form Height to " (Get-Variable "row$numRows").Value
	$MainFormHeight = (Get-Variable "row$numRows").Value + $BUTTON_HEIGHT + 50
} else {
	Write-Host -ForegroundColor Red "ERROR: That's a lot of modules!"
	Break
}	


########################################################################
### Disable previous Module buttons -- no 'rollback' allowed

function DisablePrevious { 
	PARAM ( [int]$thisModule )
	PROCESS {
		if( $thisModule -gt $activeModule ) {
			for($i=$activeModule; $i -lt $thisModule; $i++) {
				$buttonName = "Start$i"
				if( $StartButtons.ContainsKey($buttonName) ) {
					$StartButtons[$buttonName].Enabled = $false
				}
			}
			#Change this button's name to "Stop" and enable it
			$thisButtonName = "Start" + $thisModule
			if( $StartButtons.ContainsKey($thisButtonName) ) {
				$StartButtons[$thisButtonName].Text = "Stop"
			}

			$activeModule = $thisModule
			$statusBar1.Text = "Active module: $thisModule"

		} else {
			#how did we get here?
			$wshell = New-Object -ComObject Wscript.Shell
			$wshell.Popup("Attempting to go backwards!",0,"Oops!",0x1)
		}
	}
}#End DisablePrevious


########################################################################
## The function that displays the main UI
##
function DisplayModuleSwitcherForm {

	#Import the required Assemblies
	[reflection.assembly]::loadwithpartialname("System.Drawing") | Out-Null
	[reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null

	$moduleSwitcherForm = New-Object System.Windows.Forms.Form
			
	$InitialFormWindowState = New-Object System.Windows.Forms.FormWindowState
	
	
	#Example to display a Windows dialog (in case of errors)
	#	$wshell = New-Object -ComObject Wscript.Shell
	#	$wshell.Popup("Stop Module 4",0,"Cool!",0x1)

	########################################################################
	### Define the button events
	
	$mXStart_OnClick= 
	{
		# General on-click function... get module/button number here
		# from the calling button's Name
		$thisButton = [int](($this.Name).Split("_")[1])
		
		if( $thisButton -lt 10 ) { 
			$numModule = "0$thisButton"
		} else {
			$numModule = $thisButton
		}
		
		$buttonAction = ($this.Text).ToUpper()
		
		$ScriptPath = ($ModuleScripts | where { $_.Name -match "Module$numModule" | select -first 1 }).FullName

		#Write-Host "Testing $ScriptPath"
		try { 
			if( Test-Path $ScriptPath ) {
				Start-Process powershell -ArgumentList "-command $ScriptPath $buttonAction"
				DisablePrevious $thisButton
				if( $buttonAction -ne 'START' ) { 
					$buttonName = "Start$thisButton"
					if( $StartButtons.ContainsKey($buttonName) ) {
						$StartButtons[$buttonName].Enabled = $false
					}
					$statusBar1.Text = "No active module"
				}
			}
		}
		catch {
			$wshell = New-Object -ComObject Wscript.Shell
			$wshell.Popup("Error: Unable to Locate script $ScriptPath",0,"Dang!",0x1)
		}
	}
	
	$OnLoadForm_StateCorrection=
	{#Correct the initial state of the form to prevent the .Net maximized form issue
		$moduleSwitcherForm.WindowState = $InitialFormWindowState
	}
	
	########################################################################
	### Build the Form/Panel
	
	$moduleSwitcherForm.Text = "ModuleSwitcher Form"
	$moduleSwitcherForm.Name = "moduleSwitcherForm"
	$moduleSwitcherForm.DataBindings.DefaultDataSourceUpdateMode = 0
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $MainFormWidth
	$System_Drawing_Size.Height = $MainFormHeight
	$moduleSwitcherForm.ClientSize = $System_Drawing_Size
	
	########################################################################
	### Title Text @ Top of panel
	
	$label1 = New-Object System.Windows.Forms.Label
	$label1.TabIndex = 0
	$label1.TextAlign = 2
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $MainFormWidth - 10
	$System_Drawing_Size.Height = 30
	$label1.Size = $System_Drawing_Size
	$label1.Text = "Hands-on Labs Module Switcher"
	$label1.Font = New-Object System.Drawing.Font("Microsoft Sans Serif",12,1,3,0)
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = 10
	$System_Drawing_Point.Y = 10
	$label1.Location = $System_Drawing_Point
	$label1.DataBindings.DefaultDataSourceUpdateMode = 0
	$label1.Name = "label1"
	$moduleSwitcherForm.Controls.Add($label1)
	
	
	########################################################################
	### Status Bar @ Bottom of panel
	
	$statusBar1 = New-Object System.Windows.Forms.StatusBar
	$statusBar1.Name = "statusBar1"
	$statusBar1.Text = "Ready" #  pull LabStartup status into here for initial text
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $MainFormWidth
	$System_Drawing_Size.Height = 20
	$statusBar1.Size = $System_Drawing_Size
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = 0
	$System_Drawing_Point.Y = $MainFormHeight - 20 # subtract height of statusbar1 from form height
	$statusBar1.Location = $System_Drawing_Point
	$statusBar1.DataBindings.DefaultDataSourceUpdateMode = 0
	$statusBar1.TabIndex = 0
	$moduleSwitcherForm.Controls.Add($statusBar1)
	
	#Corner case - ModuleSwitchDir exists, but no matching scripts
	if( $numButtons -lt 1 ) { 
		$statusBar1.Text = "No ModuleSwitcher scripts found in $moduleswitchdir" 
	}

	### GroupBoxes and Buttons
	for( $i=2 ; $i -le ($numbuttons + 1) ; $i++ ) {
		Set-Variable "gbModule$i" -value $(New-Object System.Windows.Forms.GroupBox)
		Set-Variable $("m" + $i + "Start") -value $(New-Object System.Windows.Forms.Button)
		$StartButtons.Add( "Start$i",(Get-Variable $("m" + $i + "Start" )).Value )
		
		########################################################################
		### Module X Group Boxes and buttons
		
		(Get-Variable "gbModule$i").Value.Name = "gbModule$i"
		(Get-Variable "gbModule$i").Value.Text = "Module $i"
		
		$System_Drawing_Size = New-Object System.Drawing.Size
		$System_Drawing_Size.Width = $GROUP_WIDTH
		$System_Drawing_Size.Height = $GROUP_HEIGHT
		(Get-Variable "gbModule$i").Value.Size = $System_Drawing_Size
		
		$System_Drawing_Point = New-Object System.Drawing.Point
		$theX = ($i - 2) % $NUM_COLUMNS + 1
		$theY = [math]::floor( ($i - 2) / $NUM_COLUMNS ) + 1

		$System_Drawing_Point.X = (Get-Variable "col$theX").Value
		$System_Drawing_Point.Y = (Get-Variable "row$theY").Value
		
		(Get-Variable "gbModule$i").Value.Location = $System_Drawing_Point
		
		(Get-Variable "gbModule$i").Value.TabStop = $False
		(Get-Variable "gbModule$i").Value.TabIndex = 0
		(Get-Variable "gbModule$i").Value.DataBindings.DefaultDataSourceUpdateMode = 0
		
		(Get-Variable $("m" + $i + "Start")).Value.TabIndex = 1
		(Get-Variable $("m" + $i + "Start")).Value.Name = $("m_" + $i + "_Start")
		$System_Drawing_Size = New-Object System.Drawing.Size
		$System_Drawing_Size.Width = $BUTTON_WIDTH
		$System_Drawing_Size.Height = $BUTTON_HEIGHT
		(Get-Variable $("m" + $i + "Start")).Value.Size = $System_Drawing_Size
		(Get-Variable $("m" + $i + "Start")).Value.UseVisualStyleBackColor = $True
		
		(Get-Variable $("m" + $i + "Start")).Value.Text = "Start"
		
		$System_Drawing_Point = New-Object System.Drawing.Point
		$System_Drawing_Point.X = $BUTTON_OFFSET_X
		$System_Drawing_Point.Y = $BUTTON_OFFSET_Y
		(Get-Variable $("m" + $i + "Start")).Value.Location = $System_Drawing_Point
		(Get-Variable $("m" + $i + "Start")).Value.DataBindings.DefaultDataSourceUpdateMode = 0
		(Get-Variable $("m" + $i + "Start")).Value.add_Click($mXStart_OnClick)
		
		(Get-Variable "gbModule$i").Value.Controls.Add((Get-Variable ("m" + $i + "Start")).Value)
		$moduleSwitcherForm.Controls.Add((Get-Variable "gbModule$i").Value)
	}

########################################################################
		
	#Save the initial state of the form
	$InitialFormWindowState = $moduleSwitcherForm.WindowState
	#Init the OnLoad event to correct the initial state of the form
	$moduleSwitcherForm.add_Load($OnLoadForm_StateCorrection)
	#Show the Form
	$moduleSwitcherForm.ShowDialog()| Out-Null

} #End DisplayModuleSwitcherForm


#Call the Function
DisplayModuleSwitcherForm
