# BrailleVision — Catatan Integrasi (Progress Sementara)

> **Penulis:** Integration & Optimization Engineer (Anggota 5)
> **Tanggal:** 2026-06-12
> **Status:** Pipeline DIP + ML + Temporal Voting sudah terhubung dan **berjalan di perangkat** (Samsung Galaxy A55). Akurasi deteksi **masih dalam tahap tuning** (lihat §10).

Dokumen ini menjelaskan secara detail apa yang **ditambahkan**, apa yang **diubah**, perbaikan **toolchain build**, keputusan arsitektur, dan catatan penting agar seluruh tim paham kondisi terkini sebelum refactor lanjutan.

---

## 1. Ringkasan

Seluruh modul kini tersambung menjadi satu alur real-time sesuai PRD §6:

```
Kamera (Flutter)
  → frame-skipping (~6 FPS) + busy-guard          [CameraService]
  → Y-plane → grayscale tegak (rotasi sensor)      [YuvConverter]
  → crop ROI tengah + skala ke tinggi kerja         [GrayImage]
  → binarisasi sadar-polaritas                      [BraillePreprocessor]
      (Gaussian blur → adaptive threshold → morfologi)
  → deteksi titik (blob) + rekonstruksi grid braille [BrailleGridDecoder]
      → baca pola 6-titik per sel
      → decode via tabel pola (deterministik)        [BrailleAlphabet]
  → (pembanding) render sel bersih → klasifikasi      [BrailleClassifier + TFLite]
  → Temporal Voting (stabilkan antar frame)          [TemporalVoter]
  → tampilkan teks + auto-TTS                        [ScannerProvider → UI]
```

> **Catatan arsitektur:** awalnya segmentasi memakai *projection profile* (port dari notebook CV). Setelah uji di perangkat, metode itu **gagal mengisolasi sel braille** (lihat §6), sehingga diganti dengan **deteksi titik + rekonstruksi grid + decode tabel**. File projection-profile lama (`braille_segmenter.dart`) **masih ada tetapi tidak dipakai** (legacy/arsip).

---

## 2. File yang DITAMBAHKAN

Semua modul pipeline ada di `flutterapp/lib/features/scanner/pipeline/`:

| File | Penjelasan |
|------|-----------|
| `gray_image.dart` | Tipe citra grayscale 8-bit ringan (hand-rolled, tanpa package eksternal) + operasi: `rotate`, `cropCenter`, `crop`, `resize` (bilinear), `scaledToHeight`, `inverted`, `framedSquare`, `mean`. Dipakai di semua tahap DIP. |
| `yuv_converter.dart` | Konversi `CameraImage` → `GrayImage` tegak. Untuk YUV420 (Android), plane Y **sudah** luminance → grayscale nyaris gratis. Mendukung BGRA (iOS) juga. Rotasi mengikuti `sensorOrientation`. |
| `braille_preprocessor.dart` | **Port modul DIP** (notebook CV Engineer): Gaussian blur 3×3 → adaptive threshold (integral image) → erosi + dilasi. **Sadar-polaritas**: memastikan titik selalu jadi foreground (255), baik titik gelap-di-terang maupun terang-di-gelap. Output biner untuk segmentasi. |
| `braille_segmenter.dart` | *(LEGACY, tidak dipakai)* Segmentasi projection profile (Horizontal/Vertical Projection Profile). Disimpan sebagai arsip metode lama. |
| `braille_alphabet.dart` | **Tabel pola braille** (sumber: `synthetic_data_generation.ipynb`). Map huruf A–Z → pola 6-titik `[d1..d6]`, plus fungsi `decode(pola) → huruf`. Penomoran sel: `1 4 / 2 5 / 3 6`. |
| `braille_grid_decoder.dart` | **INTI CV BARU.** Langkah: (1) connected-component labeling untuk deteksi tiap titik, (2) estimasi pitch titik `a` (median jarak tetangga terdekat), (3) pisah baris teks via gap vertikal, (4) per baris: anchor baris-atas, urut titik kiri→kanan, kelompokkan jadi sel via gap horizontal, snap tiap titik ke slot (kolom, baris), (5) baca pola 6-titik → decode tabel. Juga punya `renderCleanCell(pola)` untuk merender sel bersih 64×64 (titik gelap di latar terang, posisi seperti data training) sebagai pembanding model. |
| `braille_classifier.dart` | Wrapper TFLite. Memuat model + label map. `classify()` (normalisasi polaritas + framing) dan `classifyDirect()` (untuk sel ter-render bersih, tanpa framing ulang). Input model: `(1,64,64,3)` float32 ternormalisasi `/255`. |
| `temporal_voter.dart` | **Temporal Voting** (PRD §6, §7.3). Buffer N prediksi terakhir, voting **per-posisi karakter** (mayoritas), karakter baru dipancarkan hanya bila menang ≥ `votingMinAgreement` suara → teks tidak berkedip saat tangan goyang. |
| `braille_pipeline.dart` | **Orchestrator.** Menjalankan seluruh rantai per frame, mengembalikan `PipelineResult { text, state, confidence, debug }`. |

**Aset baru:**
| Path | Isi |
|------|-----|
| `flutterapp/assets/models/braille_vision.tflite` | Model TFLite final (`braille_vision_f16_synth.tflite`, ~1.3 MB) yang disalin dari `ml_pipeline/`. |
| `flutterapp/assets/models/label_map.json` | Pemetaan indeks → huruf (A–Z). |

**Dokumentasi baru:**
| Path | Isi |
|------|-----|
| `INTEGRATION_PROGRESS.md` | Dokumen ini. |

---

## 3. File yang DIUBAH

### Kode aplikasi (`flutterapp/lib/`)
| File | Perubahan |
|------|-----------|
| `core/constants/app_constants.dart` | **Banyak konstanta baru** (lihat §8). Yang penting: `modelInputWidth/Height` **224 → 64** (perbaikan: model butuh 64×64, bukan 224), path model, parameter frame-skip, voting, ROI, threshold, parameter grid decoder, debug flag, auto-TTS. |
| `features/scanner/services/camera_service.dart` | **Frame-skipping + busy-guard** ditambahkan di `startStream()`: hanya ~1 dari (`frameSkipCount`+1) frame diproses (~6 FPS), dan frame baru di-*drop* selama frame sebelumnya masih diproses (cegah overheat). Callback lama `onFrameResult` (hasil jadi) diganti `onFrameAvailable` (frame mentah). Tambah getter `rotationQuarterTurns` (dari `sensorOrientation`). |
| `features/scanner/providers/scanner_provider.dart` | Wiring pipeline: muat model saat init, jalankan pipeline tiap frame, dorong hasil ber-voting ke state. **Auto-TTS** (debounce) ditambahkan. Mock detection dihapus. State `debugInfo` ditambahkan. |
| `features/scanner/presentation/screens/scanner_screen.dart` | Hapus `_MockControlBar`. Tambah **overlay debug** (jumlah sel + huruf + confidence) yang aktif bila `debugOverlayEnabled`. |
| `features/scanner/scanner.dart` | Barrel export diperbarui: `FrameResultCallback` → `RawFrameCallback`; ekspor `BraillePipeline`, `PipelineResult`. |
| `lib/INTEGRATION_GUIDE.md` | Checklist integrasi ditandai selesai + dokumentasi arsitektur. |

### Dependency
| File | Perubahan |
|------|-----------|
| `pubspec.yaml` | Tambah `tflite_flutter: ^0.11.0`. Daftarkan `assets/models/`. |
| `pubspec.lock` | Hasil `flutter pub get`. |

### Konfigurasi Android — lihat §4 (penting).

> Catatan: file `linux/`, `macos/`, `windows/` generated-plugin-registrant ikut berubah otomatis karena penambahan plugin (file generated, tidak perlu diedit manual).

---

## 4. Perbaikan Toolchain Build (WAJIB DIBACA TIM)

Saat pertama `flutter run`, build gagal dengan error `unable to resolve class groovy.xml.QName`. **Penyebab:** folder `android/` ter-scaffold dengan versi build-tool yang **terlalu baru** untuk Flutter yang terpasang (**Flutter 3.24.2**). Diturunkan agar selaras:

| Komponen | Sebelum (rusak) | Sesudah (jalan) | File |
|----------|-----------------|-----------------|------|
| Gradle | 9.1.0 | **8.7** | `android/gradle/wrapper/gradle-wrapper.properties` |
| Android Gradle Plugin | 9.0.1 | **8.6.0** | `android/settings.gradle.kts` |
| Kotlin | 2.3.20 | **2.2.20** | `android/settings.gradle.kts` |
| `kotlin{compilerOptions}` DSL | (gaya baru) | `kotlinOptions{jvmTarget="17"}` + `id("org.jetbrains.kotlin.android")` | `android/app/build.gradle.kts` |
| `minSdk` | 21 | **24** (dibutuhkan `flutter_tts`) | `android/app/build.gradle.kts` |
| `compileSdk` | flutter default (34) | **35** | `android/app/build.gradle.kts` |
| `ndkVersion` | flutter default (23) | **26.1.10909125** (plugin native: tflite, camerax) | `android/app/build.gradle.kts` |
| flag `android.newDsl`/`builtInKotlin` | ada | dihapus; `jvmargs` 8G → 4G | `android/gradle.properties` |

Juga ditambahkan ke `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.hardware.camera" android:required="true"/>
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false"/>
```

> ⚠️ **PENTING:** Versi build-tool ini dipin ke Flutter **3.24.2**. Jika ada anggota tim memakai Flutter versi berbeda (mis. 2025), file Gradle ini bisa jadi sumber konflik. **Samakan versi Flutter satu tim** (`flutter --version`).
>
> ℹ️ Saat build masih muncul warning `flutter_tts requires Android SDK 36` — ini **benign** (SDK backward-compatible). Sengaja **tidak** dinaikkan ke 36 agar AGP 8.6 tidak pecah.

---

## 5. Keputusan Arsitektur (Decisions Log)

1. **Model:** dipakai `braille_vision_f16_synth.tflite` (varian f16 + data sintesis). Float32 in/out → integrasi paling mudah, akurasi penuh, lebih robust untuk kondisi nyata dibanding varian int8/kaggle-saja.
2. **Input model = 64×64×3, titik GELAP di latar TERANG, satu sel braille terpusat** (bukti dari `synthetic_data_generation.ipynb`). Bukan 224×224 seperti yang sempat tertulis di konstanta.
3. **Metode decode = tabel pola braille (deterministik)** sebagai sumber kebenaran utama; model TFLite tetap dijalankan pada sel ter-render bersih sebagai **pembanding** (ditampilkan di overlay debug). Alasan: classifier pada potongan kamera mentah sangat rapuh (lihat §6); decode via tabel jauh lebih andal dan tetap mempertahankan deliverable ML di laporan.
4. **Preprocessing klasifikasi = grayscale ternormalisasi**, bukan biner. Hasil biner DIP hanya untuk *menemukan lokasi titik* (segmentasi), bukan diumpankan ke model.

---

## 6. Mengapa CV diubah dari Projection Profile → Grid Decoder

Hasil uji perangkat (overlay debug) untuk teks "halo dunia" (9 huruf):
```
cells:4  H67 A72 J48 J44   → "HA"
```
- Segmentasi projection-profile **under-segment**: 9 huruf hanya jadi 4 "sel" → tiap sel berisi 2–3 karakter menyatu.
- Model **kolaps ke {H, A, J}** dengan confidence rendah pada input apa pun → tanda input di luar distribusi (bukan satu karakter bersih).

**Kesimpulan:** projection profile tidak bisa mengisolasi sel braille per karakter. Diganti deteksi titik + rekonstruksi grid (lattice braille) yang membaca pola 6-titik langsung. Kunci keandalan: **setiap huruf A–Z punya titik di kolom kiri**, jadi kolom paling-kiri tiap sel selalu = kolom kiri (tanpa ambiguitas).

---

## 7. Cara Menjalankan & Menguji

```powershell
# Pastikan device terdeteksi (USB debugging ON)
flutter devices
# Jalankan (debug = fungsi penuh, performa lebih lambat)
flutter run
# Untuk uji performa/termal (≈ kecepatan rilis)
flutter run --profile
```
- Saat dialog izin kamera muncul → **Allow**.
- Arahkan ke dokumen braille, pencahayaan 300–500 lux.
- **Overlay debug** (hijau, di atas kamera) menampilkan:
  ```
  cells:9  rule:HALODUNIA
  ml:H88 A92 L74 ...  →  "HALODUNIA"
  ```
  `rule:` = decode tabel (output utama), `ml:` = model pada sel ter-render, `cells:` = jumlah sel.
- Log yang sama juga tercetak di konsol (`[BraillePipeline] ...`).

> Untuk demo/produksi: set `debugOverlayEnabled = false` di `app_constants.dart`.

---

## 8. Parameter Tuning (`app_constants.dart`)

| Konstanta | Default | Fungsi |
|-----------|---------|--------|
| `frameSkipCount` | 4 | Lewati N frame per 1 yang diproses (~6 FPS) |
| `votingWindowSize` / `votingMinAgreement` | 5 / 2 | Jendela & ambang temporal voting |
| `roiWidthFactor` / `roiHeightFactor` | 0.80 / 0.55 | Area frame yang diproses (pusatkan ke braille saja) |
| `segmentWorkHeight` | 96 | Tinggi citra kerja sebelum deteksi |
| `threshBlockSize` / `threshC` / `morphKernelSize` | 11 / 2 / 2 | Parameter adaptive threshold & morfologi |
| `gridMinDotArea` / `gridMaxDotAreaFactor` | 2 / 8.0 | Filter ukuran blob titik |
| `gridCellGapFactor` | 1.2 | Gap-x > a×ini → sel baru (naikkan bila sel menyatu, turunkan bila 1 huruf terpecah) |
| `gridLineGapFactor` | 1.8 | Gap-y > a×ini → baris teks baru |
| `minCellConfidence` | 0.55 | Ambang confidence (dipakai jalur classifier lama) |
| `autoSpeakEnabled` / `autoSpeakDebounceMs` | true / 1200 | Auto-TTS |
| `debugOverlayEnabled` | true | Overlay & log debug |

---

## 9. Catatan & Caveat

- **Spasi antar kata BELUM dideteksi** → "halo dunia" keluar "HALODUNIA". Mudah ditambah (gap horizontal besar → spasi) setelah akurasi sel stabil.
- **Pitch tunggal** untuk baris & kolom (asumsi grid ~persegi; benar untuk braille nyata). Bila perangkat menunjukkan salah baris/kolom, pisahkan estimasi pitch horizontal & vertikal.
- **Inferensi di main isolate** — untuk HP low-end bisa di-*offload* ke `Isolate`/`IsolateInterpreter` bila terasa lag.
- **ROI** harus menangkap braille saja; bila ada teks cetak di sekitarnya (mis. kartu ucapan) bisa menambah blob noise.
- **Gap domain**: model dilatih pada citra sintetis bersih; foto kertas nyata berbeda. Karena output utama kini via tabel pola, ketergantungan pada akurasi model berkurang.

---

## 10. Status & Langkah Berikutnya (TODO)

- [ ] **Validasi akurasi grid decoder di perangkat** (sedang berjalan — butuh laporan overlay dari uji terbaru).
- [ ] Tuning `gridCellGapFactor` / ROI bila jumlah sel belum pas.
- [ ] Tambah **deteksi spasi** antar kata.
- [ ] (Opsional) pisah estimasi pitch horizontal/vertikal bila perlu.
- [ ] (Opsional) pindahkan pipeline ke Isolate untuk perangkat low-end.
- [ ] Matikan `debugOverlayEnabled` sebelum demo/rilis.
- [ ] Samakan versi Flutter seluruh anggota tim (3.24.2) untuk menghindari konflik Gradle.
