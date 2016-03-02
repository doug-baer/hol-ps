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

$MainFormWidth = $col4 + $BUTTON_WIDTH + 20 # 390 for all
$MainFormHeight = $row4 + $BUTTON_HEIGHT + 50 # 335 for all

# the value of 20 is the offset from the edge
# the bottom gets an extra 30 for the height of the status bar + 10 extra


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
	
	$gbModule15 = New-Object System.Windows.Forms.GroupBox
	$m15Start = New-Object System.Windows.Forms.Button
	$StartButtons.add("Start15",$m15Start)
	
	$gbModule16 = New-Object System.Windows.Forms.GroupBox
	$m16Start = New-Object System.Windows.Forms.Button
	$StartButtons.add("Start16",$m16Start)
	
	$gbModule17 = New-Object System.Windows.Forms.GroupBox
	$m17Start = New-Object System.Windows.Forms.Button
	$StartButtons.add("Start17",$m17Start)


	
	
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
	### Module 6 Group Box
	
	$gbModule6.Name = "gbModule6"
	$gbModule6.Text = "Module 6"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $GROUP_WIDTH
	$System_Drawing_Size.Height = $GROUP_HEIGHT
	$gbModule6.Size = $System_Drawing_Size
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $col1
	$System_Drawing_Point.Y = $row2
	$gbModule6.Location = $System_Drawing_Point
	$gbModule6.TabStop = $False
	$gbModule6.TabIndex = 7
	$gbModule6.DataBindings.DefaultDataSourceUpdateMode = 0
	
	
	$m6Start.TabIndex = 8
	$m6Start.Name = "m_5_Start"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $BUTTON_WIDTH
	$System_Drawing_Size.Height = $BUTTON_HEIGHT
	$m6Start.Size = $System_Drawing_Size
	$m6Start.UseVisualStyleBackColor = $True
	
	$m6Start.Text = "Start"
	
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $BUTTON_OFFSET_X
	$System_Drawing_Point.Y = $BUTTON_OFFSET_Y
	$m6Start.Location = $System_Drawing_Point
	$m6Start.DataBindings.DefaultDataSourceUpdateMode = 0
	$m6Start.add_Click($mXStart_OnClick)
	
	$gbModule6.Controls.Add($m6Start)
	$moduleSwitcherForm.Controls.Add($gbModule6)
	
	########################################################################
	### Module 7 Group Box
	
	$gbModule7.Name = "gbModule7"
	$gbModule7.Text = "Module 7"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $GROUP_WIDTH
	$System_Drawing_Size.Height = $GROUP_HEIGHT
	$gbModule7.Size = $System_Drawing_Size
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $col2
	$System_Drawing_Point.Y = $row2
	$gbModule7.Location = $System_Drawing_Point
	$gbModule7.TabStop = $False
	$gbModule7.TabIndex = 0
	$gbModule7.DataBindings.DefaultDataSourceUpdateMode = 0
	
	
	$m7Start.TabIndex = 0
	$m7Start.Name = "m_7_Start"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $BUTTON_WIDTH
	$System_Drawing_Size.Height = $BUTTON_HEIGHT
	$m7Start.Size = $System_Drawing_Size
	$m7Start.UseVisualStyleBackColor = $True
	
	$m7Start.Text = "Start"
	
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $BUTTON_OFFSET_X
	$System_Drawing_Point.Y = $BUTTON_OFFSET_Y
	$m7Start.Location = $System_Drawing_Point
	$m7Start.DataBindings.DefaultDataSourceUpdateMode = 0
	$m7Start.add_Click($mXStart_OnClick)
	
	$gbModule7.Controls.Add($m7Start)
	$moduleSwitcherForm.Controls.Add($gbModule7)
	
	########################################################################


	########################################################################
	### Module 8 Group Box
	
	$gbModule8.Name = "gbModule8"
	$gbModule8.Text = "Module 8"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $GROUP_WIDTH
	$System_Drawing_Size.Height = $GROUP_HEIGHT
	$gbModule8.Size = $System_Drawing_Size
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $col3
	$System_Drawing_Point.Y = $row2
	$gbModule8.Location = $System_Drawing_Point
	$gbModule8.TabStop = $False
	$gbModule8.TabIndex = 0
	$gbModule8.DataBindings.DefaultDataSourceUpdateMode = 0
	
	
	$m8Start.TabIndex = 0
	$m8Start.Name = "m_8_Start"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $BUTTON_WIDTH
	$System_Drawing_Size.Height = $BUTTON_HEIGHT
	$m8Start.Size = $System_Drawing_Size
	$m8Start.UseVisualStyleBackColor = $True
	
	$m8Start.Text = "Start"
	
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $BUTTON_OFFSET_X
	$System_Drawing_Point.Y = $BUTTON_OFFSET_Y
	$m8Start.Location = $System_Drawing_Point
	$m8Start.DataBindings.DefaultDataSourceUpdateMode = 0
	$m8Start.add_Click($mXStart_OnClick)
	
	$gbModule8.Controls.Add($m8Start)
	$moduleSwitcherForm.Controls.Add($gbModule8)
	
	########################################################################

	########################################################################
	### Module 9 Group Box
	
	$gbModule9.Name = "gbModule9"
	$gbModule9.Text = "Module 9"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $GROUP_WIDTH
	$System_Drawing_Size.Height = $GROUP_HEIGHT
	$gbModule9.Size = $System_Drawing_Size
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $col4
	$System_Drawing_Point.Y = $row2
	$gbModule9.Location = $System_Drawing_Point
	$gbModule9.TabStop = $False
	$gbModule9.TabIndex = 0
	$gbModule9.DataBindings.DefaultDataSourceUpdateMode = 0
	
	
	$m9Start.TabIndex = 0
	$m9Start.Name = "m_9_Start"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $BUTTON_WIDTH
	$System_Drawing_Size.Height = $BUTTON_HEIGHT
	$m9Start.Size = $System_Drawing_Size
	$m9Start.UseVisualStyleBackColor = $True
	
	$m9Start.Text = "Start"
	
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $BUTTON_OFFSET_X
	$System_Drawing_Point.Y = $BUTTON_OFFSET_Y
	$m9Start.Location = $System_Drawing_Point
	$m9Start.DataBindings.DefaultDataSourceUpdateMode = 0
	$m9Start.add_Click($mXStart_OnClick)
	
	$gbModule9.Controls.Add($m9Start)
	$moduleSwitcherForm.Controls.Add($gbModule9)
	
	########################################################################

	########################################################################
	### Module 10 Group Box
	
	$gbModule10.Name = "gbModule10"
	$gbModule10.Text = "Module 10"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $GROUP_WIDTH
	$System_Drawing_Size.Height = $GROUP_HEIGHT
	$gbModule10.Size = $System_Drawing_Size
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $col1
	$System_Drawing_Point.Y = $row3
	$gbModule10.Location = $System_Drawing_Point
	$gbModule10.TabStop = $False
	$gbModule10.TabIndex = 0
	$gbModule10.DataBindings.DefaultDataSourceUpdateMode = 0
	
	
	$m10Start.TabIndex = 0
	$m10Start.Name = "m_10_Start"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $BUTTON_WIDTH
	$System_Drawing_Size.Height = $BUTTON_HEIGHT
	$m10Start.Size = $System_Drawing_Size
	$m10Start.UseVisualStyleBackColor = $True
	
	$m10Start.Text = "Start"
	
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $BUTTON_OFFSET_X
	$System_Drawing_Point.Y = $BUTTON_OFFSET_Y
	$m10Start.Location = $System_Drawing_Point
	$m10Start.DataBindings.DefaultDataSourceUpdateMode = 0
	$m10Start.add_Click($mXStart_OnClick)
	
	$gbModule10.Controls.Add($m10Start)
	$moduleSwitcherForm.Controls.Add($gbModule10)
	
	########################################################################

	########################################################################
	### Module 11 Group Box
	
	$gbModule11.Name = "gbModule11"
	$gbModule11.Text = "Module 11"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $GROUP_WIDTH
	$System_Drawing_Size.Height = $GROUP_HEIGHT
	$gbModule11.Size = $System_Drawing_Size
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $col2
	$System_Drawing_Point.Y = $row3
	$gbModule11.Location = $System_Drawing_Point
	$gbModule11.TabStop = $False
	$gbModule11.TabIndex = 0
	$gbModule11.DataBindings.DefaultDataSourceUpdateMode = 0
	
	
	$m11Start.TabIndex = 0
	$m11Start.Name = "m_11_Start"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $BUTTON_WIDTH
	$System_Drawing_Size.Height = $BUTTON_HEIGHT
	$m11Start.Size = $System_Drawing_Size
	$m11Start.UseVisualStyleBackColor = $True
	
	$m11Start.Text = "Start"
	
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $BUTTON_OFFSET_X
	$System_Drawing_Point.Y = $BUTTON_OFFSET_Y
	$m11Start.Location = $System_Drawing_Point
	$m11Start.DataBindings.DefaultDataSourceUpdateMode = 0
	$m11Start.add_Click($mXStart_OnClick)
	
	$gbModule11.Controls.Add($m11Start)
	$moduleSwitcherForm.Controls.Add($gbModule11)
	
	########################################################################

	########################################################################
	### Module 12 Group Box
	
	$gbModule12.Name = "gbModule12"
	$gbModule12.Text = "Module 12"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $GROUP_WIDTH
	$System_Drawing_Size.Height = $GROUP_HEIGHT
	$gbModule12.Size = $System_Drawing_Size
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $col3
	$System_Drawing_Point.Y = $row3
	$gbModule12.Location = $System_Drawing_Point
	$gbModule12.TabStop = $False
	$gbModule12.TabIndex = 0
	$gbModule12.DataBindings.DefaultDataSourceUpdateMode = 0
	
	
	$m12Start.TabIndex = 0
	$m12Start.Name = "m_12_Start"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $BUTTON_WIDTH
	$System_Drawing_Size.Height = $BUTTON_HEIGHT
	$m12Start.Size = $System_Drawing_Size
	$m12Start.UseVisualStyleBackColor = $True
	
	$m12Start.Text = "Start"
	
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $BUTTON_OFFSET_X
	$System_Drawing_Point.Y = $BUTTON_OFFSET_Y
	$m12Start.Location = $System_Drawing_Point
	$m12Start.DataBindings.DefaultDataSourceUpdateMode = 0
	$m12Start.add_Click($mXStart_OnClick)
	
	$gbModule12.Controls.Add($m12Start)
	$moduleSwitcherForm.Controls.Add($gbModule12)
	
	########################################################################

	########################################################################
	### Module 13 Group Box
	
	$gbModule13.Name = "gbModule13"
	$gbModule13.Text = "Module 13"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $GROUP_WIDTH
	$System_Drawing_Size.Height = $GROUP_HEIGHT
	$gbModule13.Size = $System_Drawing_Size
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $col4
	$System_Drawing_Point.Y = $row3
	$gbModule13.Location = $System_Drawing_Point
	$gbModule13.TabStop = $False
	$gbModule13.TabIndex = 0
	$gbModule13.DataBindings.DefaultDataSourceUpdateMode = 0
	
	
	$m13Start.TabIndex = 0
	$m13Start.Name = "m_13_Start"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $BUTTON_WIDTH
	$System_Drawing_Size.Height = $BUTTON_HEIGHT
	$m13Start.Size = $System_Drawing_Size
	$m13Start.UseVisualStyleBackColor = $True
	
	$m13Start.Text = "Start"
	
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $BUTTON_OFFSET_X
	$System_Drawing_Point.Y = $BUTTON_OFFSET_Y
	$m13Start.Location = $System_Drawing_Point
	$m13Start.DataBindings.DefaultDataSourceUpdateMode = 0
	$m13Start.add_Click($mXStart_OnClick)
	
	$gbModule13.Controls.Add($m13Start)
	$moduleSwitcherForm.Controls.Add($gbModule13)
	
	########################################################################

	########################################################################
	### Module 14 Group Box
	
	$gbModule14.Name = "gbModule14"
	$gbModule14.Text = "Module 14"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $GROUP_WIDTH
	$System_Drawing_Size.Height = $GROUP_HEIGHT
	$gbModule14.Size = $System_Drawing_Size
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $col1
	$System_Drawing_Point.Y = $row4
	$gbModule14.Location = $System_Drawing_Point
	$gbModule14.TabStop = $False
	$gbModule14.TabIndex = 0
	$gbModule14.DataBindings.DefaultDataSourceUpdateMode = 0
	
	
	$m14Start.TabIndex = 0
	$m14Start.Name = "m_14_Start"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $BUTTON_WIDTH
	$System_Drawing_Size.Height = $BUTTON_HEIGHT
	$m14Start.Size = $System_Drawing_Size
	$m14Start.UseVisualStyleBackColor = $True
	
	$m14Start.Text = "Start"
	
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $BUTTON_OFFSET_X
	$System_Drawing_Point.Y = $BUTTON_OFFSET_Y
	$m14Start.Location = $System_Drawing_Point
	$m14Start.DataBindings.DefaultDataSourceUpdateMode = 0
	$m14Start.add_Click($mXStart_OnClick)
	
	$gbModule14.Controls.Add($m14Start)
	$moduleSwitcherForm.Controls.Add($gbModule14)
	
	########################################################################

	########################################################################
	### Module 15 Group Box
	
	$gbModule15.Name = "gbModule15"
	$gbModule15.Text = "Module 15"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $GROUP_WIDTH
	$System_Drawing_Size.Height = $GROUP_HEIGHT
	$gbModule15.Size = $System_Drawing_Size
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $col2
	$System_Drawing_Point.Y = $row4
	$gbModule15.Location = $System_Drawing_Point
	$gbModule15.TabStop = $False
	$gbModule15.TabIndex = 0
	$gbModule15.DataBindings.DefaultDataSourceUpdateMode = 0
	
	
	$m15Start.TabIndex = 0
	$m15Start.Name = "m_15_Start"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $BUTTON_WIDTH
	$System_Drawing_Size.Height = $BUTTON_HEIGHT
	$m15Start.Size = $System_Drawing_Size
	$m15Start.UseVisualStyleBackColor = $True
	
	$m15Start.Text = "Start"
	
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $BUTTON_OFFSET_X
	$System_Drawing_Point.Y = $BUTTON_OFFSET_Y
	$m15Start.Location = $System_Drawing_Point
	$m15Start.DataBindings.DefaultDataSourceUpdateMode = 0
	$m15Start.add_Click($mXStart_OnClick)
	
	$gbModule15.Controls.Add($m15Start)
	$moduleSwitcherForm.Controls.Add($gbModule15)

	########################################################################
	### Module 16 Group Box
	
	$gbModule16.Name = "gbModule16"
	$gbModule16.Text = "Module 16"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $GROUP_WIDTH
	$System_Drawing_Size.Height = $GROUP_HEIGHT
	$gbModule16.Size = $System_Drawing_Size
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $col3
	$System_Drawing_Point.Y = $row4
	$gbModule16.Location = $System_Drawing_Point
	$gbModule16.TabStop = $False
	$gbModule16.TabIndex = 0
	$gbModule16.DataBindings.DefaultDataSourceUpdateMode = 0
	
	
	$m16Start.TabIndex = 0
	$m16Start.Name = "m_16_Start"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $BUTTON_WIDTH
	$System_Drawing_Size.Height = $BUTTON_HEIGHT
	$m16Start.Size = $System_Drawing_Size
	$m16Start.UseVisualStyleBackColor = $True
	
	$m16Start.Text = "Start"
	
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $BUTTON_OFFSET_X
	$System_Drawing_Point.Y = $BUTTON_OFFSET_Y
	$m16Start.Location = $System_Drawing_Point
	$m16Start.DataBindings.DefaultDataSourceUpdateMode = 0
	$m16Start.add_Click($mXStart_OnClick)
	
	$gbModule16.Controls.Add($m16Start)
	$moduleSwitcherForm.Controls.Add($gbModule16)
	
	########################################################################

	########################################################################
	### Module 17 Group Box
	
	$gbModule17.Name = "gbModule17"
	$gbModule17.Text = "Module 17"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $GROUP_WIDTH
	$System_Drawing_Size.Height = $GROUP_HEIGHT
	$gbModule17.Size = $System_Drawing_Size
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $col4
	$System_Drawing_Point.Y = $row4
	$gbModule17.Location = $System_Drawing_Point
	$gbModule17.TabStop = $False
	$gbModule17.TabIndex = 0
	$gbModule17.DataBindings.DefaultDataSourceUpdateMode = 0
	
	
	$m17Start.TabIndex = 0
	$m17Start.Name = "m_17_Start"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = $BUTTON_WIDTH
	$System_Drawing_Size.Height = $BUTTON_HEIGHT
	$m17Start.Size = $System_Drawing_Size
	$m17Start.UseVisualStyleBackColor = $True
	
	$m17Start.Text = "Start"
	
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = $BUTTON_OFFSET_X
	$System_Drawing_Point.Y = $BUTTON_OFFSET_Y
	$m17Start.Location = $System_Drawing_Point
	$m17Start.DataBindings.DefaultDataSourceUpdateMode = 0
	$m17Start.add_Click($mXStart_OnClick)
	
	$gbModule17.Controls.Add($m17Start)
	$moduleSwitcherForm.Controls.Add($gbModule17)
	
	########################################################################


	########################################################################
	########################################################################
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
