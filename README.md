# Malaysia Radio Player

Aplikasi radio Malaysia untuk **Android 6.0 Marshmallow (API 23) dan ke atas**: telefon, tablet
dan **Android TV / TV box**. Dibina dengan Flutter 3.24.5.

* Direktori radio Malaysia: RTM (nasional & negeri), komersial dan radio internet
* Carian, susunan A-Z / Z-A, tapisan kategori, negeri dan bahasa
* Pemain audio: Play, Pause, Stop, kelantangan, buffering/loading indicator, status
  Playing / Paused / Buffering / Error / Offline, sambung semula automatik
* Main di latar belakang (foreground service), kawalan notifikasi media dan lock screen
  (MediaSession), pengurusan audio focus, jeda apabila fon kepala ditanggalkan
* Pangkalan data JSON jauh di GitHub dengan semakan versi, cache tempatan dan fallback luar talian
* Kegemaran (boleh disusun semula, termasuk dengan alat kawalan jauh TV), Recently Played
* Dark/Light mode, biru gelap + turquoise, mini player, full-screen player, animasi gelombang ringan
* Android TV: navigasi D-pad, fokus visual jelas, NavigationRail, ikon dalam Leanback launcher

> **Kejujuran status:** "Strim disahkan" bermaksud ujian automatik CI berjaya **menyahkod audio
> sebenar** daripada URL itu pada tarikh ujian (lihat [`docs/stream-verification.md`](docs/stream-verification.md)).
> Ia bukan jaminan stesen sedang bersiaran, dan bukan ujian pada peranti Android 6.0 fizikal.

---

## Laporan pembangunan

Lihat [Laporan akhir](#laporan-akhir) di bawah untuk SDK, versi, saiz APK dan status ujian.

## Keserasian

| Perkara | Nilai |
|---|---|
| Flutter SDK | 3.24.5 (stable) |
| Dart | 3.5.4 |
| minSdkVersion | **23** (Android 6.0) — jangan dinaikkan |
| targetSdkVersion / compileSdk | 34 |
| ABI dalam APK | armeabi-v7a (ARM32), arm64-v8a (ARM64), x86_64 |
| AGP / Gradle / Kotlin | 8.1.0 / 8.3 / 1.8.22 (templat Flutter 3.24.5) |
| JDK untuk build | 17 |

### Kebergantungan (dipin dalam `pubspec.yaml`, transitif dikunci dalam `pubspec.lock`)

| Pakej | Versi | minSdk Android plugin | Kegunaan |
|---|---|---|---|
| just_audio | 0.9.42 | 16 | Pemain (ExoPlayer): MP3, AAC/AAC+, HLS |
| audio_service | 0.18.15 | 16 | Foreground service, notifikasi, lock screen |
| audio_session | 0.1.21 | 16 | Audio focus, "becoming noisy" |
| http | 1.2.2 | – | Muat turun JSON |
| path_provider | 2.1.4 (android 2.2.12) | 19 | Lokasi cache JSON |
| shared_preferences | 2.3.3 (android **2.3.4**) | 19 | Tetapan, kegemaran |
| connectivity_plus | 6.1.0 | 19 | Status rangkaian |
| cached_network_image / flutter_cache_manager | 3.4.1 / 3.4.1 | 19 (sqflite) | Logo, cache cakera |
| url_launcher | 6.3.1 (android 6.3.12) | 19 | Buka pemain web rasmi |
| provider | 6.1.2 | – | Pengurusan state |

Perubahan & sebab:
* `dependency_overrides` digunakan untuk memin implementasi Android (`shared_preferences_android`,
  `path_provider_android`, `url_launcher_android`, `sqflite*`) kepada versi yang dibina dengan
  toolchain AGP 8 / Kotlin 1.x yang serasi dengan Flutter 3.24.5. Versi terbaru memerlukan Flutter ≥ 3.27.
* `shared_preferences_android` **2.3.4** (bukan 2.3.3): 2.3.3 terjejas oleh advisori keselamatan
  GHSA-3hpf-ff72-j67p (deserialisasi), dibaiki dalam 2.3.4.
* Tiada Google Play Services. Tiada plugin yang memerlukan API 24+.

### Isu khusus Android 6.0 yang ditangani

| Isu | Penyelesaian |
|---|---|
| Android 6.0/7.0 tiada sijil akar **ISRG Root X1/X2** (Let's Encrypt) → HTTPS gagal | Sijil akar rasmi ISRG dibundel (`res/raw`, `assets/certs`) dan **ditambah** pada trust store (sistem + ISRG) untuk ExoPlayer (`MainActivity.kt`, hanya API < 25) dan Dart `SecurityContext`. Pengesahan sijil **tidak pernah dimatikan**. API 24+ juga melalui `network_security_config.xml`. |
| `POST_NOTIFICATIONS` (API 33) | Diminta pada masa jalan hanya jika `SDK_INT >= 33`. |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (API 34) | Diisytihar dalam manifest; diabaikan oleh versi lama. |
| `networkSecurityConfig` (API 24) | Diabaikan oleh API 23; `usesCleartextTraffic` digunakan. |
| Strim HTTP (Icecast/Shoutcast) | Cleartext dibenarkan (banyak pelayan radio Malaysia hanya http); HTTPS diutamakan dalam pangkalan data. |
| just_audio menghantar strim melalui proksi Dart tempatan apabila User-Agent ditetapkan; proksi itu guna `HttpClient` biasa tanpa sijil ISRG → `CERTIFICATE_VERIFY_FAILED` / timeout HTTPS pada API 23 | `useProxyForRequestHeaders: false` (ExoPlayer hantar header sendiri) dan `HttpOverrides.global` memberi semua `HttpClient` Dart trust store yang sama (sistem + ISRG). |
| Logo HTTPS pada API 23 | Logo dimuat melalui `HttpClientFactory` (cache khas `LogoCache`); gagal → monogram. |
| RAM rendah pada TV box | Logo dinyahkod pada saiz paparan (`memCacheWidth`), animasi berhenti bila tidak bermain. |

## Struktur projek

```
lib/
  main.dart, app.dart, bootstrap.dart
  core/{constants,config,network,utils}/
  data/models/radio_station.dart, radio_database.dart
  data/repositories/radio_repository.dart
  data/services/json_service.dart, download_service.dart
  features/{home,directory,player,favorites,settings}/
  services/audio_service.dart, connectivity_service.dart, storage_service.dart,
           stream_resolver.dart, player_types.dart
  widgets/radio_card.dart, mini_player.dart, full_player.dart, loading_widget.dart, ...
assets/data/malaysia_radio.json      # salinan terbina (fallback luar talian)
assets/certs/                        # sijil akar ISRG rasmi
data/malaysia_radio.json             # pangkalan data jauh (dihoskan di GitHub)
data/version.json                    # manifest versi kecil
data/verification_results.json       # keputusan ujian strim mentah
docs/stream-verification.md          # laporan ujian strim
docs/json-schema.md                  # skema JSON
tool/                                # skrip penyelenggaraan pangkalan data
test/unit, test/widget, test/integration   # ujian hos (flutter test)
integration_test/                    # ujian pada peranti/emulator (main balik sebenar)
android/app/build.gradle, android/app/src/main/AndroidManifest.xml
```

## Pangkalan data JSON jauh

URL (cabang `main`):

```
https://raw.githubusercontent.com/cdsouthernjhr-gif/RadioM/main/data/malaysia_radio.json
https://raw.githubusercontent.com/cdsouthernjhr-gif/RadioM/main/data/version.json
```

> Fail ini berada di cabang pembangunan sehingga digabungkan ke `main`. Sebelum itu aplikasi
> menggunakan salinan terbina (`assets/data`) dan memaparkan "Gagal memuat turun… data tempatan dikekalkan".

Aliran: muat `cache` → atau `assets` (yang lebih baharu) → semak `version.json` (automatik setiap
12 jam atau manual) → muat turun penuh hanya jika versi lebih tinggi (ETag sebagai sandaran) →
sahkan skema → tulis atomik ke cache. Jika muat turun gagal, **data tempatan tidak dipadam**.
Skema: [`docs/json-schema.md`](docs/json-schema.md).

### Mengemas kini stesen

```bash
# 1. Sunting tool/stations_source.py
# 2. Uji strim (perlu ffmpeg) — atau jalankan workflow "verify-streams" di GitHub Actions
python3 tool/verify_streams.py
# 3. Jana pangkalan data (versi dinaikkan automatik) + salinan assets + version.json
python3 tool/build_db.py
```

`stream_type` diterbitkan **hanya** daripada keputusan ujian: `direct` jika sekurang-kurangnya satu
strim berjaya dinyahkod, `unverified` jika belum diuji, `web_player` jika tiada strim yang lulus
tetapi laman rasmi wujud. Tiada scraping, tiada pengekstrakan token, tiada pintasan sekatan penyiar.

## Logo sendiri, volum & bisu, Android TV

* **Logo sendiri:** pemain penuh → ikon gambar (atau tekan lama stesen dalam Direktori / Kegemaran).
  Pilih gambar dari peranti, atau masukkan **URL gambar** (berguna pada TV box tanpa galeri). Logo
  disimpan dalam folder peribadi aplikasi dan juga dipaparkan pada notifikasi / skrin kunci.
  **Padam logo sendiri** mengembalikan logo asal; **Tetapan → Padam semua logo sendiri** membuang semuanya.
  Gambar disahkan: hanya PNG/JPG/GIF/WebP (dikesan daripada bait fail), maksimum 3 MB, mesti boleh
  dinyahkod; URL hanya `http`/`https`.
* **Volum:** butang **kuatkan / perlahankan** (langkah 10%), slider dan peratus dalam pemain penuh;
  butang **bisu** dalam pemain penuh dan pemain mini. Bisu mengekalkan aras volum dan memulihkannya.
  Volum di sini ialah volum aplikasi; butang volum alat kawalan jauh / telefon masih mengawal volum sistem.
* **Android TV / TV box:** tekan stesen yang sedang dimainkan sekali lagi (butang OK) untuk membuka
  **pemain penuh** (logo, info lagu, volum). Sebelum ini tekanan kedua memulakan semula strim.

## Info lagu (RDS untuk radio internet)

RDS (Radio Data System) sebenar dihantar dalam isyarat **FM** dan hanya boleh dibaca oleh cip penerima
FM. Aplikasi ini memainkan **strim internet**, jadi ia menggunakan padanan RDS bagi strim tersebut:

| RDS (FM) | Padanan strim internet | Paparan dalam aplikasi |
|---|---|---|
| PS (nama stesen) | Nama stesen daripada pangkalan data | Tajuk pemain |
| RT (RadioText: artis – lagu) | Metadata ICY `StreamTitle` (Icecast/Shoutcast) | Panel **"Kini bersiaran"** dalam pemain penuh, baris kedua dalam pemain mini, notifikasi dan skrin kunci |

* Teks `Artis - Lagu` dipecahkan kepada lagu (baris 1) dan artis (baris 2), seperti paparan RDS kereta.
* Teks daripada pelayan dianggap **tidak dipercayai**: aksara kawalan dan aksara arah teks dibuang,
  ruang dirapatkan, panjang dihadkan (160 aksara), dan nilai kosong seperti `Unknown`, `-`, `Iklan`, URL
  atau nama stesen yang diulang diabaikan. Teks hanya dipaparkan sebagai teks biasa.
* Boleh dimatikan: **Tetapan → Papar info lagu (RDS)**.
* **Diuji pada emulator Android 6.0 (CI, 2026-11-15)** — keputusan sebenar:

  | Jenis strim | Contoh | Info lagu diterima | Teks yang diterima | Tajuk notifikasi |
  |---|---|---|---|---|
  | Icecast HTTP | KCFM | ✅ Ya | `Jubin Nautiyal - Humnava Mere` | `Humnava Mere` |
  | revma AAC (Astro) | HITZ | ✅ Ya | `Doechii, Lady Gaga - Runway` | `Runway` |
  | revma HLS (Astro) | MY | ❌ Tidak | – | nama stesen |
  | StreamTheWorld MP3 (RTM) | Nasional FM | ❌ Tidak | – | nama stesen |

* **Had:** hanya strim yang membawa metadata ICY memaparkan info lagu. Strim RTM (StreamTheWorld) dan
  HLS tidak menghantarnya dalam ujian ini, jadi aplikasi hanya memaparkan nama stesen (tiada teks
  rekaan). Metadata ID3 dalam HLS belum disokong, dan ciri RDS lain (TP/TA, AF, jam) tidak berkenaan
  untuk strim internet.

## Resolver strim

| Jenis | Pengesanan | Tindakan |
|---|---|---|
| Direct audio (MP3/AAC/AAC+) | sambungan fail / `format` / `Content-Type: audio/*` | `ProgressiveAudioSource` |
| HLS | `.m3u8` / `application/vnd.apple.mpegurl` | `HlsAudioSource` |
| Playlist PLS/M3U | `.pls`, `.m3u`, `audio/x-scpls` | URL http(s) pertama diekstrak |
| Laman web / HTML | `.html` / `text/html` | **tidak dimainkan**; buka pelayar luaran |
| Belum disahkan | `stream_type: unverified` | amaran dipaparkan sebelum cubaan |

## Membina

Keperluan: Flutter 3.24.5, JDK 17, Android SDK (platform 34, build-tools 34).

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release                    # APK universal (ARM32 + ARM64 + x86_64)
flutter build apk --release --split-per-abi    # APK lebih kecil per ABI
```

Output: `build/app/outputs/flutter-apk/app-release.apk` (dan `app-armeabi-v7a-release.apk`,
`app-arm64-v8a-release.apk`, `app-x86_64-release.apk`).

Tandatangan: tanpa `android/key.properties`, APK release ditandatangani dengan kunci debug (boleh
dipasang untuk ujian). Untuk edaran, cipta keystore dan `android/key.properties`
(lihat komen dalam `android/app/build.gradle`). **Jangan commit keystore/kata laluan.**

### CI (GitHub Actions)

* `android-build-and-test` — analyze, test, build APK (universal + split), periksa `minSdkVersion`
  dengan `aapt2`, kemudian pasang & uji pada **emulator Android 6.0 (API 23) x86_64**:
  pemasangan, pelancaran, main balik MP3/AAC/HLS/HTTP sebenar, latar belakang (HOME),
  putus & sambung semula rangkaian. APK dimuat naik sebagai artifact `apk-release`.
* `verify-streams` — menyahkod setiap URL strim dengan ffmpeg (mingguan + bila senarai berubah).
* `discover-stations` — senarai calon daripada radio-browser.info (data komuniti, perlu disahkan).

## Ujian

| # | Ujian | Lokasi |
|---|---|---|
| 1 | JSON parsing | `test/unit/json_service_test.dart` |
| 2 | Schema validation | `test/unit/json_service_test.dart` |
| 3 | Download database | `test/unit/download_service_test.dart` |
| 4 | Offline database | `test/unit/repository_test.dart`, `test/integration/data_flow_test.dart` |
| 5 | Version comparison | `test/unit/version_utils_test.dart` |
| 6–8 | MP3 / AAC / HLS playback | `integration_test/playback_test.dart` (peranti/emulator) |
| 9–10 | Network disconnect / reconnect | `integration_test/playback_test.dart` + `tool/ci_emulator.sh` |
| 11 | Background playback | `integration_test/playback_test.dart` (HOME ditekan oleh skrip hos) |
| 12 | Android TV remote navigation | `test/widget/tv_navigation_test.dart` |
| 13 | Android 6.0 installation | `tool/ci_emulator.sh` (emulator API 23) |
| 14 | ARM32/ARM64 build | `flutter build apk --split-per-abi` dalam CI |
| – | Resolver, URL, carian, kegemaran, UI | `test/unit/*`, `test/widget/*` |

Jalankan ujian peranti secara manual:

```bash
flutter test integration_test/playback_test.dart -d <device-id>
```

## Keselamatan

* Tiada token/kata laluan dalam kod atau JSON. Tiada maklumat sensitif disimpan.
* Hanya URL `http`/`https`; URL dengan kelayakan terbenam ditolak; HTML tidak pernah dimainkan.
* Pengesahan sijil TLS tidak pernah dimatikan (tiada `badCertificateCallback`, tiada TrustManager "trust-all").
* Timeout 15 s, cubaan semula dengan backoff eksponen (JSON: 3×; strim: sehingga 8×, maks 30 s).
* `allowBackup="false"`.

## Laporan akhir

Keputusan daripada GitHub Actions (larian `android-build-and-test` #43677788447 pada commit `312e139`,
dan `verify-streams` #43677788430). Semua nombor di bawah diambil daripada log CI, bukan anggaran.

### Toolchain & binaan

| Perkara | Keputusan |
|---|---|
| Flutter SDK / Dart | 3.24.5 (stable) / 3.5.4 |
| minSdkVersion / targetSdk / compileSdk | **23** / 34 / 34 — disahkan dengan `aapt2` pada setiap APK (`minSdk=23 OK`) |
| `flutter analyze` | Tiada isu |
| `flutter test` | **57/57 lulus** |
| `flutter build apk --release` | Berjaya |
| APK universal (armeabi-v7a + arm64-v8a + x86_64) | 51,477,965 bait (~51.5 MB) |
| APK armeabi-v7a (ARM32) | 16,073,132 bait (~16.1 MB) |
| APK arm64-v8a (ARM64) | 18,647,247 bait (~18.6 MB) |
| APK x86_64 | 19,766,106 bait (~19.8 MB) |
| Lokasi APK | **GitHub Release [v1.0.0](https://github.com/cdsouthernjhr-gif/RadioM/releases/tag/v1.0.0)** (muat turun terus, dengan `SHA256SUMS.txt`); juga artifact Actions `apk-release` |
| Tandatangan | Kunci *debug* kecuali `android/key.properties` disediakan (lihat [Membina](#membina)) |

Versi kebergantungan: lihat jadual [Kebergantungan](#kebergantungan-dipin-dalam-pubspecyaml-transitif-dikunci-dalam-pubspeclock).

### Ujian pada Android 6.0 (API 23)

> **Penting:** diuji pada **emulator** Android 6.0 (API 23, `google_apis`, x86_64) dalam CI —
> **bukan peranti fizikal**. Ujian pada telefon / TV box Android 6.0 sebenar (ARM) masih perlu dibuat
> sebelum dakwaan keserasian penuh. APK ARM32/ARM64 dibina dan diperiksa, tetapi tidak dijalankan
> pada perkakasan ARM.

| Ujian | Keputusan | Bukti |
|---|---|---|
| Pemasangan APK release | ✅ LULUS | `INSTALL=PASS` |
| Pelancaran (aktiviti di hadapan, tiada crash) | ✅ LULUS | `LAUNCH_FOREGROUND=PASS`, `LAUNCH_CRASH=NO` |
| Pangkalan data dimuat | ✅ LULUS | 65 stesen dimuat (DB terbundel v2 dalam APK yang diuji) |
| MP3 (Nasional FM, HTTPS StreamTheWorld) | ✅ LULUS | `playing`, stabil 10 s |
| AAC (TraXX FM, HTTPS StreamTheWorld) | ✅ LULUS | `playing`, stabil |
| AAC HTTPS (HITZ, revma CDN) | ✅ LULUS | `playing`, stabil |
| HLS HTTPS (MY, revma CDN) | ✅ LULUS | `playing`, stabil |
| HLS HTTP / AAC HTTP (fallback revma) | ✅ LULUS | `playing`, stabil |
| HTTP Icecast cleartext (KCFM) | ✅ LULUS | `playing`, stabil |
| Fallback strim penuh stesen (HITZ) | ✅ LULUS | `playing` |
| Logo HTTPS (trust store Android 6) | ✅ LULUS | 5/5 dimuat |
| Background playback (HOME ditekan oleh skrip hos) | ✅ LULUS | `wentBackground=true lifecycle=paused`, audio kekal `playing` 20 s |
| Rangkaian terputus → sambung semula | ✅ LULUS | ping selepas OFF: 100% hilang; status `offline` → `playing` secara automatik |
| Info lagu (RDS/ICY) | ✅ LULUS | Icecast & revma AAC menghantar info lagu dan notifikasi dikemas kini; HLS & StreamTheWorld tiada metadata |
| Jumlah ujian integrasi | **13/13 lulus** | `All tests passed!` (larian #43689363793) |
| Navigasi alat kawalan jauh TV (D-pad) | ✅ LULUS (ujian widget hos) | `test/widget/tv_navigation_test.dart` — bukan pada peranti TV sebenar |

### Stesen & strim

| Perkara | Jumlah |
|---|---|
| Stesen dalam pangkalan data (v3) | **65** |
| Stesen `direct` (sekurang-kurangnya satu strim disahkan) | **61** |
| Stesen `web_player` (tiada strim disahkan → buka pemain rasmi) | **4** |
| URL strim keseluruhan | 117 |
| URL disahkan (ffmpeg nyahkod ≥ 6 s audio sebenar) | **112** |
| URL gagal | **5** |
| URL belum diuji | 0 |

URL yang gagal dan sebabnya (pemeriksaan CI 2026-11-15):

| Stesen | URL | Sebab |
|---|---|---|
| Minnal FM | `…/livestream-redirect/MINNAL_FM.mp3` | HTTP 404 (StreamTheWorld) |
| Perak FM | `…/livestream-redirect/PERAK_FM.mp3` | HTTP 404 |
| Sibu FM | `…/livestream-redirect/SIBU_FM.mp3` | HTTP 404 → stesen kini `web_player` |
| Terengganu FM | `…/livestream-redirect/TERENGGANU_FM.mp3` | HTTP 404 |
| Terengganu FM | `…/livestream-redirect/TERENGGANU_FMAAC_SC` | HTTP 404 → stesen kini `web_player` |

Minnal FM dan Perak FM masih `direct` kerana strim AAC mereka disahkan. ERA dan GEGAR ialah
`web_player` kerana tiada strim langsung rasmi yang disahkan.

### Had yang diketahui

* Diuji pada emulator API 23, bukan peranti fizikal Android 6.0 / TV box ARM.
* Pengesahan strim dibuat dari pelayan CI di luar Malaysia; strim yang disekat geografi mungkin
  berkelakuan berbeza di Malaysia (dan sebaliknya).
* URL pangkalan data jauh menunjuk ke cawangan `main`; sehingga cawangan ini digabungkan, aplikasi
  menggunakan DB terbundel (fallback berfungsi seperti direka).
* Status strim berubah dari masa ke masa — `verify-streams` dijalankan setiap minggu dan
  mengemas kini `stream_type` secara automatik.
