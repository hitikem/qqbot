# Show whether the QQ bot and the Agent2API gateway are running.
# ASCII-only + UTF-8 BOM on purpose (Windows PowerShell 5.1 mis-parses non-ASCII without BOM).
# Use -NoPause when calling from automation; the desktop shortcut omits it.

param([switch]$NoPause)

Write-Host '=== QQ Bot status ===' -ForegroundColor Cyan
Write-Host ''

$bot = Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
    Where-Object { $_.CommandLine -like '*dsh*qqbot*' }
if ($bot) {
    foreach ($p in $bot) {
        $start = (Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue).StartTime
        if ($start) {
            $up = (Get-Date) - $start
            Write-Host ('[OK] QQ bot      PID ' + $p.ProcessId + '   up ' + $up.ToString('hh\:mm\:ss')) -ForegroundColor Green
        } else {
            Write-Host ('[OK] QQ bot      PID ' + $p.ProcessId) -ForegroundColor Green
        }
    }
} else {
    Write-Host '[--] QQ bot      NOT running' -ForegroundColor Red
}

$gw = Get-Process agent2api -ErrorAction SilentlyContinue
if ($gw) {
    Write-Host ('[OK] Gateway     PID ' + (($gw.Id) -join ',') + '   (Agent2API, port 3065)') -ForegroundColor Green
} else {
    Write-Host '[--] Gateway     NOT running -> bot receives QQ messages but cannot reply' -ForegroundColor Red
}

$proxy = Test-NetConnection -ComputerName '127.0.0.1' -Port 7897 -InformationLevel Quiet -WarningAction SilentlyContinue
if ($proxy) {
    Write-Host '[OK] Clash proxy port 7897 is listening' -ForegroundColor Green
} else {
    Write-Host '[--] Clash proxy port 7897 is closed (bot uses a direct connection)' -ForegroundColor Yellow
}

Write-Host ''
Write-Host '=== Last 12 lines of run-out.log ===' -ForegroundColor Cyan
$out = 'D:\ds\qqbot\run-out.log'
if (Test-Path $out) {
    Get-Content $out -Tail 40 -ErrorAction SilentlyContinue |
        Where-Object { $_ -match '\S' -and $_ -notmatch '[\u2580\u2584\u2588]' } |
        Select-Object -Last 12
} else {
    Write-Host '(no log file yet)'
}

if ($NoPause) { return }

Write-Host ''
Write-Host 'Press any key to close...'
try {
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
} catch {
    # redirected / non-interactive: just exit
}
