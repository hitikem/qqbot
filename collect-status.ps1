param(
    [switch]$Quick
)
# QQ Bot 状态采集器
# 由计划任务每 5 秒运行一次，把状态写入 status.json
# 这样控制台（受沙箱限制）只需读文件，不用查进程

$ErrorActionPreference = 'Continue'
$out = 'D:\ds\qqbot\logs\status.json'

try {
    # 机器人进程
    $bot = Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*bin.js*' -and $_.CommandLine -like '*qqbot*' }

    $pidStr = ''
    $uptime = '-'
    $conn = -1
    if ($bot) {
        $ids = @($bot | ForEach-Object { $_.ProcessId })
        $pidStr = ($ids -join ',')
        try {
            $proc = Get-Process -Id $ids[0] -ErrorAction Stop
            $span = (Get-Date) - $proc.StartTime
            if ($span.TotalHours -ge 1) {
                $uptime = '{0}h {1:D2}m' -f [int]$span.TotalHours, $span.Minutes
            } else {
                $uptime = '{0}m {1:D2}s' -f [int]$span.TotalMinutes, $span.Seconds
            }
        } catch { }
        try {
            $conn = @(Get-NetTCPConnection -OwningProcess $ids[0] -State Established -ErrorAction SilentlyContinue |
                Where-Object { $_.RemotePort -eq 443 }).Count
        } catch { }
    }

    # 网关
    $gw = $null
    try { $gw = Get-Process agent2api -ErrorAction SilentlyContinue } catch { }
    $gwStatus = '已停止'
    if ($gw) {
        $gwStatus = '正常'
        try {
            $h = Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1:3065/health' -TimeoutSec 3
            if ($h.Content -match 'degraded') { $gwStatus = '降级' }
        } catch { $gwStatus = '无响应' }
    }

    # 人格
    $personaFull = '(读取失败)'
    try {
        $raw = [System.IO.File]::ReadAllText('D:\ds\qqbot\agent\AGENTS.md', [System.Text.Encoding]::UTF8)
        $firstLine = ($raw -split "`n")[0]
        $personaFull = $firstLine -replace '^#\s*QQ 机器人人格：', '' -replace '^#\s*', ''
        $personaFull = $personaFull.Trim()
    } catch { }
    $personaShort = $personaFull -replace '（成人向 · 高浓度）', '' -replace '（成人向）', '' -replace '版$', ''
    if ($personaShort.Length -gt 12) { $personaShort = $personaShort.Substring(0, 12) }

    # DNS
    $ip = '(解析失败)'
    try {
        $r = Resolve-DnsName 'api.sgroup.qq.com' -Type A -ErrorAction Stop |
            Where-Object { $_.IPAddress } | Select-Object -First 1
        if ($r) { $ip = $r.IPAddress }
    } catch { }
    $dnsBad = $false
    if ($ip -like '198.18.*' -or $ip -like '198.19.*') { $dnsBad = $true }

    # Clash TUN
    $tun = $null
    try {
        $c = Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1:9097/configs' `
            -Headers @{ Authorization = 'Bearer $env:CLASH_SECRET' } -TimeoutSec 3
        if ($c.Content -match '"tun"\s*:\s*\{[^}]*"enable"\s*:\s*(true|false)') {
            if ($Matches[1] -eq 'true') { $tun = 1 } else { $tun = 0 }
        }
    } catch { }

    # 自检项（Quick 模式跳过，太慢）
    $checks = @()
    if (-not $Quick) {

    function Add-Check($name, $pass, $detail) {
        $script:checks += [PSCustomObject]@{ name = $name; pass = $pass; ms = 0; detail = $detail }
    }

    $miss = @()
    foreach ($f in @('C:\Program Files\nodejs\node.exe',
                     'C:\Users\Administrator\AppData\Roaming\npm\node_modules\@deepseek-ai\dsh\lib\bin.js',
                     'D:\ds\qqbot\patch.yml',
                     'D:\ds\qqbot\autostart.ps1',
                     'D:\ds\qqbot\ui\index.html')) {
        if (-not (Test-Path $f)) { $miss += (Split-Path $f -Leaf) }
    }
    if (-not (Test-Path 'D:\ds\qqbot-repo\personas')) { $miss += 'personas' }
    Add-Check '① 文件结构' ($miss.Count -eq 0) $(if ($miss.Count -eq 0) { '全部存在' } else { '缺失: ' + ($miss -join ', ') })

    Add-Check '② 机器人进程' ([bool]$bot) $(if ($bot) { 'PID ' + $pidStr } else { '未运行' })
    Add-Check '③ 网关进程' ([bool]$gw) $(if ($gw) { 'agent2api 运行中 PID ' + $gw.Id } else { '未运行' })
    Add-Check '④ 网关接口' ($gwStatus -ne '已停止' -and $gwStatus -ne '无响应') $gwStatus

    # 模型真实调用
    $modelOk = $false
    $modelDet = '未测试'
    try {
        $body = '{"model":"deepseek-v4.1-flash","stream":false,"max_tokens":30,"messages":[{"role":"user","content":"回复OK"}]}'
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $mr = Invoke-WebRequest -UseBasicParsing -Method Post 'http://127.0.0.1:3065/v1/chat/completions' `
            -Headers @{ 'x-api-key' = 'sk-a2a-1c6d2d1382646d26b50fa44f8bc94ba8'; 'Content-Type' = 'application/json' } `
            -Body $body -TimeoutSec 30
        $sw.Stop()
        if ($mr.StatusCode -eq 200) {
            $modelOk = $true
            $modelDet = 'deepseek-v4.1-flash 正常 ' + $sw.ElapsedMilliseconds + 'ms'
        }
    } catch { $modelDet = $_.Exception.Message }
    Add-Check '⑤ 模型真实调用' $modelOk $modelDet

    Add-Check '⑥ QQ API DNS' (-not $dnsBad) $ip
    $pcount = @(Get-ChildItem 'D:\ds\qqbot-repo\personas' -Filter '*.md' -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -ne 'README' }).Count
    Add-Check '⑦ 人格文件' ($pcount -gt 0) ($pcount.ToString() + ' 套 · 当前 ' + $personaFull)

    $canWrite = $false
    try {
        $tf = 'D:\ds\qqbot\logs\.selftest'
        Set-Content -Path $tf -Value '1' -ErrorAction Stop
        Remove-Item $tf -Force
        $canWrite = $true
    } catch { }
    Add-Check '⑧ 日志写入' $canWrite $(if ($canWrite) { '可写' } else { '不可写' })

    Add-Check '⑨ Clash TUN' $(if ($null -eq $tun) { $null } else { $tun -eq 0 }) `
        $(if ($null -eq $tun) { 'Clash 未运行（直连不受影响）' } elseif ($tun -eq 1) { 'TUN 开启（会劫持 DNS）' } else { 'TUN 已关闭' })

    Add-Check '⑩ 出站连接 443' ($conn -gt 0) $(if ($conn -gt 0) { "$conn 条 Established" } elseif ($conn -eq 0) { '无连接' } else { '无法读取' })

    # 组装 JSON
    }  # end if (-not $Quick)

    # CPU / 内存
    $cpuPct  = $null
    $memMB   = $null
    $memPct  = $null
    $threads = $null

    if ($bot -and $ids) {
        try {
            $procObj = Get-Process -Id $ids[0] -ErrorAction Stop

            # 内存：MB + 占系统总内存百分比
            $memMB    = [math]::Round($procObj.WorkingSet64 / 1MB, 1)
            $totalMB  = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB, 0)
            if ($totalMB -gt 0) { $memPct = [math]::Round(($memMB / $totalMB) * 100, 1) }
            $threads  = $procObj.Threads.Count

            # CPU：采 1 秒，除以核数
            $c1 = $procObj.TotalProcessorTime.TotalMilliseconds
            $t1 = [DateTime]::UtcNow
            Start-Sleep -Milliseconds 300
            $procObj.Refresh()
            $c2 = $procObj.TotalProcessorTime.TotalMilliseconds
            $t2 = [DateTime]::UtcNow

            $elapsedMs = ($t2 - $t1).TotalMilliseconds
            $cores     = [Environment]::ProcessorCount
            if ($elapsedMs -gt 0 -and $cores -gt 0) {
                $cpuPct = [math]::Round((($c2 - $c1) / ($elapsedMs * $cores)) * 100, 1)
                if ($cpuPct -lt 0)   { $cpuPct = 0 }
                if ($cpuPct -gt 100) { $cpuPct = 100 }
            }
        } catch { }
    }

    # 消息量：统计 run-out.log 里收到消息的行数
    $msgCount = $null
    try {
        $outLog = 'D:\ds\qqbot\run-out.log'
        if (Test-Path $outLog) {
            $msgCount = @(Select-String -Path $outLog -Pattern '收到|receive|message|C2C|GROUP_AT' -SimpleMatch:$false -ErrorAction SilentlyContinue).Count
        }
    } catch { }

    $status = [PSCustomObject]@{
        ok           = $true
        time         = (Get-Date -Format 'HH:mm:ss')
        bot          = [bool]$bot
        pid          = $(if ($bot) { $pidStr } else { '-' })
        uptime       = $uptime
        cpu          = $cpuPct
        mem          = $memMB
        memPct       = $memPct
        memTotal     = $(if ($null -ne $memPct) { [math]::Round(($memMB / $memPct) * 100, 0) } else { $null })
        threads      = $threads
        msgCount     = $msgCount
        gateway      = $gwStatus
        persona      = $personaShort
        personaFull  = $personaFull
        dns          = $ip
        dnsHijacked  = $dnsBad
        conn         = $conn
        tun          = $tun
        checks       = $checks
    }

    $json = $status | ConvertTo-Json -Depth 6 -Compress
    Set-Content -Path $out -Value $json -Encoding UTF8 -Force

} catch {
    $err = [PSCustomObject]@{ ok = $false; error = $_.Exception.Message; time = (Get-Date -Format 'HH:mm:ss') }
    Set-Content -Path $out -Value ($err | ConvertTo-Json -Compress) -Encoding UTF8 -Force
}
