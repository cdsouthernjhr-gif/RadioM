# Skema `malaysia_radio.json` (schema_version 1)

```jsonc
{
  "schema_version": 1,                 // integer, wajib. Aplikasi menolak versi > yang disokong.
  "version": 3,                        // integer >= 1, wajib. Dinaikkan setiap kali data berubah.
  "last_updated": "2026-11-15T00:00:00Z", // ISO-8601, wajib.
  "verification_checked_at": "...",    // ISO-8601, pilihan: masa ujian strim terakhir.
  "source": "https://github.com/...",  // pilihan
  "stations": [                        // senarai, wajib, tidak kosong
    {
      "id": "rtm-nasional-fm",         // unik, wajib
      "name": "Nasional FM",           // wajib
      "category": "rtm",               // rtm | commercial | internet
      "stream_type": "direct",         // direct | web_player | unverified
      "network": "RTM",
      "state": null,                   // null = nasional, atau nama negeri
      "languages": ["ms"],             // ms, en, zh, ta, iban, bidayuh, kadazandusun, orang-asli
      "frequencies": [{"area": "Lembah Klang", "mhz": "88.5"}],
      "logo": "https://...",           // http/https sahaja atau null
      "website": "https://...",        // laman/pemain web rasmi; wajib untuk web_player
      "featured": true,
      "tags": [],
      "status_note": "...",
      "streams": [                     // disusun ikut keutamaan (disahkan dahulu)
        {
          "url": "https://...",        // http/https sahaja
          "format": "mp3",             // mp3 | aac | aac+ | hls | pls | m3u
          "bitrate": 96,
          "verification": {
            "status": "verified",      // verified | failed | untested
            "checked_at": "...",
            "detail": "10s audio dinyahkod (mp3 44100Hz)",
            "codec": "mp3 (mp3float) 44100Hz"
          }
        }
      ]
    }
  ]
}
```

## Peraturan pengesahan dalam aplikasi (`JsonService.validate`)

* Ralat root (pangkalan data **ditolak**, data tempatan dikekalkan): root bukan objek,
  `schema_version` bukan integer / tidak disokong, `version` < 1, `last_updated` bukan tarikh,
  `stations` bukan senarai atau kosong, atau lebih separuh stesen tidak sah.
* Ralat stesen (stesen itu **digugurkan**, yang lain kekal): `id` kosong/berulang, `name` kosong,
  `category`/`stream_type` tidak sah, URL strim/logo/website bukan http/https atau mengandungi
  kelayakan (`user:pass@`), format tidak dikenali, `direct` tanpa strim, `web_player` tanpa website.

## `data/version.json`

Fail kecil yang disemak dahulu. Fail penuh hanya dimuat turun jika `version` di sini lebih besar
daripada versi tempatan. Jika `version.json` tidak dapat dibaca, aplikasi menggunakan ETag
(`If-None-Match`) untuk mengelakkan muat turun berulang.

```json
{"schema_version": 1, "version": 3, "last_updated": "2026-11-15T00:00:00Z", "stations": 65}
```
