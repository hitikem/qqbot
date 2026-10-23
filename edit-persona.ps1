# Open the bot personality prompt (agent/AGENTS.md) in Notepad.
# Save in Notepad, then the next QQ message uses the new personality.
# ASCII-only + UTF-8 BOM on purpose (Windows PowerShell 5.1 mis-parses non-ASCII without BOM).

$file = 'D:\ds\qqbot\agent\AGENTS.md'
if (-not (Test-Path $file)) {
    Write-Host ('File not found: ' + $file) -ForegroundColor Red
    Write-Host 'Press any key to close...'
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    return
}

Write-Host 'Opening the personality file:' -ForegroundColor Cyan
Write-Host ('  ' + $file)
Write-Host ''
Write-Host 'Replace everything with your own text, then save (Ctrl+S).'
Write-Host 'The NEXT QQ message will already use the new personality.'
Write-Host 'If it still sounds like the old one, send /new in QQ to reset context.'
Write-Host ''

# A backup before editing, so a bad paste is easy to undo.
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item $file ('D:\ds\qqbot\agent\AGENTS.md.bak-' + $stamp) -Force

Start-Process notepad.exe -ArgumentList ('"' + $file + '"')
Start-Sleep -Seconds 1
