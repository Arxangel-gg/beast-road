' Beast Road Update Manager - launcher with no console window.
'
' cmd.exe always creates a console, so a .bat can never start a windowed app
' without one flashing up behind it. WScript.Shell.Run with a window style of 0
' starts PowerShell genuinely hidden, and the WinForms window is then the only
' thing on screen - which is what it should have been all along.
'
' Double-click this rather than the .bat.

Dim shell, here
Set shell = CreateObject("WScript.Shell")
here = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
shell.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & here & "publish.ps1""", 0, False
