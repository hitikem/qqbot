# QQBot autostart: launches Agent2API gateway + the QQ bot in the background.
# Called by scheduled task "QQBot-AutoStart" at logon (see install-autostart.ps1).
# NOTE: keep this file ASCII-only and saved as UTF-8 with BOM so Windows
# PowerShell 5.1 parses it correctly on any locale.

$ErrorActionPreference = 'Continue'
$log = 'D:\ds\qqbot\autostart.log'
$lockFile = 'D:\ds\qqbot\autostart.lock'
$proxyPort = 7897

function Write-Log([string]$m) {
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
    Add-Content -Path $log -Value $line -Encoding utf8
}

# --- Single instance guard: never run two autostarts at once ---
if (Test-Path $lockFile) {
    $lockPid = (Get-Content $lockFile -Raw -ErrorAction SilentlyContinue).Trim()
    if ($lockPid -match '^\d+$' -and (Get-Process -Id ([int]$lockPid) -ErrorAction SilentlyContinue)) {
        Write-Log ('another autostart is running (pid ' + $lockPid + '), exiting')
        return
    }
}
Set-Content -Path $lockFile -Value $PID -Encoding ascii

try {

Write-Log 'autostart begin'

# --- Decide proxy vs direct, ONCE, and be decisive ---
# Probe the proxy port quickly. If Clash is not listening, we go direct and
# make sure the dead proxy is NOT inherited by anything we spawn.
$useProxy = $false
for ($i = 1; $i -le 3; $i++) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $iar = $tcp.BeginConnect('127.0.0.1', $proxyPort, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne(800)) { $tcp.EndConnect($iar); $useProxy = $true }
        $tcp.Close()
    } catch { }
    if ($useProxy) { break }
    Start-Sleep -Milliseconds 500
}

if ($useProxy) {
    $proxy = 'http://127.0.0.1:' + $proxyPort
    $env:HTTPS_PROXY = $proxy
    $env:HTTP_PROXY = $proxy
    Write-Log ('using proxy ' + $proxy)
} else {
    # Critical: clear in-process env AND make sure nothing re-adds it.
    $env:HTTPS_PROXY = ''
    $env:HTTP_PROXY = ''
    $env:ALL_PROXY = ''
    Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:HTTP_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:ALL_PROXY -ErrorAction SilentlyContinue
    Write-Log 'proxy port unreachable, using DIRECT connection (no proxy vars set)'
}

# Keep localhost and domestic endpoints off the proxy regardless.
$env:NO_PROXY = 'localhost,127.0.0.1,::1,[::1],qq.com,.qq.com,api.sgroup.qq.com,deepseek.com,.deepseek.com'
$env:no_proxy = $env:NO_PROXY

# --- 1) Agent2API gateway ---
$gateway = Get-Process agent2api -ErrorAction SilentlyContinue
if (-not $gateway) {
    Start-Process -FilePath 'C:\Program Files\Agent2API\agent2api.exe' -WindowStyle Hidden
    Write-Log 'agent2api started'
    Start-Sleep -Seconds 10
} else {
    Write-Log ('agent2api already running (pid ' + (($gateway.Id) -join ',') + ')')
}

# --- 2) Do not start a second bot if one is already running ---
$existing = Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
    Where-Object { $_.CommandLine -like '*dsh*qqbot*' }
if ($existing) {
    Write-Log ('qqbot already running (pid ' + (($existing.ProcessId) -join ',') + '), not starting another')
    return
}

# --- 3) Start the QQ bot ---
# IMPORTANT: launch node directly instead of the `dsh` PowerShell wrapper.
# The wrapper (dsh.ps1) ties the child process to its own console, so when
# the wrapper exits (or the scheduled task is recycled) the bot is killed too.
$env:DSH_HOME = 'C:\Users\Administrator\.dsh\qqbot-home'
$env:AGENT2API_PROXY_API_KEY = 'sk-a2a-1c6d2d1382646d26b50fa44f8bc94ba8'

$nodeExe = 'C:\Program Files\nodejs\node.exe'
$dshJs = 'C:\Users\Administrator\AppData\Roaming\npm\node_modules\@deepseek-ai\dsh\lib\bin.js'

if (-not (Test-Path $nodeExe)) { Write-Log ('ERROR: node not found at ' + $nodeExe); return }
if (-not (Test-Path $dshJs))   { Write-Log ('ERROR: dsh entry not found at ' + $dshJs); return }

Set-Location 'D:\ds\qqbot'
Write-Log ('starting dsh qqbot via node (proxy=' + $useProxy + ')')

# Detached, hidden, inheriting our env (which already has the right proxy vars)
$botProc = Start-Process -FilePath $nodeExe `
    -ArgumentList @($dshJs, '--profile', 'qqbot', '--patch', 'D:\ds\qqbot\patch.yml') `
    -WorkingDirectory 'D:\ds\qqbot' `
    -WindowStyle Hidden `
    -RedirectStandardOutput 'D:\ds\qqbot\run-out.log' `
    -RedirectStandardError 'D:\ds\qqbot\run-err.log' `
    -PassThru

Write-Log ('qqbot launched, pid ' + $botProc.Id)

# Wait a bit and verify it is actually alive
Start-Sleep -Seconds 20
if (Get-Process -Id $botProc.Id -ErrorAction SilentlyContinue) {
    Write-Log 'qqbot is running'
} else {
    Write-Log 'WARNING: qqbot exited shortly after launch - check run-err.log'
}

}
finally {
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
}
