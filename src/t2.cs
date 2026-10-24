using System;
using System.Linq;
using System.Diagnostics;
using System.Management;

class T {
    static void Main() {
        Console.WriteLine("=== 1. 简单进程列表 ===");
        try {
            var all = Process.GetProcesses();
            Console.WriteLine("总进程数: " + all.Length);
            var nodes = all.Where(p => p.ProcessName.ToLower().Contains("node")).ToList();
            Console.WriteLine("node 相关: " + nodes.Count);
            foreach(var p in nodes.Take(5)) Console.WriteLine("  " + p.ProcessName + " PID=" + p.Id);
        } catch (Exception e) { Console.WriteLine("ERR1: " + e.GetType().Name + " " + e.Message); }

        Console.WriteLine("");
        Console.WriteLine("=== 2. 精确匹配 agent2api ===");
        try {
            var g = Process.GetProcesses().Where(p => p.ProcessName.ToLower() == "agent2api").ToList();
            Console.WriteLine("找到: " + g.Count);
        } catch (Exception e) { Console.WriteLine("ERR2: " + e.Message); }

        Console.WriteLine("");
        Console.WriteLine("=== 3. WMI 整体 ===");
        try {
            var mo = new ManagementObjectSearcher("SELECT ProcessId FROM Win32_Process");
            var col = mo.Get();
            Console.WriteLine("WMI 进程数: " + col.Count);
        } catch (Exception e) { Console.WriteLine("ERR3: " + e.GetType().FullName + " | " + e.Message); }

        Console.WriteLine("");
        Console.WriteLine("=== 4. WMI 取 CommandLine ===");
        try {
            var mo = new ManagementObjectSearcher("SELECT ProcessId, Name, CommandLine FROM Win32_Process WHERE Name='node.exe'");
            var col = mo.Get();
            Console.WriteLine("node.exe 数: " + col.Count);
            foreach (ManagementObject m in col) {
                var c = m["CommandLine"];
                Console.WriteLine("  PID=" + m["ProcessId"] + " Cmd=" + (c == null ? "NULL" : "有(" + c.ToString().Length + "字)"));
            }
        } catch (Exception e) { Console.WriteLine("ERR4: " + e.GetType().FullName + " | " + e.Message); }
    }
}
