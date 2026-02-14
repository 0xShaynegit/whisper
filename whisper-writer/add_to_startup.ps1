$WshShell = New-Object -ComObject WScript.Shell
$Startup = [Environment]::GetFolderPath('Startup')
$Shortcut = $WshShell.CreateShortcut("$Startup\WhisperWriter.lnk")
$Shortcut.TargetPath = "C:\whisper\whisper-writer\start.bat"
$Shortcut.WorkingDirectory = "C:\whisper\whisper-writer"
$Shortcut.Save()
Write-Host "WhisperWriter added to Windows Startup!"
