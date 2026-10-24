# 安装/更新“开机自启”计划任务（登录后隐藏窗口后台运行）
# 用法：powershell -ExecutionPolicy Bypass -File D:\ds\qqbot\install-autostart.ps1
$ErrorActionPreference = 'Stop'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "D:\ds\qqbot\autostart.ps1"'
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName 'QQBot-AutoStart' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
Write-Host '已安装计划任务 QQBot-AutoStart（登录时自动启动，窗口隐藏）'
Write-Host '查看：Get-ScheduledTask -TaskName QQBot-AutoStart'
Write-Host '卸载：Unregister-ScheduledTask -TaskName QQBot-AutoStart -Confirm:$false'
