param(
    [string]$OutFile = 'D:\ds\qqbot\logs\shot.jpg',
    [int]$TargetWidth = 900,
    [long]$Quality = 93
)

Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class WinCap {
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
    [DllImport("user32.dll")] public static extern IntPtr SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
}
'@

$proc = Get-Process QQBotConsole -ErrorAction SilentlyContinue
if (-not $proc) { Write-Output 'ERR_NO_PROCESS'; exit 1 }

$hwnd = $proc.MainWindowHandle
if ($hwnd -eq [IntPtr]::Zero) { Write-Output 'ERR_NO_HANDLE'; exit 1 }

# 恢复窗口
if ([WinCap]::IsIconic($hwnd)) {
    [WinCap]::ShowWindow($hwnd, 9) | Out-Null
    Start-Sleep -Milliseconds 900
}
[WinCap]::SetWindowPos($hwnd, [IntPtr](-1), 0, 0, 0, 0, 0x0003) | Out-Null
[WinCap]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 1500

$rect = New-Object WinCap+RECT
[WinCap]::GetClientRect($hwnd, [ref]$rect) | Out-Null
$cw = $rect.R - $rect.L
$ch = $rect.B - $rect.T

if ($cw -le 0 -or $ch -le 0) {
    Write-Output "ERR_SIZE ${cw}x${ch}"
    exit 1
}

$origin = New-Object WinCap+POINT
[WinCap]::ClientToScreen($hwnd, [ref]$origin) | Out-Null

$bmp = New-Object System.Drawing.Bitmap([int]$cw, [int]$ch)
$gr = [System.Drawing.Graphics]::FromImage($bmp)
$gr.CopyFromScreen([int]$origin.X, [int]$origin.Y, 0, 0, $bmp.Size)

$nw = $TargetWidth
$nh = [int]($ch * $TargetWidth / $cw)
$bmp2 = New-Object System.Drawing.Bitmap([int]$nw, [int]$nh)
$gr2 = [System.Drawing.Graphics]::FromImage($bmp2)
$gr2.InterpolationMode = 'HighQualityBicubic'
$gr2.DrawImage($bmp, 0, 0, [int]$nw, [int]$nh)

$encJ = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, $Quality)
$bmp2.Save($OutFile, $encJ, $ep)

$gr.Dispose(); $bmp.Dispose(); $gr2.Dispose(); $bmp2.Dispose()

$kb = [math]::Round((Get-Item $OutFile).Length / 1KB, 1)
Write-Output "OK ${cw}x${ch} -> ${OutFile} ${kb}KB"
