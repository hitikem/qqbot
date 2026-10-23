# QQBot autostart: launches Agent2API gateway + the QQ bot in the background.
# Called by scheduled task "QQBot-AutoStart" at logon (see install-autostart.ps1).
# NOTE: keep this file ASCII-only and saved as UTF-8 with BOM so Windows
# PowerShell 5.1 parses it correctly on any locale.

$ErrorActionPreference = 'Continue'
$log = 'D:\ds\qqbot\autostart.log'
$proxyPort = 7897

function Write-Log([string]$m) {
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
    Add-Content -Path $log -Value $line -Encoding utf8
}

Write-Log 'autostart begin'

# Wait for network / Clash proxy to come up (Clash may start much later)
Start-Sleep -Seconds 25

# Decide proxy vs direct: only use the proxy when its port is actually listening.
# If Clash is not running, the system proxy points at a dead port and the bot
# would fail to reach QQ, so fall back to a direct connection in that case.
$useProxy = $false
for ($i = 1; $i -le 12; $i++) {
    $probe = Test-NetConnection -ComputerName '127.0.0.1' -Port $proxyPort -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($probe) { $useProxy = $true; break }
    Write-Log ('proxy port not ready, retry ' + $i)
    Start-Sleep -Seconds 5
}

if ($useProxy) {
    $proxy = 'http://127.0.0.1:' + $proxyPort
    $env:HTTPS_PROXY = $proxy
    $env:HTTP_PROXY = $proxy
    Write-Log ('using proxy ' + $proxy)
} else {
    # Explicitly clear proxy vars so Node does not inherit a dead proxy
    Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:HTTP_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:ALL_PROXY -ErrorAction SilentlyContinue
    Write-Log 'proxy port unreachable, using direct connection'
}

# 1) Agent2API gateway (needs the bot API key in its environment)
$gateway = Get-Process agent2api -ErrorAction SilentlyContinue
if (-not $gateway) {
    $env:AGENT2API_PROXY_API_KEY = 'sk-qqbot-9c1d4e7a2b6f8e30'
    Start-Process -FilePath 'C:\Program Files\Agent2API\agent2api.exe' -WindowStyle Hidden
    Write-Log 'agent2api started'
    Start-Sleep -Seconds 10
} else {
    Write-Log ('agent2api already running (pid ' + (($gateway.Id) -join ',') + ')')
}

# 2) Do not start a second bot if one is already running
$existing = Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
    Where-Object { $_.CommandLine -like '*dsh*qqbot*' }
if ($existing) {
    Write-Log ('qqbot already running (pid ' + (($existing.ProcessId) -join ',') + ')')
    return
}

# 3) Start the QQ bot (dsh qqbot profile), no window, output to log files
$env:DSH_HOME = 'C:\Users\Administrator\.dsh\qqbot-home'
$env:AGENT2API_PROXY_API_KEY = 'sk-qqbot-9c1d4e7a2b6f8e30'

Set-Location 'D:\ds\qqbot'
Write-Log 'starting dsh qqbot'
& dsh --profile qqbot --patch 'D:\ds\qqbot\patch.yml' *>> 'D:\ds\qqbot\run-out.log' 2>> 'D:\ds\qqbot\run-err.log'
Write-Log 'dsh qqbot exited'
