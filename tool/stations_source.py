#!/usr/bin/env python3
"""Source-of-truth list used to (re)generate data/malaysia_radio.json.

Stream URLs come from the community radio-browser.info directory (see
tool/discover_stations.py) or from the broadcaster's own streaming provider
naming pattern. NONE of them are considered playable until
tool/verify_streams.py has decoded real audio from them; verification results
are stored in data/verification_results.json and merged by tool/build_db.py.
"""

STW = "https://playerservices.streamtheworld.com/api/livestream-redirect/"
REVMA = "https://stream.rcs.revma.com/"
RTM_HUB = "https://radio.rtm.gov.my/"

def rtm(id, name, callsign_urls, state=None, langs=("ms",), website=RTM_HUB, freq=None,
        featured=False, logo=None, tags=()):
    return dict(id=id, name=name, category="rtm", network="RTM", state=state,
                languages=list(langs), website=website, logo=logo,
                frequencies=freq or [], featured=featured, tags=list(tags),
                streams=callsign_urls)

def s(url, fmt, bitrate=None):
    d = {"url": url, "format": fmt}
    if bitrate: d["bitrate"] = bitrate
    return d

KV = "Lembah Klang"

STATIONS = [
    # ---------------- RTM national ----------------
    rtm("rtm-nasional-fm", "Nasional FM", [s(STW + "NASIONAL_FM.mp3", "mp3", 96), s(STW + "NASIONAL_FMAAC.aac", "aac", 64)],
        website=RTM_HUB, freq=[{"area": KV, "mhz": "88.5"}], featured=True, tags=["nasional"]),
    rtm("rtm-radio-klasik", "Radio Klasik", [s(STW + "RADIO_KLASIK.mp3", "mp3", 96), s(STW + "RADIO_KLASIKAAC_SC", "aac", 64)],
        website=RTM_HUB, freq=[{"area": KV, "mhz": "87.6"}], featured=True, tags=["nasional", "klasik"]),
    rtm("rtm-traxx-fm", "TraXX FM", [s(STW + "TRAXX_FMAAC_SC", "aac", 64), s(STW + "TRAXX_FM.mp3", "mp3", 96)],
        langs=("en",), website=RTM_HUB, freq=[{"area": KV, "mhz": "90.3"}], tags=["nasional"]),
    rtm("rtm-ai-fm", "Ai FM", [s(STW + "AI_FMAAC_SC", "aac", 64), s(STW + "AI_FM.mp3", "mp3", 96)],
        langs=("zh",), website=RTM_HUB, freq=[{"area": KV, "mhz": "89.3"}], tags=["nasional"]),
    rtm("rtm-minnal-fm", "Minnal FM", [s(STW + "MINNAL_FMAAC_SC", "aac", 64), s(STW + "MINNAL_FM.mp3", "mp3", 96)],
        langs=("ta",), website=RTM_HUB, freq=[{"area": KV, "mhz": "96.3"}], tags=["nasional"]),
    rtm("rtm-asyik-fm", "Asyik FM", [s(STW + "ASYIK_FM.mp3", "mp3", 96)],
        langs=("ms", "orang-asli"), website=RTM_HUB, tags=["nasional"]),
    # ---------------- RTM state ----------------
    rtm("rtm-kl-fm", "KL FM", [s(STW + "KL_FM.mp3", "mp3", 96), s(STW + "KL_FMAAC.aac", "aac", 64)],
        state="Kuala Lumpur", freq=[{"area": KV, "mhz": "97.2"}]),
    rtm("rtm-selangor-fm", "Selangor FM", [s(STW + "SELANGOR_FM.mp3", "mp3", 96), s(STW + "SELANGOR_FMAAC.aac", "aac", 64)],
        state="Selangor", freq=[{"area": KV, "mhz": "100.9"}]),
    rtm("rtm-perak-fm", "Perak FM", [s(STW + "PERAK_FM.mp3", "mp3", 96), s(STW + "PERAK_FMAAC.aac", "aac", 64)], state="Perak"),
    rtm("rtm-kedah-fm", "Kedah FM", [s(STW + "KEDAH_FM.mp3", "mp3", 96), s(STW + "KEDAH_FMAAC.aac", "aac", 64)], state="Kedah"),
    rtm("rtm-langkawi-fm", "Langkawi FM", [s(STW + "LANGKAWI_FM.mp3", "mp3", 96)], state="Kedah",
        website=RTM_HUB),
    rtm("rtm-perlis-fm", "Perlis FM", [s(STW + "PERLIS_FM.mp3", "mp3", 96), s(STW + "PERLIS_FMAAC.aac", "aac", 64)], state="Perlis"),
    rtm("rtm-mutiara-fm", "Mutiara FM", [s(STW + "MUTIARA_FM.mp3", "mp3", 96), s(STW + "MUTIARA_FMAAC.aac", "aac", 64)], state="Pulau Pinang"),
    rtm("rtm-kelantan-fm", "Kelantan FM", [s(STW + "KELANTAN_FMAAC.aac", "aac", 64), s(STW + "KELANTAN_FM.mp3", "mp3", 96)],
        state="Kelantan", website=RTM_HUB),
    rtm("rtm-terengganu-fm", "Terengganu FM", [s(STW + "TERENGGANU_FMAAC_SC", "aac", 64), s(STW + "TERENGGANU_FM.mp3", "mp3", 96)],
        state="Terengganu", website=RTM_HUB),
    rtm("rtm-pahang-fm", "Pahang FM", [s(STW + "PAHANG_FM.mp3", "mp3", 96), s(STW + "PAHANG_FMAAC.aac", "aac", 64)], state="Pahang"),
    rtm("rtm-negeri-fm", "Negeri FM", [s(STW + "NEGERI_FM.mp3", "mp3", 96), s(STW + "NEGERI_FMAAC.aac", "aac", 64)], state="Negeri Sembilan"),
    rtm("rtm-melaka-fm", "Melaka FM", [s(STW + "MELAKA_FM.mp3", "mp3", 96), s(STW + "MELAKA_FMAAC.aac", "aac", 64)], state="Melaka"),
    rtm("rtm-johor-fm", "Johor FM", [s(STW + "JOHOR_FM.mp3", "mp3", 96), s(STW + "JOHOR_FMAAC.aac", "aac", 64)], state="Johor"),
    rtm("rtm-sabah-fm", "Sabah FM", [s(STW + "SABAH_FMAAC.aac", "aac", 64), s(STW + "SABAH_FM.mp3", "mp3", 96)],
        state="Sabah", website=RTM_HUB),
    rtm("rtm-sabah-vfm", "Sabah vFM", [s(STW + "SABAH_VFM.mp3", "mp3", 96), s(STW + "SABAH_VFMAAC.aac", "aac", 64)],
        state="Sabah", langs=("ms", "kadazandusun")),
    rtm("rtm-keningau-fm", "Keningau FM", [s(STW + "KENINGAU_FM.mp3", "mp3", 96)], state="Sabah",
        website=RTM_HUB),
    rtm("rtm-sandakan-fm", "Sandakan FM", [s(STW + "SANDAKAN_FM.mp3", "mp3", 96)], state="Sabah"),
    rtm("rtm-tawau-fm", "Tawau FM", [s(STW + "TAWAU_FM.mp3", "mp3", 96)], state="Sabah"),
    rtm("rtm-labuan-fm", "Labuan FM", [s(STW + "LABUAN_FM.mp3", "mp3", 96), s(STW + "LABUAN_FMAAC.aac", "aac", 64)], state="Labuan"),
    rtm("rtm-sarawak-fm", "Sarawak FM", [s(STW + "SARAWAK_FM.mp3", "mp3", 96), s(STW + "SARAWAK_FMAAC.aac", "aac", 64)], state="Sarawak"),
    rtm("rtm-red-fm", "RED FM", [s(STW + "RED_FMAAC.aac", "aac", 64)], state="Sarawak", langs=("en", "zh"),
        website="https://radio.rtm.gov.my/station/red-fm",
        logo="https://radio.rtm.gov.my/storage/stations/1777447046-gemini-generated-image-chd08qchd08qchd0.png"),
    rtm("rtm-wai-fm-iban", "WAI FM Iban", [s(STW + "WAI_FM_IBAN.mp3", "mp3", 96)], state="Sarawak", langs=("iban",)),
    rtm("rtm-wai-fm-bidayuh", "WAI FM Bidayuh", [s(STW + "WAI_FM_BK.mp3", "mp3", 96)], state="Sarawak", langs=("bidayuh",),
        website=RTM_HUB),
    rtm("rtm-miri-fm", "Miri FM", [s(STW + "MIRI_FM.mp3", "mp3", 96)], state="Sarawak"),
    rtm("rtm-sibu-fm", "Sibu FM", [s(STW + "SIBU_FM.mp3", "mp3", 96)], state="Sarawak"),
    rtm("rtm-bintulu-fm", "Bintulu FM", [s(STW + "BINTULU_FM.mp3", "mp3", 96)], state="Sarawak"),

    # ---------------- Commercial: Astro Radio ----------------
    dict(id="astro-era", name="ERA", category="commercial", network="Astro Radio", languages=["ms"],
         website="https://syok.my/", frequencies=[{"area": KV, "mhz": "103.3"}], featured=True, streams=[]),
    dict(id="astro-sinar", name="Sinar", category="commercial", network="Astro Radio", languages=["ms"],
         website="https://audio1.syok.my/sinar", frequencies=[{"area": KV, "mhz": "96.7"}], featured=True,
         streams=[s(REVMA + "azatk0tbv4uvv", "aac")]),
    dict(id="astro-hitz", name="HITZ", category="commercial", network="Astro Radio", languages=["en"],
         website="https://hitz.com.my/", frequencies=[{"area": KV, "mhz": "92.9"}], featured=True,
         streams=[s(REVMA + "488kt4sbv4uvv", "aac")]),
    dict(id="astro-lite", name="LITE", category="commercial", network="Astro Radio", languages=["en"],
         website="https://lite.syok.my/", frequencies=[{"area": KV, "mhz": "105.7"}],
         logo="https://media2.fishtank.my/stations/lite/2025/lite_square_updated.png",
         streams=[s(REVMA + "bn4ex8sbv4uvv", "aac")]),
    dict(id="astro-mix", name="MIX", category="commercial", network="Astro Radio", languages=["en"],
         website="https://mix.my/", frequencies=[{"area": KV, "mhz": "94.5"}],
         streams=[s(REVMA + "v5pq3htbv4uvv/hls.m3u8", "hls"), s(REVMA + "v5pq3htbv4uvv", "aac")]),
    dict(id="astro-my", name="MY", category="commercial", network="Astro Radio", languages=["zh"],
         website="https://my.com.my/", frequencies=[{"area": KV, "mhz": "101.8"}],
         streams=[s(REVMA + "hc3unrtbv4uvv/hls.m3u8", "hls"), s(REVMA + "hc3unrtbv4uvv", "aac")]),
    dict(id="astro-melody", name="Melody", category="commercial", network="Astro Radio", languages=["zh"],
         website="https://melody.my/", frequencies=[{"area": KV, "mhz": "97.7"}],
         streams=[s(REVMA + "2u1n6dtbv4uvv/hls.m3u8", "hls"), s(REVMA + "2u1n6dtbv4uvv", "aac")]),
    dict(id="astro-raaga", name="RAAGA", category="commercial", network="Astro Radio", languages=["ta"],
         website="https://raaga.syok.my/", frequencies=[{"area": KV, "mhz": "99.3"}],
         streams=[s(REVMA + "1ut6qwtbv4uvv", "aac")]),
    dict(id="astro-zayan", name="Zayan", category="commercial", network="Astro Radio", languages=["ms"],
         website="https://zayan.syok.my/", streams=[s(REVMA + "7ww2a4tbv4uvv", "aac")]),
    dict(id="astro-goxuan", name="goXuan", category="commercial", network="Astro Radio", languages=["zh"],
         website="https://goxuan.syok.my/",
         logo="https://media2.fishtank.my/app_themes/goxuan/assets/images/landscape_goxuan.png",
         streams=[s(REVMA + "xt9nhzsbv4uvv", "aac"), s(STW + "RAKITAAAC.aac", "aac", 64)]),
    dict(id="astro-gegar", name="GEGAR", category="commercial", network="Astro Radio", languages=["ms"],
         website="https://syok.my/", streams=[]),
    # ---------------- Commercial: Media Prima Audio ----------------
    dict(id="mpa-hot-fm", name="Hot FM", category="commercial", network="Media Prima Audio", languages=["ms"],
         website="https://www.hotfm.audio/", frequencies=[{"area": KV, "mhz": "97.6"}], featured=True,
         streams=[s(REVMA + "drakdf8mtd3vv/hls.m3u8", "hls"), s(REVMA + "drakdf8mtd3vv", "aac")]),
    dict(id="mpa-fly-fm", name="Fly FM", category="commercial", network="Media Prima Audio", languages=["en"],
         website="https://www.flyfm.audio/", frequencies=[{"area": KV, "mhz": "95.8"}],
         streams=[s(REVMA + "q17aka9mtd3vv", "aac")]),
    dict(id="mpa-kool-fm", name="Kool FM", category="commercial", network="Media Prima Audio", languages=["ms"],
         website="https://www.koolfm.audio/",
         streams=[s(REVMA + "3930238mtd3vv/hls.m3u8", "hls"), s(REVMA + "3930238mtd3vv", "aac")]),
    dict(id="mpa-eight-fm", name="Eight FM", category="commercial", network="Media Prima Audio", languages=["zh"],
         website="https://www.eight.audio/",
         streams=[s(REVMA + "qp0xrd9mtd3vv", "aac")]),
    # ---------------- Commercial: others ----------------
    dict(id="bfm-899", name="BFM 89.9", category="commercial", network="BFM Media", languages=["en"], state="Selangor",
         website="https://www.bfm.my/", frequencies=[{"area": KV, "mhz": "89.9"}], featured=True,
         streams=[s("https://22253.live.streamtheworld.com/BFM_SC", "mp3", 96), s(STW + "BFM_SC", "mp3", 96)]),
    dict(id="star-988", name="988 FM", category="commercial", network="Star Media", languages=["zh"],
         website="https://www.988.com.my/", frequencies=[{"area": KV, "mhz": "98.8"}],
         logo="https://www.988.com.my/wp-content/themes/988_web/assets/988-logo.png",
         streams=[s(STW + "988_FMAAC.aac", "aac", 64), s("https://28103.live.streamtheworld.com/988_FMAAC.aac", "aac", 64)]),
    dict(id="ikim-fm", name="IKIMfm", category="commercial", network="IKIM", languages=["ms"],
         website="https://ikimhub.my/", frequencies=[{"area": KV, "mhz": "91.5"}],
         logo="https://ikimhub.my/frontend/favicon.png",
         streams=[s(REVMA + "kz3pdu9wz2nwv/hls.m3u8", "hls"), s(REVMA + "kz3pdu9wz2nwv", "aac")]),
    dict(id="cats-fm", name="Cats FM", category="commercial", network="Cats Radio", languages=["en", "ms"], state="Sarawak",
         website="https://www.catsfm.my/", streams=[s(REVMA + "51qe53rv0y3vv.m4a", "aac")]),
    dict(id="cityplus-fm", name="CITYPlus FM", category="commercial", network="CITYPlus", languages=["zh"],
         website="https://cityplusfm.my/", streams=[s(REVMA + "9ykdmcawe1bwv", "aac")]),
    dict(id="afo-chinese", name="AFO Radio (Cina)", category="commercial", network="AFO Radio", languages=["zh"],
         website="https://aforadio.my/", streams=[s(REVMA + "7x3gv2y4bshvv", "aac")]),
    dict(id="afo-english", name="AFO Radio (English)", category="commercial", network="AFO Radio", languages=["en"],
         website="https://aforadio.my/", streams=[s(REVMA + "8150ezy4bshvv", "aac")]),

    # ---------------- Internet radio ----------------
    dict(id="net-radio-kpkt", name="Radio KPKT", category="internet", network="KPKT", languages=["ms"],
         website="http://radio.kpkt.gov.my/", streams=[s("http://listen.kpkt.gov.my:8000/stream", "aac")]),
    dict(id="net-nasyid-fm", name="Nasyid FM", category="internet", network="Nasyid FM", languages=["ms"],
         website="https://www.nasyidfm.com/", tags=["nasyid"], streams=[s("http://stereo.nasyidfm.com:8000/", "aac")]),
    dict(id="net-ceritera-fm", name="Ceritera FM", category="internet", network="Ceritera FM", languages=["ms"],
         website="http://ceriterafm.my/", streams=[s("http://live.ceriterafm.my:8000/", "aac")]),
    dict(id="net-kcfm", name="KCFM Radio", category="internet", network="KCFM", languages=["ms"], state="Kuala Lumpur",
         website="http://www.kcfm.org/", streams=[s("http://www.kcfm.org:8000/stream", "mp3", 128)]),
    dict(id="net-ltfm", name="LTFM Radio", category="internet", network="LTFM", languages=["ms"], state="Kuala Lumpur",
         website="http://ltfmonline.com/", streams=[s("http://live.ltfmonline.com:8000/stream", "mp3", 128)]),
    dict(id="net-stay-fm", name="Stay.FM", category="internet", network="Stay.FM", languages=["en"],
         website="https://stayfm.com/", streams=[s("https://stayfm.com:8443/archive", "mp3", 192)]),
    dict(id="net-radio-rosak", name="Radio Rosak", category="internet", network="Radio Rosak", languages=["ms"],
         website=None, streams=[s("https://radiorosak.radioca.st/stream", "aac")]),
    dict(id="net-wheelerz", name="Wheelerz Net Radio", category="internet", network="Wheelerz", languages=["ms"],
         website=None, streams=[s("http://167.114.131.90:5448/stream/", "mp3", 320)]),
    dict(id="net-gemersik-fm", name="Gemersik FM", category="internet", network="Gemersik FM", languages=["ms"],
         website="http://gemersikfm.iradio.work/", streams=[s("http://gemersikfm.iradio.work:8000/;", "mp3", 128)]),
    dict(id="net-amboi-fm", name="Amboi FM", category="internet", network="Amboi FM", languages=["ms"],
         website="http://amboifm.blogspot.com/", streams=[s("http://amboifm.iradio.work:8000/listen.pls", "pls")]),
    dict(id="net-rentak-pelangi", name="Rentak Pelangi Muzik FM", category="internet", network="Rentak Pelangi", languages=["ms"],
         website="https://www.rentakpelangifm.com/", streams=[s("http://stream.tujuh.my/proxy/rpmfm/stream", "aac")]),
]


# Android 6.0 compatibility: revma.com HTTPS once timed out on the API 23
# emulator (that was caused by just_audio's local Dart proxy, now disabled;
# HTTPS plays on API 23 since). The plain-HTTP endpoint is kept as a safety
# net for old devices / networks where HTTPS still fails. For every
# revma stream (incl. HLS) the same CDN's plain-HTTP endpoint is added as a
# *fallback* after the HTTPS one. HTTPS stays first (preferred); the app
# remembers per device which stream worked. A fallback is only marked
# verified if verify_streams.py decodes real audio from it.
def _add_http_fallbacks(stations):
    for st in stations:
        extra = []
        for strm in st["streams"]:
            u = strm["url"]
            if u.startswith(REVMA):
                extra.append(dict(strm, url="http://" + u[len("https://"):]))
        st["streams"] = st["streams"] + [e for e in extra if e["url"] not in {x["url"] for x in st["streams"]}]

_add_http_fallbacks(STATIONS)
