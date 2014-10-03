<#
.NOTES
  Name:     Sync-VPod-Pull
  Author:   Doug Baer
  Version:  2.0b4
  Date:     2014-07-29

.SYNOPSIS
  Efficiently synchronize two OVF exports between sites using specified local data as the seed.

.DESCRIPTION
  Handles preprocessing tasks and calls rsync to perform replication
  
  Requires SSH connectivity to main CATALOG/LIBRARY system to pull latest version.

.PARAMETER
  CATALOGHOST - the name of the CATALOG host containing the new version of the vPod 
    default = "HOL-DEV-CATALOG"

.PARAMETER
  REMOTELIB - the path to the new files on the CATALOGHOST, not including NEWNAME
    default = "/cygdrive/e/HOL-Library"

.PARAMETER
  OLDNAME - the name of the local SEED vPod 

.PARAMETER
  NEWNAME - the name of the new vPod (the version in REMOTELIB)

.PARAMETER
  LOCALSEED - the local path to the SEED files, not including OLDNAME
    default = "E:\Seeds"

.PARAMETER
  LOCALLIB - the path to the local LIBRARY files, not including NEWNAME
    default = "E:\HOL_Library"

.PARAMETER
  SSHUSER - the user account used for SSH connection to CATALOGHOST
    default = "catalog"

.PARAMETER
  OUTPUTPATH - path to the log file (optional)
    default = "E:\LabMaps"

.EXAMPLE - using defaults
Sync-vPod-Pull.ps1 -OldName HOL-SDC-1400-v1 -NewName HOL-SDC-1400-v2

.EXAMPLE
Sync-vPod-Pull.ps1 -OldName HOL-SDC-1400-v1 -NewName HOL-SDC-1400-v2 -CatalogHost HOL-DEV-CATALOG -RemoteLib /cygdrive/e/HOL-Library  -LocalSeed E:\Seeds\ -LocalLib E:\HOL-Library -SSHuser catalog -OutputPath E:\LabMaps

.CHANGELOG
  2.0b2 - Added defaults for all parameters but OldName and NewName
  2.0b4 - Removed extraneous "/" from ovfFileRemoteEsc

#>

[CmdletBinding()]
param(
  [Parameter(Position=0,Mandatory=$false,HelpMessage="Name of the catalog host",
  ValueFromPipeline=$False)]
  [System.String]$CatalogHost = "HOL-DEV-CATALOG",

  [Parameter(Position=1,Mandatory=$true,HelpMessage="Seed vApp Name (target)",
  ValueFromPipeline=$False)]
  [System.String]$OldName,

  [Parameter(Position=2,Mandatory=$true,HelpMessage="New vApp Name (source)",
  ValueFromPipeline=$False)]
  [System.String]$NewName,

  [Parameter(Position=3,Mandatory=$false,HelpMessage="SSH path to the source files (remote)",
  ValueFromPipeline=$False)]
  [System.String]$RemoteLib = '/cygdrive/e/HOL-Library',

  [Parameter(Position=4,Mandatory=$false,HelpMessage="Path to the seed files (local)",
  ValueFromPipeline=$False)]
  [System.String]$LocalSeed = 'E:\Seeds',

  [Parameter(Position=4,Mandatory=$false,HelpMessage="Path to the library files (local)",
  ValueFromPipeline=$False)]
  [System.String]$LocalLib = 'E:\HOL-Library',

  [Parameter(Position=4,Mandatory=$false,HelpMessage="Path to the library files (local)",
  ValueFromPipeline=$False)]
  [System.String]$SSHuser = "catalog",

  [Parameter(Position=5,Mandatory=$false,HelpMessage="Path to output files",
  ValueFromPipeline=$False)]
  [System.String]$OutputPath = 'E:\LabMaps'
)

###############################################################################
BEGIN {
  Write-Host "=*=*=*=* Sync-VPod-Pull $NewName Start $(Get-Date) *=*=*=*="
  
  $debug = $false
  
  If ($debug) { Write-Host -Fore Yellow " ### DEBUG MODE IS ON ### " }

  try { 
    if( Test-Path $OutputPath ) {
      $createFile = $true
      $fileName = $(Join-Path $OutputPath $($NewName.Replace(" ",""))) + ".txt"
      "#### STARTING $(Get-Date)" | Out-File $fileName -Append
    }
  }
  catch {
    Write-Host -Fore Yellow "Output path does not exist: logging disabled."
    $createFile = $false
  }
  
  ### Setup the SSH options we need (cygwin)
  $sshComputer = $CatalogHost
  #$sshUser = "catalog"
  #$sshKey = "/home/catalog/.ssh/id_dsa"
  #$sshOptions = "-i $sshKey "
  $sshOptions = " "

  # prepend "/cygdrive/", lowercase drive letter, flip slashes, escape spaces
  function cygwinPath( $thePath ) {
    $x = $thePath.Split(":")
    Return "/cygdrive/" + ($x[0]).toLower() + $(($x[1]).Replace("\","/").Replace(" ","\ "))
  }

  # sometimes, there aren't enough slashes...
  function doubleEscapePathSpaces( $thePath ) {
    Return $thePath.Replace(" ","\\ ")
  }
  
  ## cygwin version: generic command execution over SSH
  function exec-ssh( $cmd1 ) {
    $remoteCommand = '"' + $cmd1 + '"'
    $command = "ssh " + $sshOptions + " " + $SSHuser + "@" + $sshComputer + " " + $remoteCommand
    if( $debug ) { Write-Host "EXEC-SSH:" $command }
    if( $createFile ) { 
      $command | Out-File $fileName -Append 
    } else {
      Invoke-Expression -command $command 
    }
  }

  function Add-TrailingCharacter( $myPath, $myChar ) {
    if( $myPath[-1] -ne $myChar ) { return $myPath += $myChar }
    else { return $myPath }
  }

  # Do any cleanup we need to do before bailing
  function CleanupAndExit {
    if( $debug ) { Write-Host "CleanupAndExit" }    
    Exit
  }

  #cleanup (and validate?) the path inputs
  $LocalSeed = Add-TrailingCharacter $LocalSeed "\"
  $LocalLib = Add-TrailingCharacter $LocalLib "\"
  $RemoteLib = Add-TrailingCharacter $RemoteLib "/"
  
  #generate cygwin versions of the local LIBRARY and SEED paths
  $localLibPathC = cygwinPath $LocalLib
  $localSeedPathC = cygwinPath $LocalSeed
  
  if( -not (Test-Path $LocalSeed) ) {
    Write-Host -Fore Red "Error: path to SEED does not exist"
    #another option here is to switch to LFTP for the trapsport if the seed is missing
    CleanupAndExit
  }
  
  #check to make sure cygwin is there
  # C:\cygwin64\bin\bash.exe
}

###############################################################################
PROCESS {
  
  #Make new local directory to contain new vPod
  $newVPodPath = Join-Path $LocalLib $NewName
  if( -not (Test-Path $newVPodPath) ) {
    mkdir $newVPodPath
  } else {
    Write-Host -Fore Red "Error: Target Path exists: $newVPodPath"
    if( $createFile ) {
      "Error: Target Path exists: $newVPodPath" | Out-File $fileName -append
    } 
    CleanupAndExit
  }

  ## obtain the new OVF if not already present
  $newOvfPath = Join-Path $newVPodPath $($NewName + ".ovf")
  
  if( -not (Test-Path $newOvfPath) ) {
    # sanity check: we just created this directory, so OVF should not be here
    ## GO GET IT VIA SSH -- EVEN IN DEBUG MODE
    $ovfFileRemoteEsc = doubleEscapePathSpaces $($RemoteLib + $NewName + "/" + $NewName + ".ovf")
    $newOvfPathC = cygwinPath $newOvfPath
    $command = "C:\cygwin64\bin\bash.exe --login -c 'scp "+ $sshOptions + $SSHuser + "@" + $sshComputer + ':"' + $ovfFileRemoteEsc + '" "' + $newOvfPathC +'"' +"'"

    if( $debug ) { Write-Host $command }
    if( $createFile ) { $command | Out-File $fileName -append } 

    Write-Host "Getting new OVF via SCP..."
    Invoke-Expression -command $command 
  }

  ## second check -- see if we successfully downloaded it
  if( -not (Test-Path $newOvfPath) ) {
    Write-Host -Fore Red "Error: Unable to read new OVF @ $newOvfPath"
    CleanupAndExit
  }
 
  #here, we have a copy of the new OVF in the new location
  [xml]$new = Get-Content $newOvfPath
  $newfiles = $new.Envelope.References.File
  $newvAppName = $new.Envelope.VirtualSystemCollection.Name 

  #Map the filenames to the OVF IDs in a hash table by diskID within the OVF
  $newVmdks = @{}
  foreach ($disk in $new.Envelope.References.File) {
    $diskID = ($disk.ID).Remove(0,5)
    $newVmdks.Add($diskID,$disk.href)
  }
  
  #### Read the SEED OVF
  $oldOvfPath = Join-Path $LocalSeed $(Join-Path $OldName $($OldName + ".ovf"))

  #ensure the file exists... 
  if( -not (Test-Path $oldOvfPath) ) {
    Write-Host -Fore Red "Error: unable to read seed OVF"
    CleanupAndExit
  }
  
  [xml]$old = Get-Content $oldOvfPath
  $oldfiles = $old.Envelope.References.File
  $oldvAppName = $old.Envelope.VirtualSystemCollection.Name

  #Map the VMDK file names to the OVF IDs in a hash table by diskID within the OVF
  $oldVmdks = @{}
  foreach ($disk in $old.Envelope.References.File) {
    $diskID = ($disk.ID).Remove(0,5)
    $oldVmdks.Add($diskID,$disk.href)
  }
  
  ## Match the OLD VMs and their files (uses $oldVmdks to resolve)
  $oldVms = @()
  $oldVms = $old.Envelope.VirtualSystemCollection.VirtualSystem
  $oldDiskMap = @{}
  
  foreach ($vm in $oldVms) {
    #special case for vPOD router VM -- it has a version number and blows up when renamed
    if( $vm.name -like "vpodrouter*" ) {
      $oldDiskMap.Add("vpodrouter",@{})
    } else {
      $oldDiskMap.Add($vm.name,@{})
    }

    $disks = ($vm.VirtualHardwareSection.Item | Where {$_.description -like "Hard disk*"} | Sort -Property AddressOnParent)
    $i = 0
    foreach ($disk in $disks) {
      $parentDisks = @($Disks)
      $diskName = $parentDisks[$i].ElementName
      $i++
      $ref = ($disk.HostResource."#text")
      $ref = $ref.Remove(0,$ref.IndexOf("-") + 1)
      if ($vm.name -like "vpodrouter*") {
        ($oldDiskMap["vpodrouter"]).Add($diskName,$oldVmdks[$ref])
      } 
      else {
        ($oldDiskMap[$vm.name]).Add($diskName,$oldVmdks[$ref])
      }
    }
  }
  
  ## Match the NEW VMs and their files (uses $oldVmdks to resolve)
  $newVms = @()
  $newVms = $new.Envelope.VirtualSystemCollection.VirtualSystem
  $newDiskMap = @{}
  
  foreach ($vm in $newVms) {
    #special case for vPOD router VM -- it gets a version number
    if( $vm.name -like "vpodrouter*" ) {
      $newDiskMap.Add("vpodrouter",@{})
    } 
    else {
      $newDiskMap.Add($vm.name,@{})
    }

    $disks = ($vm.VirtualHardwareSection.Item | Where {$_.description -like "Hard disk*"} | Sort -Property AddressOnParent)
    $i = 0
    foreach ($disk in $disks) {
      $parentDisks = @($Disks)
      $diskName = $parentDisks[$i].ElementName
      $i++
      $ref = ($disk.HostResource."#text") #Powershell or OVF version dependent?
      $ref = $ref.Remove(0,$ref.IndexOf("-") + 1)
      if ($vm.name -like "vpodrouter*") {
        ($newDiskMap["vpodrouter"]).Add($diskName,$newVmdks[$ref])
      } 
      else {
        ($newDiskMap[$vm.name]).Add($diskName,$newVmdks[$ref])
      }
    }
  }

###############################################################################

  # Walk through the NEW disk map, create a hash table of the file mappings 
  #  keys are FROM filenames and values are TO filenames
  Write-Host "`n=====>Begin VMDK Map and Move"
  foreach ($key in $newDiskMap.Keys) {
    #look up the NEW host (by name) in $oldDiskMap 
    foreach ($key2 in ($newDiskMap[$key]).Keys) { 
      #enumerate the disks per VM :"Hard disk #"
      #ensure ($oldDiskMap[$key])[$key2] exists prior to continuing
      $oldFileExists = $false
      if( $oldDiskMap.ContainsKey($key) ) {
        if( ($oldDiskMap[$key]).ContainsKey($key2) ) {
          $str1 = "  OLD " + $key2 + "->" + ($oldDiskMap[$key])[$key2]
          $oldFileExists = $true
        } 
        else {
          $str1 = "  NO MATCH for $key2 @ $key : new disk on VM"      
        }
      } 
      else {
        $str1 = "  NO MATCH for $key : net new VM"
      }
      $str2 = "  NEW " + $key2 + "->" + ($newDiskMap[$key])[$key2]
      Write "`n==> HOST: $key"
      Write $str1
      Write $str2
      #Rename the target files (seeds) to match the source's
      # SPACES _SUCK_
      #ssh needs whole command double-quoted and path-spaces double-escaped:
      #  ssh user@target "mv /cygdrive/.../path\\ with\\ spaces /cygdrive/.../path\\ with\\ more\\ spaces"

      $newPathEsc = doubleEscapePathSpaces $($localLibPathC + $newvAppName + "/" + ($newDiskMap[$key])[$key2])
      if( $oldFileExists ) {
        $oldPathEsc = doubleEscapePathSpaces $($localSeedPathC + $oldvAppName + "/" + ($oldDiskMap[$key])[$key2])
        $command = "C:\cygwin64\bin\bash.exe --login -c 'mv " + $oldPathEsc + " " + $newPathEsc + "'"
        Write-Host -Fore Yellow "  MOVE VMDK FILE: $command"
        if( $createFile ) { $command | Out-File $fileName -Append }
        if ( !($debug) ) { Invoke-Expression -command $command }
        $command = $null
      }
    }
  }
  Write-Host "`n=====>End VMDK Map and Move"

###############################################################################

  Write-Host "`n=====>Begin file sync:"
  
  ## When we get here, the SEED files have been matched and renamed to the same 
  ##  names as the matching files and relocated to the local LIBRARY 
  ##  in preparation for the rsync call

  # In rsync, the '-a' does weird things with Windows permissions for
  # non-admin users... use '-tr' instead
  #  EXAMPLE rsync -tvhPr --stats user@remote:/SOURCE/ /cygdrive/c/LOCAL_TARGET
  
  if( $debug ) { 
    #the -n performs the "dry run" analysis
    $rsyncOpts = "-tvhPrn --stats --delete --max-delete=3" 
  } 
  else { 
    # BEWARE: this is a "real" rsync .. can delete things!
    $rsyncOpts = "-tvhPr --stats --delete --max-delete=3" 
  }

  #rsync needs SSH path to be double-quoted AND double-escaped:
  #  user@target:"/cygdrive/.../path\\ with\\ spaces"
  $remotePathRsync = $RemoteLib + $newvAppName
#  $remotePathRsyncEsc = $remotePathRsync.Replace(" ","\ ")
  $remotePathRsyncEsc = doubleEscapePathSpaces $remotePathRsync

  #rsync needs local path to be escaped
  #  /cygdrive/.../path\ with\ spaces/
  # [05/22/2013-DB .. what about using -s option to rsync? need to test]
#  $targetPathRsyncEsc = doubleEscapePathSpaces $($TargetPath + $newvAppName)
  $targetPathRsyncEsc = $($localLibPathC + $newvAppName).Replace(" ","\ ")
  
  $syncCmd = "rsync $rsyncOpts " + $SSHuser + "@"  + $sshComputer + ':"' + $remotePathRsyncEsc + '/" "' + $targetPathRsyncEsc + '"'

  $command = "C:\cygwin64\bin\bash.exe --login -c " + "'" + $syncCmd + "'"

  if( $debug ) { Write-Host "REPLICATE:" $command }
  if( $createFile ) { $syncCmd | Out-File $fileName -Append }
  
  #Pull the ripcord!
  Invoke-Expression -command $command 
  
  # Remove old Seed directory (clean up)
  #  arbitrary value of >5 files remaining to limit exposure of accidental deletion

  if( $OldName -ne "" ) {
    $oldSeedDir = Get-Item $(Join-Path $LocalSeed $OldName)
    $count = 0
    $oldSeedDir.EnumerateFiles() | % {$count +=1}
    $oldSeedDir.EnumerateDirectories() | % {$count +=10}
    if( $count -lt 5 ) {
      Write-Host "Removing SEED directory $($oldSeedDir.FullName)"
      if( !($debug) ) { Remove-Item $oldSeedDir -Recurse -Confirm:$false }
    }
    else {
      $msg = "`nWARNING!! files remaining in SEED directory: $($oldSeedDir.FullName)"
      Write-Host -Fore Red $msg
      if( $createFile ) { $msg | Out-File $fileName -Append }
    }
  }
}

###############################################################################
END {
  Write-Host "`n=*=*=*=*=* Sync-VPod-Pull $NewName End $(Get-Date) *=*=*=*=*="
  if ($createfile) { "#### COMPLETED $(Get-Date)" | Out-File $fileName -Append }
}