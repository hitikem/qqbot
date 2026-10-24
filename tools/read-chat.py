"""读取 QQ Bot 聊天记录（DSH 会话格式 session.jsonl.zstd）"""
import json
import os
import sys
import zstandard as zstd

SESSIONS_DIR = r"C:\Users\Administrator\.dsh\qqbot-home\sessions"


def find_sessions():
    """递归扫描所有 session 文件"""
    out = []
    for root, dirs, files in os.walk(SESSIONS_DIR):
        for fn in files:
            if fn.endswith(".zstd") or fn.endswith(".jsonl"):
                out.append(os.path.join(root, fn))
    out.sort(key=lambda p: os.path.getmtime(p), reverse=True)
    return out


def read_session(path, max_lines=20000):
    """解压并解析会话"""
    if path.endswith(".zstd"):
        dctx = zstd.ZstdDecompressor()
        with open(path, "rb") as fh:
            raw = dctx.stream_reader(fh).read()
    else:
        with open(path, "rb") as fh:
            raw = fh.read()

    text = raw.decode("utf-8", errors="replace")
    rows = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except Exception:
            continue
        if len(rows) >= max_lines:
            break
    return rows


def main():
    files = find_sessions()
    print(f"找到 {len(files)} 个会话文件")
    for f in files:
        sz = os.path.getsize(f) // 1024
        rel = f.replace(SESSIONS_DIR + "\\", "")
        print(f"  {rel}  {sz}KB")

    if not files:
        return

    # 探查最大的那个
    target = files[0]
    rows = read_session(target, 300)
    print(f"\n=== 探查最大会话 ===")
    print(f"文件: {target}")
    print(f"行数(前300): {len(rows)}")

    kinds = {}
    for r in rows:
        k = r.get("type") or r.get("kind") or r.get("role") or "?"
        kinds[k] = kinds.get(k, 0) + 1
    print(f"类型统计: {kinds}")

    print("\n=== 前 2 条 ===")
    for r in rows[:2]:
        s = json.dumps(r, ensure_ascii=False)
        print("  " + (s[:600] + "..." if len(s) > 600 else s))
        print()

    # 找带 usage/token 的条目
    print("=== 含 token/usage 的条目 ===")
    n = 0
    for r in rows:
        s = json.dumps(r, ensure_ascii=False)
        if "usage" in s or "tokens" in s.lower():
            print("  " + s[:500])
            n += 1
            if n >= 2:
                break
    if n == 0:
        print("  (前 300 条里没有)")


if __name__ == "__main__":
    main()
