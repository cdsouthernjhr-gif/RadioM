#!/usr/bin/env python3
"""Generate data/malaysia_radio.json (+ data/version.json + bundled asset copy).

Usage: python3 tool/build_db.py [--version N]

Merges tool/stations_source.py with data/verification_results.json (written by
tool/verify_streams.py). stream_type is derived strictly from verification:
  direct     -> at least one stream decoded real audio in CI
  web_player -> no stream verified but an official website exists
  unverified -> streams exist but were never tested
"""
import json, os, sys, datetime
sys.path.insert(0, os.path.dirname(__file__))
from stations_source import STATIONS

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "data", "verification_results.json")

def main():
    version = None
    if "--version" in sys.argv:
        version = int(sys.argv[sys.argv.index("--version") + 1])
    results = json.load(open(RES)) if os.path.exists(RES) else {"checked_at": None, "streams": {}}
    sres = results.get("streams", {})
    out = []
    for st in STATIONS:
        st = json.loads(json.dumps(st))
        st.setdefault("state", None); st.setdefault("logo", None)
        st.setdefault("frequencies", []); st.setdefault("featured", False); st.setdefault("tags", [])
        verified, failed, untested = [], [], []
        for strm in st["streams"]:
            r = sres.get(strm["url"])
            if r is None:
                strm["verification"] = {"status": "untested"}
                untested.append(strm)
            else:
                strm["verification"] = {k: r[k] for k in ("status", "checked_at", "detail", "codec") if r.get(k) is not None}
                if r.get("codec_format") and r["status"] == "verified":
                    strm["format"] = r["codec_format"]
                (verified if r["status"] == "verified" else failed).append(strm)
        st["streams"] = verified + untested + failed
        if verified:
            st["stream_type"] = "direct"
            st["status_note"] = "Strim disahkan oleh ujian CI (audio berjaya dinyahkod)."
        elif untested:
            st["stream_type"] = "unverified"
            st["status_note"] = "Strim belum disahkan."
        else:
            st["stream_type"] = "web_player"
            st["status_note"] = ("Tiada strim terus yang disahkan; buka pemain web rasmi." if failed
                                 else "Hanya pemain web rasmi tersedia.")
        out.append(st)
    out.sort(key=lambda x: x["name"].lower())
    prev = None
    p = os.path.join(ROOT, "data", "malaysia_radio.json")
    if os.path.exists(p):
        prev = json.load(open(p))
    if version is None:
        version = (prev["version"] + 1) if prev else 1
    now = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    db = {
        "schema_version": 1,
        "version": version,
        "last_updated": now,
        "verification_checked_at": results.get("checked_at"),
        "source": "https://github.com/cdsouthernjhr-gif/RadioM",
        "stations": out,
    }
    txt = json.dumps(db, ensure_ascii=False, indent=2) + "\n"
    for path in (p, os.path.join(ROOT, "assets", "data", "malaysia_radio.json")):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, "w").write(txt)
    vj = {"schema_version": 1, "version": version, "last_updated": now, "stations": len(out)}
    open(os.path.join(ROOT, "data", "version.json"), "w").write(json.dumps(vj, indent=2) + "\n")
    c = {}
    for st in out: c[st["stream_type"]] = c.get(st["stream_type"], 0) + 1
    print(f"stations={len(out)} version={version} {c}")

if __name__ == "__main__":
    main()
