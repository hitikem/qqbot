"""深入分析 DSH 会话结构，找出 token 用量和消息内容的位置"""
import json
import os
import zstandard as zstd

SESSIONS_DIR = r"C:\Users\Administrator\.dsh\qqbot-home\sessions"


def find_sessions():
    out = []
    for root, dirs, files in os.walk(SESSIONS_DIR):
        for fn in files:
            if fn.endswith(".jsonl.zstd"):
                out.append(os.path.join(root, fn))
    return out


def load(path):
    dctx = zstd.ZstdDecompressor()
    with open(path, "rb") as fh:
        raw = dctx.stream_reader(fh).read()
    rows = []
    for line in raw.decode("utf-8", errors="replace").splitlines():
        line = line.strip()
        if line:
            try:
                rows.append(json.loads(line))
            except Exception:
                pass
    return rows


def main():
    files = find_sessions()
    if not files:
        print("no files")
        return

    # 汇总全部会话
    all_rows = []
    for f in files:
        rows = load(f)
        all_rows.extend(rows)
        print(f"{os.path.basename(os.path.dirname(f))}: {len(rows)} 行")

    print(f"\n总计 {len(all_rows)} 条事件")

    # 1) step/end 里有没有 usage
    print("\n=== step/end 样例 ===")
    for r in all_rows:
        if r.get("type") == "step/end":
            print(json.dumps(r, ensure_ascii=False)[:800])
            break

    # 2) assistant/message 结构
    print("\n=== assistant/message 样例 ===")
    for r in all_rows:
        if r.get("type") == "assistant/message":
            print(json.dumps(r, ensure_ascii=False)[:800])
            break

    # 3) user/message 结构
    print("\n=== user/message 样例 ===")
    cnt = 0
    for r in all_rows:
        if r.get("type") == "user/message":
            print(json.dumps(r, ensure_ascii=False)[:600])
            cnt += 1
            if cnt >= 2:
                break

    # 4) 搜索所有含 usage 的
    print("\n=== 含 'usage' 字段的事件类型 ===")
    found = {}
    for r in all_rows:
        s = json.dumps(r, ensure_ascii=False)
        if '"usage"' in s:
            t = r.get("type", "?")
            found[t] = found.get(t, 0) + 1
    print(found if found else "  无")

    if found:
        for r in all_rows:
            s = json.dumps(r, ensure_ascii=False)
            if '"usage"' in s:
                print("\n样例:")
                print("  " + s[:1000])
                break

    # 5) 搜索 token 相关字段名
    print("\n=== 所有字段名（采样）===")
    keys = set()
    for r in all_rows[:2000]:
        def walk(o, depth=0):
            if depth > 3:
                return
            if isinstance(o, dict):
                for k, v in o.items():
                    keys.add(k)
                    walk(v, depth + 1)
            elif isinstance(o, list):
                for v in o[:3]:
                    walk(v, depth + 1)
        walk(r)
    token_keys = [k for k in sorted(keys) if any(t in k.lower() for t in ["token", "usage", "cost", "prompt", "completion"])]
    print(f"  {token_keys}")


if __name__ == "__main__":
    main()
