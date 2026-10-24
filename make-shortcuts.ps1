# QQBot desktop shortcuts builder.
# Creates 4 .lnk shortcuts on the Desktop. ASCII-only + UTF-8 BOM on purpose
# (Windows PowerShell 5.1 mis-parses non-ASCII files without BOM).

$ErrorActionPreference = 'Stop'
$desktop = [Environment]::GetFolderPath('Desktop')
$target = 'powershell.exe'
$root = 'D:\ds\qqbot'

function New-Shortcut {
    param(
        [string]$Name,
        [string]$Script,
        [string]$Description
    )
    $path = Join-Path $desktop $Name
    $shell = New-Object -ComObject WScript.Shell
    $sc = $shell.CreateShortcut($path)
    $sc.TargetPath = $target
    $sc.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $Script + '"'
    $sc.WorkingDirectory = $root
    $sc.IconLocation = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe,0'
    $sc.Description = $Description
    $sc.Save()
    Write-Host ('created: ' + $path)
}

New-Shortcut -Name 'QQ Bot - Start.lnk'   -Script (Join-Path $root 'start.ps1')   -Description 'Start the QQ bot (shows a console window; closing it stops the bot)'
New-Shortcut -Name 'QQ Bot - Stop.lnk'    -Script (Join-Path $root 'stop.ps1')    -Description 'Stop the QQ bot process'
New-Shortcut -Name 'QQ Bot - Status.lnk'  -Script (Join-Path $root 'status.ps1')  -Description 'Show whether the bot and gateway are running'
New-Shortcut -Name 'QQ Bot - Persona.lnk' -Script (Join-Path $root 'edit-persona.ps1') -Description 'Open agent/AGENTS.md (the personality prompt) in Notepad'

Write-Host ''
Write-Host 'Done. Four shortcuts are now on the Desktop.'
