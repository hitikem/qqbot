using System;
using System.Diagnostics;
using System.Text;

class T {
    static void Main() {
        Console.WriteLine("=== 从 C# 调用 PowerShell ===");
        try {
            var psi = new ProcessStartInfo("powershell.exe",
                "-NoProfile -NonInteractive -Command \"(Get-CimInstance Win32_Process -Filter \\\"Name=''node.exe''\\\").Count\"")
            {
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            using (var p = Process.Start(psi)) {
                var o = p.StandardOutput.ReadToEnd();
                p.WaitForExit(8000);
                Console.WriteLine("node.exe 数量: [" + o.Trim() + "]");
            }
        } catch (Exception e) { Console.WriteLine("ERR: " + e.Message); }

        Console.WriteLine("");
        Console.WriteLine("=== 再测 agent2api ===");
        try {
            var psi = new ProcessStartInfo("powershell.exe",
                "-NoProfile -NonInteractive -Command \"(Get-Process agent2api -ErrorAction SilentlyContinue) -ne $null\"")
            {
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            using (var p = Process.Start(psi)) {
                var o = p.StandardOutput.ReadToEnd();
                p.WaitForExit(8000);
                Console.WriteLine("agent2api 存在: [" + o.Trim() + "]");
            }
        } catch (Exception e) { Console.WriteLine("ERR: " + e.Message); }
    }
}
