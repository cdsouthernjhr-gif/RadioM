#!/usr/bin/env python3
"""Rebuild data/verification_results.json from a saved verify-streams CI log.

Usage: python3 tool/import_ci_log.py <log-file>
Useful when CI artifacts cannot be downloaded; the log contains one
`RESULT {...}` / `SITE {...}` JSON line per URL.
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def main(path):
    raw = open(path, encoding="utf-8").read()
    try:
        d = json.loads(raw)
        if isinstance(d, dict):
            raw = d.get("logs_content") or d.get("content") or json.dumps(d)
    except ValueError:
        pass
    if "\n" not in raw[:20000]:
        raw = raw.replace("\\n", "\n")
    streams, sites, checked = {}, {}, None
    dec = json.JSONDecoder()
    for tag, store in (("RESULT ", streams), ("SITE ", sites)):
        for m in re.finditer(re.escape(tag) + r"\{", raw):
            try:
                obj, _ = dec.raw_decode(raw, m.end() - 1)
            except ValueError:
                continue
            store[obj["url"]] = obj
            checked = max(checked or "", obj.get("checked_at") or "")
    out = {"checked_at": checked, "runner": "github-actions", "streams": streams, "sites": sites}
    json.dump(out, open(os.path.join(ROOT, "data", "verification_results.json"), "w"), ensure_ascii=False, indent=2)
    ok = sum(1 for r in streams.values() if r["status"] == "verified")
    print(f"imported streams={len(streams)} verified={ok} sites={len(sites)}")

if __name__ == "__main__":
    main(sys.argv[1])
