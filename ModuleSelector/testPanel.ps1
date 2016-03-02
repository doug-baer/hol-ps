<#

.SYNOPSIS			Module Switcher panel for HOL vPods.

.DESCRIPTION	

.NOTES				
							Version 0.1 - 01 March 2016
 
.EXAMPLE			.\testPanel.ps1

.INPUTS				Provide scripts with names like "Module02.ps1" in the $ModuleSwitchDir
							Note the two-digit value in the script names
							Each provided script should take two parameters: "START" and "STOP"

.OUTPUTS			Scripts are launched in their own PS console

#>

#$ModuleSwitchDir = 'C:\HOL\ModuleSwitcher'
$ModuleSwitchDir = 'E:\Temp\ModuleSwitcher'
if( Test-Path $ModuleSwitchDir ) {
	$ModuleScripts = Get-ChildItem -Path $ModuleSwitchDir -Filter 'Module*.ps1' | Sort
} else {
	Write-Host -ForegroundColor Red "ERROR - Unable to locate $ModuleSwitchDir"
	exit
}

# Initially, module 1 is the active module
$activeModule = 1

# Create a hashtable of Start buttons here
$StartButtons = @{}

$MainFormWidth = 450
$MainFormHeight = 500


########################################################################

Set-Variable BUTTON_WIDTH  -value 75 -option Constant
Set-Variable BUTTON_HEIGHT -value 25 -option Constant
Set-Variable GROUP_WIDTH   -value 85 -option Constant
Set-Variable GROUP_HEIGHT  -value 50 -option Constant

Set-Variable BUTTON_OFFSET_X -value 5 -option Constant
Set-Variable BUTTON_OFFSET_Y -value 20 -option Constant

Set-Variable row1 -value 50 -option Constant
Set-Variable row2 -value 120 -option Constant
Set-Variable row3 -value 190 -option Constant
Set-Variable row4 -value 260 -option Constant

Set-Variable col1 -value 10 -option Constant
Set-Variable col2 -value 105 -option Constant
Set-Variable col3 -value 200 -option Constant
Set-Variable col4 -value 295 -option Constant

########################################################################

function DisablePrevious { 
	PARAM ( [int]$thisModule )
	PROCESS {
		if( $thisModule -gt $activeModule ) {
			for($i=$activeModule; $i -le $thisModule; $i++) {
				$buttonName = "Start$i"
				if( $StartButtons.ContainsKey($buttonName) ) {
					$StartButtons[$buttonName].Enabled = $false
				}
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


##
## Display the main UI form
##
function DisplayModuleSwitcherForm {

	#Import the required Assemblies
	[reflection.assembly]::loadwithpartialname("System.Drawing") | Out-Null
	[reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null

	$moduleSwitcherForm = New-Object System.Windows.Forms.Form
	
	### GroupBoxes and Buttons
	
	$gbModule2 = New-Object System.Windows.Forms.GroupBox
	$m2Start = New-Object System.Windows.Forms.Button
	$StartButtons.add("Start2",$m2Start)
	
	$gbModule3 = New-Object System.Windows.Forms.GroupBox
	$m3Start = New-Object System.Windows.Forms.Button
	$StartButtons.add("Start3",$m3Start)
	
	$gbModule4 = New-Object System.Windows.Forms.GroupBox
	$m4Start = New-Object System.Windows.Forms.Button
	$StartButtons.add("Start4",$m4Start)
	
	$gbModule5 = New-Object System.Windows.Forms.GroupBox
	$m5Start = New-Object System.Windows.Forms.Button
	$StartButtons.add("Start5",$m5Start)
	
	$gbModule6 = New-Object System.Windows.Forms.GroupBox
	$m6Start = New-Object System.Windows.Forms.Button
	$StartButtons.add("Start6",$m6Start)
	
	$gbModule7 = New-Object System.Windows.Forms.GroupBox
	$m7Start = New-Object System.Windows.Forms.Button
	$StartButtons.add("Start7",$m7Start)
	
	$gbModule8 = New-Object System.Windows.Forms.GroupBox
	$m8Start = New-Object System.Windows.Forms.Button
	$StartButtons.add("Start8",$m8Start)
	
	$gbModule9 = New-Object System.Windows.Forms.GroupBox
	$m9Start = New-Object System.Windows.Forms.Button
	$StartButtons.add("Start9",$m9Start)
	
	$gbModule10 = New-Object System.Windows.Forms.GroupBox
	$m10Start = New-Object System.Windows.Forms.Button
	$StartButtons.add("Start10",$m10Start)
	
	$gbModule11 = New-Object System.Windows.Forms.GroupBox
	$m11Start = New-Object System.Windows.Forms.Button
	$StartButtons.add("Start11",$m11Start)
	
	$gbModule12 = New-Object System.Windows.Forms.GroupBox
	$m12Start = New-Object System.Windows.Forms.Button
	$StartButtons.add("Start12",$m12Start)
	
	$gbModule13 = New-Object System.Windows.Forms.GroupBox
	$m13Start = New-Object System.Windows.Forms.Button
	$StartButtons.add("Start13",$m13Start)
	
	$gbModule14 = New-Object System.Windows.Forms.GroupBox
	$m14Start = New-Object System.Windows.Forms.Button
	$StartButtons.add("Start14",$m14Start)
	
	
	########################################################################
	
	$statusBar1 = New-Object System.Windows.Forms.StatusBar
	
	$InitialFormWindowState = New-Object System.Windows.Forms.FormWindowState
	
	#endregion Generated Form Objects
	
	#----------------------------------------------
	#Event Script Blocks
	#----------------------------------------------
	
	#Example to display a dialog
	#	$wshell = New-Object -ComObject Wscript.Shell
	#	$wshell.Popup("Stop Module 4",0,"Cool!",0x1)
	
	$mXStart_OnClick= 
	{
		# General on-click function... need to set module/button number here
		# unless we can find it via the calling click
		$numButton = [int](($this.Name).Split("_")[1])
		
		if( $numButton -lt 10 ) { 
			$numModule = "0$numButton"
		} else {
			$numModule = $numButton
		}
		
		$ScriptPath = ($ModuleScripts | where { $_.Name -match "Module$numModule" | select -first 1 }).FullName
		if( Test-Path $ScriptPath ) {
			Start-Process powershell -ArgumentList "-command $ScriptPath 'START'"
			DisablePrevious $numButton
			$m2Start.Enabled = $false
		} else {
			$wshell = New-Object -ComObject Wscript.Shell
			$wshell.Popup("Error: Unable to Locate script $ScriptPath",0,"Dang!",0x1)
		}
	}	
	
	$OnLoadForm_StateCorrection=
	{#Correct the initial state of the form to prevent the .Net maximized form issue
		$moduleSwitcherForm.WindowState = $InitialFormWindowState
	}
	
	#----------------------------------------------
	
	$moduleSwitcherForm.Text = "ModuleSwitcher Form"
	$moduleSwitcherForm.Name = "moduleSwitcherForm"
	$moduleSwitcherForm.DataBindings.DefaultDataSourceUpdateMode = 0
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $MainFormWidth
	$System_Drawing_Size.Height = $MainFormHeight
	$moduleSwitcherForm.ClientSize = $System_Drawing_Size
	
	
	########################################################################
	### Status Bar @ Bottom of panel
	
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
	
	
	########################################################################
	### Module 2
	
	$gbModule2.Name = "gbModule2"
	$gbModule2.Text = "Module 2"
	
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $GROUP_WIDTH
	$System_Drawing_Size.Height = $GROUP_HEIGHT
	$gbModule2.Size = $System_Drawing_Size
	
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $col1
	$System_Drawing_Point.Y = $row1
	$gbModule2.Location = $System_Drawing_Point
	
	$gbModule2.TabStop = $False
	$gbModule2.TabIndex = 0
	$gbModule2.DataBindings.DefaultDataSourceUpdateMode = 0
	
	$m2Start.TabIndex = 1
	$m2Start.Name = "m_2_Start"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $BUTTON_WIDTH
	$System_Drawing_Size.Height = $BUTTON_HEIGHT
	$m2Start.Size = $System_Drawing_Size
	$m2Start.UseVisualStyleBackColor = $True
	
	$m2Start.Text = "Start"
	
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $BUTTON_OFFSET_X
	$System_Drawing_Point.Y = $BUTTON_OFFSET_Y
	$m2Start.Location = $System_Drawing_Point
	$m2Start.DataBindings.DefaultDataSourceUpdateMode = 0
	$m2Start.add_Click($mXStart_OnClick)
	
	$gbModule2.Controls.Add($m2Start)
	$moduleSwitcherForm.Controls.Add($gbModule2)
	
	
	########################################################################
	### Module 3
	
	$gbModule3.Name = "gbModule3"
	
	$gbModule3.Text = "Module 3"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $GROUP_WIDTH
	$System_Drawing_Size.Height = $GROUP_HEIGHT
	$gbModule3.Size = $System_Drawing_Size
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $col2
	$System_Drawing_Point.Y = $row1
	$gbModule3.Location = $System_Drawing_Point
	$gbModule3.TabStop = $False
	$gbModule3.TabIndex = 4
	$gbModule3.DataBindings.DefaultDataSourceUpdateMode = 0
	
	$m3Start.TabIndex = 5
	$m3Start.Name = "m_3_Start"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $BUTTON_WIDTH
	$System_Drawing_Size.Height = $BUTTON_HEIGHT
	$m3Start.Size = $System_Drawing_Size
	$m3Start.UseVisualStyleBackColor = $True
	
	$m3Start.Text = "Start"
	
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $BUTTON_OFFSET_X
	$System_Drawing_Point.Y = $BUTTON_OFFSET_Y
	$m3Start.Location = $System_Drawing_Point
	$m3Start.DataBindings.DefaultDataSourceUpdateMode = 0
	$m3Start.add_Click($mXStart_OnClick)
	
	$gbModule3.Controls.Add($m3Start)
	$moduleSwitcherForm.Controls.Add($gbModule3)
	
	
	########################################################################
	### Module 4 Group Box
	
	$gbModule4.Name = "gbModule4"
	$gbModule4.Text = "Module 4"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $GROUP_WIDTH
	$System_Drawing_Size.Height = $GROUP_HEIGHT
	$gbModule4.Size = $System_Drawing_Size
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $col3
	$System_Drawing_Point.Y = $row1
	$gbModule4.Location = $System_Drawing_Point
	$gbModule4.TabStop = $False
	$gbModule4.TabIndex = 7
	$gbModule4.DataBindings.DefaultDataSourceUpdateMode = 0
	
	
	$m4Start.TabIndex = 8
	$m4Start.Name = "m_4_Start"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $BUTTON_WIDTH
	$System_Drawing_Size.Height = $BUTTON_HEIGHT
	$m4Start.Size = $System_Drawing_Size
	$m4Start.UseVisualStyleBackColor = $True
	
	$m4Start.Text = "Start"
	
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $BUTTON_OFFSET_X
	$System_Drawing_Point.Y = $BUTTON_OFFSET_Y
	$m4Start.Location = $System_Drawing_Point
	$m4Start.DataBindings.DefaultDataSourceUpdateMode = 0
	$m4Start.add_Click($mXStart_OnClick)
	
	$gbModule4.Controls.Add($m4Start)
	$moduleSwitcherForm.Controls.Add($gbModule4)
	
	########################################################################
	### Module 5 Group Box
	
	$gbModule5.Name = "gbModule5"
	$gbModule5.Text = "Module 5"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $GROUP_WIDTH
	$System_Drawing_Size.Height = $GROUP_HEIGHT
	$gbModule5.Size = $System_Drawing_Size
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $col4
	$System_Drawing_Point.Y = $row1
	$gbModule5.Location = $System_Drawing_Point
	$gbModule5.TabStop = $False
	$gbModule5.TabIndex = 7
	$gbModule5.DataBindings.DefaultDataSourceUpdateMode = 0
	
	
	$m5Start.TabIndex = 8
	$m5Start.Name = "m_5_Start"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $BUTTON_WIDTH
	$System_Drawing_Size.Height = $BUTTON_HEIGHT
	$m5Start.Size = $System_Drawing_Size
	$m5Start.UseVisualStyleBackColor = $True
	
	$m5Start.Text = "Start"
	
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $BUTTON_OFFSET_X
	$System_Drawing_Point.Y = $BUTTON_OFFSET_Y
	$m5Start.Location = $System_Drawing_Point
	$m5Start.DataBindings.DefaultDataSourceUpdateMode = 0
	$m5Start.add_Click($mXStart_OnClick)
	
	$gbModule5.Controls.Add($m5Start)
	$moduleSwitcherForm.Controls.Add($gbModule5)
	
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
