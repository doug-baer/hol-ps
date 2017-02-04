@echo off
REM echo Not Ready > C:\hol\startup_status.txt
C:\WINDOWS\system32\windowspowershell\v1.0\powershell.exe -windowstyle hidden "& 'c:\hol\labStartup.ps1' labcheck" >C:\hol\labStartup.log

