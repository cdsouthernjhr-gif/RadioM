#!/usr/bin/env python3
"""Verify every stream URL in tool/stations_source.py by decoding real audio.

A stream is marked "verified" ONLY when ffmpeg decodes at least
MIN_SECONDS of audio from it. Anything else is "failed" with a reason.
HTTP-200 alone is never treated as success.

Writes data/verification_results.json and docs/stream-verification.md and
prints one `RESULT {json}` line per stream so results can be read from CI logs.

Requires: python3 >= 3.8, ffmpeg/ffprobe on PATH.
"""
import concurrent.futures as cf, datetime, json, os, re, subprocess, sys, urllib.request, urllib.error

sys.path.insert(0, os.path.dirname(__file__))
from stations_source import STATIONS

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = "MalaysiaRadioPlayer/1.0 (stream-verification; +https://github.com/cdsouthernjhr-gif/RadioM)"
MIN_SECONDS = 6.0
DECODE_SECONDS = 10

def now():
    return datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

def http_probe(url, limit=4096):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Icy-MetaData": "0"})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            body = r.read(limit)
            return {"status": r.status, "content_type": (r.headers.get("Content-Type") or "").lower(),
                    "final_url": r.geturl(), "head": body}
    except urllib.error.HTTPError as e:
        return {"status": e.code, "content_type": (e.headers.get("Content-Type") or "").lower(), "final_url": url,
                "head": b"", "error": f"HTTP {e.code}"}
    except Exception as e:  # noqa
        return {"status": None, "content_type": "", "final_url": url, "head": b"", "error": type(e).__name__ + ": " + str(e)[:160]}

def parse_playlist(text):
    for line in text.splitlines():
        line = line.strip()
        m = re.match(r"^File\d+=(.+)$", line, re.I)
        if m: return m.group(1).strip()
        if line.lower().startswith(("http://", "https://")): return line
    return None

def decode(url):
    cmd = ["ffmpeg", "-hide_banner", "-nostdin", "-loglevel", "info", "-user_agent", UA,
           "-rw_timeout", "15000000", "-t", str(DECODE_SECONDS), "-i", url, "-vn", "-f", "null", "-"]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        err = p.stderr
    except subprocess.TimeoutExpired as e:
        err = (e.stderr.decode(errors="ignore") if isinstance(e.stderr, bytes) else (e.stderr or "")) + "\nTIMEOUT"
    codec = None
    m = re.search(r"Audio: ([a-zA-Z0-9_]+)(?: \(([^)]*)\))?[^\n]*?, (\d+) Hz", err)
    if m: codec = m.group(1) + (f" ({m.group(2)})" if m.group(2) else "") + f" {m.group(3)}Hz"
    times = re.findall(r"time=(\d+):(\d+):(\d+\.\d+)", err)
    secs = 0.0
    if times:
        h, mi, se = times[-1]; secs = int(h) * 3600 + int(mi) * 60 + float(se)
    return codec, secs, err[-400:]

def codec_format(codec, url):
    if not codec: return None
    c = codec.lower()
    if ".m3u8" in url.lower(): return "hls"
    if c.startswith("mp3"): return "mp3"
    if "he-aac" in c or "aac" in c and "he" in c: return "aac+"
    if c.startswith("aac"): return "aac"
    return c.split()[0]

def verify(url):
    r = {"url": url, "checked_at": now()}
    play_url = url
    pr = http_probe(url)
    r["http_status"] = pr["status"]; r["content_type"] = pr["content_type"]
    if pr.get("error") and pr["status"] is None:
        r.update(status="failed", detail="Sambungan gagal: " + pr["error"]); return r
    if pr["status"] and pr["status"] >= 400:
        r.update(status="failed", detail=f"HTTP {pr['status']}"); return r
    ct = pr["content_type"]
    if "text/html" in ct:
        r.update(status="failed", detail="Pelayan memulangkan halaman HTML, bukan audio"); return r
    low = url.lower().split("?")[0]
    if (low.endswith(".pls") or (low.endswith(".m3u") and not low.endswith(".m3u8"))
            or "audio/x-scpls" in ct or ("mpegurl" in ct and "vnd.apple" not in ct and ".m3u8" not in low)):
        inner = parse_playlist(pr["head"].decode("utf-8", "ignore"))
        if not inner:
            r.update(status="failed", detail="Playlist tiada URL strim"); return r
        r["resolved_url"] = inner; play_url = inner
    codec, secs, tail = decode(play_url)
    r["codec"] = codec; r["decoded_seconds"] = round(secs, 1)
    if secs >= MIN_SECONDS and codec:
        r.update(status="verified", detail=f"{secs:.0f}s audio dinyahkod ({codec})")
        r["codec_format"] = codec_format(codec, play_url)
    else:
        reason = "TIMEOUT" if "TIMEOUT" in tail else tail.strip().splitlines()[-1][:160] if tail.strip() else "tiada output"
        r.update(status="failed", detail=f"Hanya {secs:.1f}s dinyahkod: {reason}")
    return r

def check_site(url):
    if not url: return None
    pr = http_probe(url, 512)
    return {"url": url, "http_status": pr["status"], "error": pr.get("error")}

def main():
    urls = sorted({s["url"] for st in STATIONS for s in st["streams"]})
    sites = sorted({st["website"] for st in STATIONS if st.get("website")} | {st["logo"] for st in STATIONS if st.get("logo")})
    with cf.ThreadPoolExecutor(8) as ex:
        res = list(ex.map(verify, urls))
        site_res = list(ex.map(check_site, sites))
    results = {"checked_at": now(), "runner": os.environ.get("RUNNER_NAME", "local"),
               "streams": {r["url"]: r for r in res}, "sites": {s["url"]: s for s in site_res}}
    os.makedirs(os.path.join(ROOT, "data"), exist_ok=True)
    with open(os.path.join(ROOT, "data", "verification_results.json"), "w") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    for r in res: print("RESULT " + json.dumps(r, ensure_ascii=False))
    for s in site_res: print("SITE " + json.dumps(s, ensure_ascii=False))
    write_report(results)
    ok = sum(1 for r in res if r["status"] == "verified")
    print(f"SUMMARY streams={len(res)} verified={ok} failed={len(res) - ok}")

def write_report(results):
    sres = results["streams"]
    lines = ["# Laporan Pengesahan Strim / Stream Verification Report", "",
             f"Diperiksa: `{results['checked_at']}` (runner: {results['runner']}, GitHub Actions ubuntu-latest).", "",
             "Kaedah: setiap URL dimuat turun dan **ffmpeg mesti menyahkod sekurang-kurangnya "
             f"{MIN_SECONDS:.0f} saat audio sebenar**. HTTP 200 sahaja tidak dikira berjaya.", "",
             "> Ujian ini dijalankan dari pelayan CI (Amerika Syarikat/Eropah). Sesetengah strim mungkin "
             "dihadkan mengikut geografi (geo-blocked) dan berkelakuan berbeza di Malaysia. Ujian ini juga "
             "BUKAN ujian main balik pada peranti Android 6.0 sebenar.", ""]
    total = ok = 0
    lines += ["| Stesen | Format | Status | Butiran | URL |", "|---|---|---|---|---|"]
    for st in sorted(STATIONS, key=lambda x: x["name"].lower()):
        if not st["streams"]:
            lines.append(f"| {st['name']} | - | web player sahaja | Tiada URL strim terus rasmi diketahui | {st.get('website','')} |")
        for s in st["streams"]:
            r = sres.get(s["url"], {}); total += 1
            ok += r.get("status") == "verified"
            mark = "✅ disahkan" if r.get("status") == "verified" else "❌ gagal"
            det = (r.get("detail") or "").replace("|", "/")
            lines.append(f"| {st['name']} | {r.get('codec_format') or s['format']} | {mark} | {det} | `{s['url']}` |")
    lines += ["", f"**Jumlah URL strim: {total}, disahkan: {ok}, gagal: {total - ok}.**", ""]
    os.makedirs(os.path.join(ROOT, "docs"), exist_ok=True)
    open(os.path.join(ROOT, "docs", "stream-verification.md"), "w").write("\n".join(lines))

if __name__ == "__main__":
    main()
