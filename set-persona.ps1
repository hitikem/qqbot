# 切换人格
# 用法: .\set-persona.ps1 御姐
#       .\set-persona.ps1        (列出所有可选)
# ASCII-only + UTF-8 BOM (PowerShell 5.1 必需)

param([string]$Name)

$PersonaDir = 'D:\ds\qqbot-repo\personas'
$Target = 'D:\ds\qqbot\agent\AGENTS.md'
$Patch = 'D:\ds\qqbot\patch.yml'

Write-Host '=== QQ Bot 人格切换 ===' -ForegroundColor Cyan
Write-Host ''

if (-not $Name) {
    Write-Host 'Available personas:'
    Get-ChildItem $PersonaDir -Filter '*.md' |
        Where-Object { $_.BaseName -ne 'README' } |
        ForEach-Object { Write-Host ('  ' + $_.BaseName) }
    Write-Host ''
    Write-Host ('Usage: .\set-persona.ps1 <name>')
    return
}

$src = Join-Path $PersonaDir ($Name + '.md')
if (-not (Test-Path $src)) {
    Write-Host ('No such persona: ' + $Name) -ForegroundColor Red
    Write-Host 'Available:'
    Get-ChildItem $PersonaDir -Filter '*.md' |
        Where-Object { $_.BaseName -ne 'README' } |
        ForEach-Object { Write-Host ('  ' + $_.BaseName) }
    return
}

# backup current
if (Test-Path $Target) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Copy-Item $Target (Join-Path (Split-Path $Target) ('AGENTS.md.bak-' + $stamp)) -Force
    Write-Host ('Backed up current persona as AGENTS.md.bak-' + $stamp)
}

Copy-Item $src $Target -Force
Write-Host ('Persona applied: ' + $Name) -ForegroundColor Green

# neutralize patch.yml persona so AGENTS.md wins
if (Test-Path $Patch) {
    $lines = Get-Content $Patch
    $out = @()
    $inPersona = $false
    foreach ($line in $lines) {
        if ($line -match '^\s+persona:\s*\|-') {
            $inPersona = $true
            $out += $line
            $out += '      \u4f60\u7684\u4eba\u683c\u8bbe\u5b9a\u5df2\u7ecf\u5185\u5316\uff0c\u76f4\u63a5\u7167\u7740\u8bf4\uff0c\u4e0d\u8981\u63d0\u53ca\u4efb\u4f55\u6587\u4ef6\u6216\u8def\u5f84\u3002'
            continue
        }
        if ($inPersona) {
            if ($line -match '^\s{0,5}\S' -or $line -match '^#') {
                $inPersona = $false
                $out += $line
            }
            # else: skip old persona body
            continue
        }
        $out += $line
    }
    Set-Content -Path $Patch -Value $out -Encoding UTF8
    Write-Host 'patch.yml persona neutralized (AGENTS.md now takes effect)'
}

Write-Host ''
Write-Host 'Done. No restart needed - change takes effect on next message.' -ForegroundColor Green
