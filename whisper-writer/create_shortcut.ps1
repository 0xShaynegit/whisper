$WshShell = New-Object -ComObject WScript.Shell
$Desktop = [Environment]::GetFolderPath('Desktop')
$Shortcut = $WshShell.CreateShortcut("$Desktop\WhisperWriter.lnk")
$Shortcut.TargetPath = "C:\whisper\whisper-writer\start.bat"
$Shortcut.WorkingDirectory = "C:\whisper\whisper-writer"
$Shortcut.Save()
Write-Host "Shortcut created on Desktop!"
