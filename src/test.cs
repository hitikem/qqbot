using System;
using System.Linq;
using System.Diagnostics;
using System.Management;

class T {
    static void Main() {
        Console.WriteLine("=== 进程检测 ===");
        try {
            var ps = Process.GetProcesses().Where(p => p.ProcessName.Equals("agent2api", StringComparison.OrdinalIgnoreCase));
            Console.WriteLine("agent2api: " + ps.Count() + " 个");
        } catch (Exception e) { Console.WriteLine("进程ERR: " + e.Message); }

        Console.WriteLine("");
        Console.WriteLine("=== WMI 查询 ===");
        try {
            using (var q = new ManagementObjectSearcher("SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name='node.exe'"))
            using (var r = q.Get()) {
                int n = 0;
                foreach (ManagementObject m in r) {
                    var c = (m["CommandLine"] as string) ?? "";
                    if (c.IndexOf("bin.js", StringComparison.OrdinalIgnoreCase) >= 0 &&
                        c.IndexOf("qqbot", StringComparison.OrdinalIgnoreCase) >= 0) {
                        Console.WriteLine("匹配 PID: " + m["ProcessId"]);
                        n++;
                    }
                }
                Console.WriteLine("匹配数: " + n);
            }
        } catch (Exception e) { Console.WriteLine("WMI ERR: " + e.GetType().Name + ": " + e.Message); }
    }
}
