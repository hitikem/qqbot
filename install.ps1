# ═══════════════════════════════════════════════════════════════
#  Whale Console 一键安装脚本
#  用法：右键 → 用 PowerShell 运行
# ═══════════════════════════════════════════════════════════════

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║   Whale Console 安装程序                 ║" -ForegroundColor Cyan
Write-Host "  ║   QQ Bot 控制台                          ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  安装目录: $root" -ForegroundColor Gray
Write-Host ""

# ── 1. 检查运行环境 ──
Write-Host "[1/5] 检查运行环境..." -ForegroundColor Yellow

# .NET Framework 4.8
$fw = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -EA SilentlyContinue
if ($fw.Release -ge 528040) {
    Write-Host "  .NET Framework: OK ($($fw.Version))" -ForegroundColor Green
} else {
    Write-Host "  .NET Framework: 版本过低，需要 4.8" -ForegroundColor Red
    Write-Host "  下载: https://dotnet.microsoft.com/download/dotnet-framework/net48" -ForegroundColor Yellow
}

# WebView2 Runtime
$wv2 = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' -EA SilentlyContinue
if ($wv2.pv) {
    Write-Host "  WebView2: OK ($($wv2.pv))" -ForegroundColor Green
} else {
    Write-Host "  WebView2: 未安装" -ForegroundColor Red
    Write-Host "  下载: https://go.microsoft.com/fwlink/p/?LinkId=2124703" -ForegroundColor Yellow
}

# Python（可选，聊天记录需要）
$py = Get-Command python -EA SilentlyContinue
if ($py) {
    $pyVer = & python --version 2>&1
    Write-Host "  Python: OK ($pyVer)" -ForegroundColor Green
    # 检查 zstandard
    $hasZstd = & python -c "import zstandard" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  正在安装 zstandard..." -ForegroundColor Gray
        & python -m pip install zstandard --quiet 2>&1 | Out-Null
    }
} else {
    Write-Host "  Python: 未安装（聊天记录功能不可用，其他正常）" -ForegroundColor Yellow
}

Write-Host ""

# ── 2. 创建目录 ──
Write-Host "[2/5] 创建目录..." -ForegroundColor Yellow
foreach ($d in @('logs', 'logs\wv2')) {
    $p = Join-Path $root $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}
Write-Host "  OK" -ForegroundColor Green
Write-Host ""

# ── 3. 注册计划任务（状态采集 + 聊天采集）──
Write-Host "[3/5] 注册后台任务..." -ForegroundColor Yellow

# 状态采集
$xml1 = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <TimeTrigger><StartBoundary>2026-01-01T00:00:00</StartBoundary><Repetition><Interval>PT1M</Interval></Repetition></TimeTrigger>
    <LogonTrigger><Enabled>true</Enabled></LogonTrigger>
  </Triggers>
  <Principals><Principal id="Author"><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <ExecutionTimeLimit>PT2M</ExecutionTimeLimit>
    <Enabled>true</Enabled><Hidden>true</Hidden>
  </Settings>
  <Actions Context="Author"><Exec>
    <Command>powershell.exe</Command>
    <Arguments>-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "$root\collect-status.ps1" -Quick</Arguments>
  </Exec></Actions>
</Task>
"@
$tmp1 = Join-Path $env:TEMP 'whale-t1.xml'
$xml1 | Out-File $tmp1 -Encoding Unicode
schtasks /delete /tn "QQBot-CollectStatus" /f 2>&1 | Out-Null
schtasks /create /tn "QQBot-CollectStatus" /xml $tmp1 /f 2>&1 | Out-Null
Remove-Item $tmp1 -Force -EA SilentlyContinue
Write-Host "  状态采集任务: OK" -ForegroundColor Green

# 聊天采集（只有 Python 才装）
if ($py) {
    $pyPath = (Get-Command python).Source
    $chatPy = Join-Path $root 'tools\collect-chat.py'
    if (Test-Path $chatPy) {
        $xml2 = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <TimeTrigger><StartBoundary>2026-01-01T00:00:00</StartBoundary><Repetition><Interval>PT2M</Interval></Repetition></TimeTrigger>
    <LogonTrigger><Enabled>true</Enabled></LogonTrigger>
  </Triggers>
  <Principals><Principal id="Author"><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <ExecutionTimeLimit>PT3M</ExecutionTimeLimit>
    <Enabled>true</Enabled><Hidden>true</Hidden>
  </Settings>
  <Actions Context="Author"><Exec>
    <Command>$pyPath</Command>
    <Arguments>"$chatPy"</Arguments>
    <WorkingDirectory>$root</WorkingDirectory>
  </Exec></Actions>
</Task>
"@
        $tmp2 = Join-Path $env:TEMP 'whale-t2.xml'
        $xml2 | Out-File $tmp2 -Encoding Unicode
        schtasks /delete /tn "QQBot-ChatCollect" /f 2>&1 | Out-Null
        schtasks /create /tn "QQBot-ChatCollect" /xml $tmp2 /f 2>&1 | Out-Null
        Remove-Item $tmp2 -Force -EA SilentlyContinue
        Write-Host "  聊天采集任务: OK" -ForegroundColor Green
    }
}
Write-Host ""

# ── 4. 创建桌面快捷方式 ──
Write-Host "[4/5] 创建桌面快捷方式..." -ForegroundColor Yellow
$desktop = [Environment]::GetFolderPath('Desktop')
$lnkPath = Join-Path $desktop 'Whale Console.lnk'
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut($lnkPath)
$sc.TargetPath = Join-Path $root 'QQBotConsole.exe'
$sc.IconLocation = (Join-Path $root 'QQBotConsole.exe') + ',0'
$sc.WorkingDirectory = $root
$sc.Description = 'QQ Bot 控制台'
$sc.Save()
[Runtime.InteropServices.Marshal]::ReleaseComObject($ws) | Out-Null
Write-Host "  OK: $lnkPath" -ForegroundColor Green
Write-Host ""

# ── 5. 完成 ──
Write-Host "[5/5] 安装完成！" -ForegroundColor Green
Write-Host ""
Write-Host "  ┌────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "  │  现在可以双击桌面上的 Whale Console    │" -ForegroundColor Cyan
Write-Host "  │  开始使用了                            │" -ForegroundColor Cyan
Write-Host "  └────────────────────────────────────────┘" -ForegroundColor Cyan
Write-Host ""
Write-Host "  提示:" -ForegroundColor Gray
Write-Host "    - 首次使用请在「API 管理」页填 API Key" -ForegroundColor Gray
Write-Host "    - 关闭窗口会最小化到系统托盘" -ForegroundColor Gray
Write-Host "    - 托盘图标右键可快速启停机器人" -ForegroundColor Gray
Write-Host ""

Read-Host "按回车键退出"
