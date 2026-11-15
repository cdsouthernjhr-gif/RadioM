#!/usr/bin/env python3
"""Fetch Malaysian station candidates from the public radio-browser.info API.

Output is used by maintainers as *candidate* data only. Every stream found here
is community-submitted and must be verified (tool/verify_streams.py) and
cross-checked against the broadcaster's official site before it is marked
"verified" in data/malaysia_radio.json.
"""
import json, sys, urllib.request

URL = ("https://all.api.radio-browser.info/json/stations/bycountrycodeexact/MY"
       "?hidebroken=false&order=votes&reverse=true&limit=400")
req = urllib.request.Request(URL, headers={"User-Agent": "MalaysiaRadioPlayer-maintenance/1.0"})
with urllib.request.urlopen(req, timeout=30) as r:
    data = json.load(r)
out = []
for s in data:
    out.append({k: s.get(k) for k in ("name", "url", "url_resolved", "homepage", "favicon",
                                      "state", "language", "codec", "bitrate", "hls",
                                      "lastcheckok", "votes", "tags")})
json.dump(out, sys.stdout, ensure_ascii=False, indent=0)
print()
print(f"# total={len(out)}", file=sys.stderr)
