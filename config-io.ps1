# QQ Bot 配置读写（供控制台调用）
param(
    [string]$Action = 'get',
    [string]$Key = '',
    [string]$Value = ''
)

$ErrorActionPreference = 'Continue'
$patch = 'D:\ds\qqbot\patch.yml'
$agent = 'D:\ds\qqbot\agent\AGENTS.md'

function Out-Json($obj) {
    Write-Output ($obj | ConvertTo-Json -Compress -Depth 5)
}

function Get-CfgValue($key) {
    if (-not (Test-Path $patch)) { return $null }
    $lines = [System.IO.File]::ReadAllLines($patch, [System.Text.Encoding]::UTF8)
    $re = '^\s+' + $key + ':\s*(.+?)\s*$'
    foreach ($line in $lines) {
        if ($line -match $re) {
            $v = $Matches[1].Trim()
            $v = $v.Trim("'")
            $v = $v.Trim('"')
            return $v
        }
    }
    return $null
}

function Set-CfgValue($key, $val) {
    if (-not (Test-Path $patch)) { return $false }
    $lines = [System.IO.File]::ReadAllLines($patch, [System.Text.Encoding]::UTF8)
    $re = '^(\s+)' + $key + ':\s*(.+?)\s*$'
    $out = New-Object System.Collections.ArrayList
    $done = $false
    foreach ($line in $lines) {
        if ((-not $done) -and ($line -match $re)) {
            $indent = $Matches[1]
            [void]$out.Add($indent + $key + ': ' + $val)
            $done = $true
        } else {
            [void]$out.Add($line)
        }
    }
    if (-not $done) { return $false }
    $bak = $patch + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    Copy-Item $patch $bak -Force -ErrorAction SilentlyContinue
    [System.IO.File]::WriteAllLines($patch, $out.ToArray(), (New-Object System.Text.UTF8Encoding($false)))
    return $true
}

try {
    if ($Action -eq 'get') {
        Out-Json @{
            ok = $true
            model = Get-CfgValue 'model'
            provider = Get-CfgValue 'provider'
            appId = Get-CfgValue 'appId'
            requireMention = Get-CfgValue 'requireMention'
            streaming = Get-CfgValue 'streaming'
            debug = Get-CfgValue 'debug'
            showToolResults = Get-CfgValue 'showToolResults'
            c2cMode = Get-CfgValue 'c2cMode'
            groupMode = Get-CfgValue 'groupMode'
            cwd = Get-CfgValue 'cwd'
        }
    }
    elseif ($Action -eq 'set') {
        if (-not $Key) { Out-Json @{ ok = $false; msg = 'Key empty' }; return }
        $changed = Set-CfgValue $Key $Value
        if (-not $changed) { Out-Json @{ ok = $false; msg = "key not found: $Key" }; return }
        $verify = Get-CfgValue $Key
        $ok = ($verify -eq $Value)
        Out-Json @{
            ok = $ok
            msg = $(if ($ok) { "$Key = $Value" } else { "verify failed: got $verify" })
            key = $Key
            value = $verify
        }
    }
    elseif ($Action -eq 'getpersona') {
        if (-not (Test-Path $agent)) { Out-Json @{ ok = $false; msg = 'AGENTS.md not found' }; return }
        $text = [System.IO.File]::ReadAllText($agent, [System.Text.Encoding]::UTF8)
        $first = ''
        if ($text.Length -gt 0) { $first = ($text -split "`n")[0] }
        Out-Json @{ ok = $true; text = $text; size = $text.Length; title = $first }
    }
    elseif ($Action -eq 'setpersona') {
        if (-not (Test-Path $agent)) { Out-Json @{ ok = $false; msg = 'AGENTS.md not found' }; return }
        if ($Value.Length -lt 50) { Out-Json @{ ok = $false; msg = 'too short (min 50)' }; return }
        $bak = $agent + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Copy-Item $agent $bak -Force -ErrorAction SilentlyContinue
        [System.IO.File]::WriteAllText($agent, $Value, (New-Object System.Text.UTF8Encoding($false)))
        $verify = [System.IO.File]::ReadAllText($agent, [System.Text.Encoding]::UTF8)
        $ok = ($verify -eq $Value)
        Out-Json @{
            ok = $ok
            msg = $(if ($ok) { "saved $($Value.Length) chars" } else { 'save failed' })
            size = $verify.Length
            backup = (Split-Path $bak -Leaf)
        }
    }
    else {
        Out-Json @{ ok = $false; msg = "unknown action: $Action" }
    }
}
catch {
    Out-Json @{ ok = $false; msg = $_.Exception.Message }
}
