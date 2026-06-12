# BrailleVision — Integration Guide
> Untuk: Integration Engineer / ML Engineer  
> Dari: Mobile Front-End Developer

Dokumen ini menjelaskan semua **injection point** yang telah disiapkan agar logika ML/backend dapat dihubungkan ke UI tanpa perlu menyentuh kode tampilan.

---

## Struktur Direktori

```
lib/
├── core/
│   ├── constants/app_constants.dart      # Konstanta global (timing, TTS config)
│   └── theme/app_theme.dart              # Warna, font, tema
│
└── features/
    └── scanner/
        ├── scanner.dart                  # Barrel export (import dari sini saja)
        ├── services/
        │   ├── camera_service.dart       # ⭐ INJECTION POINT UTAMA (frame stream)
        │   └── tts_service.dart          # TTS lifecycle
        ├── providers/
        │   └── scanner_provider.dart     # ⭐ State management (Riverpod)
        └── presentation/
            ├── screens/scanner_screen.dart
            └── widgets/
                ├── viewfinder_overlay.dart   # Animasi kotak pemindai
                ├── result_panel.dart          # Area hasil terjemahan
                └── permission_gate.dart       # UI izin kamera
```

---

## Injection Point 1 — Frame Processing (CameraService)

**File:** `lib/features/scanner/services/camera_service.dart`

Di dalam method `startStream()`, tambahkan logika ML Anda di zona yang ditandai:

```dart
await _controller!.startImageStream((CameraImage frame) {
  // ── BEGIN INTEGRATION ZONE ──────────────────────────────
  
  // 1. Konversi frame (YUV420 → RGB/Grayscale)
  final inputTensor = convertYuv420ToRgb(frame);
  
  // 2. Jalankan inferensi model
  final result = await myBrailleModel.runInference(inputTensor);
  
  // 3. Push hasil ke UI melalui callback
  onFrameResult?.call(
    translatedText: result.decodedText,
    state: result.confidence > 0.85
        ? DetectionState.detected
        : DetectionState.detecting,
  );
  
  // ── END INTEGRATION ZONE ────────────────────────────────
});
```

---

## Injection Point 2 — Push Hasil dari Luar (ScannerProvider)

**File:** `lib/features/scanner/providers/scanner_provider.dart`

Jika pipeline ML berjalan di service terpisah, panggil method public ini langsung:

```dart
// Dari mana saja yang punya akses ke Riverpod ref:
ref.read(scannerProvider.notifier).updateTranslation(
  'Teks hasil terjemahan Braille.',
  DetectionState.detected,
);
```

### DetectionState enum:

| Value | Warna Viewfinder | Kapan Digunakan |
|-------|-----------------|-----------------|
| `DetectionState.idle` | Putih | Tidak ada dokumen |
| `DetectionState.detecting` | Kuning/Amber | Dokumen terdeteksi, sedang diproses |
| `DetectionState.detected` | Hijau/Teal | Terjemahan selesai & berhasil |

---

## Injection Point 3 — TTS Language (Multi-bahasa)

**File:** `lib/features/scanner/services/tts_service.dart`

Jika model mendeteksi bahasa dokumen, ubah bahasa TTS secara dinamis:

```dart
// Akses via provider
final ttsService = ref.read(scannerProvider.notifier)._ttsService;
await ttsService.setLanguage('en-US'); // atau 'id-ID'
```

---

## Mock Section (Hapus Setelah Integrasi)

Di `scanner_screen.dart`, terdapat widget `_MockControlBar` yang menampilkan tombol **SIMULASI DETEKSI** dan **RESET**. Widget ini hanya untuk pengujian UI — **hapus atau sembunyikan** setelah pipeline ML terhubung:

```dart
// Cari dan hapus/comment bagian ini di scanner_screen.dart:
// ── MOCK DETECTION BUTTON (for UI testing) ──────
_MockControlBar(...)
// ── END MOCK SECTION ────────────────────────────
```

---

## Checklist Integrasi

- [x] Tambahkan TFLite dependency ke `pubspec.yaml` (`tflite_flutter`)
- [x] Implementasi konversi `CameraImage` (YUV420 → grayscale) — `pipeline/yuv_converter.dart`
- [x] Isi zona integrasi di `CameraService.startStream()` (frame-skipping + busy-guard)
- [x] `DetectionState` transitions (idle → detecting → detected) digerakkan oleh pipeline
- [x] Throttle frame: frame-skipping ~6 FPS + busy-guard (drop frame saat inferensi berjalan)
- [x] Hapus `_MockControlBar` dari `scanner_screen.dart`
- [ ] Update bahasa TTS sesuai kebutuhan multi-bahasa (opsional — `TtsService.setLanguage`)

---

## ✅ Integrasi Terpasang (Integration Engineer)

Pipeline penuh **DIP → ML → Temporal Voting** sesuai PRD §6 sudah terhubung.
Semua modul ada di `lib/features/scanner/pipeline/`:

```
CameraImage (YUV420)
  → [CameraService] frame-skipping (skip 4, ~6 FPS) + busy-guard
  → [YuvConverter]  Y-plane → grayscale upright (rotasi sesuai sensor)
  → [GrayImage]     center-crop ROI + scale ke tinggi kerja
  → [BraillePreprocessor]  Gaussian blur → adaptive threshold → erode/dilate  (biner)
  → [BrailleSegmenter]     Horizontal/Vertical Projection Profile → bbox sel
  → [BrailleClassifier]    TFLite (64×64×3, grayscale /255) → huruf + confidence
  → [TemporalVoter]        voting per-posisi (5 frame, mayoritas) → teks stabil
  → ScannerProvider.state  → UI + auto-TTS (debounce)
```

**Parameter tuning** ada di `core/constants/app_constants.dart`
(`frameSkipCount`, `votingWindowSize`, `votingMinAgreement`, `minCellConfidence`,
`roiWidthFactor/HeightFactor`, `thresh*`, `seg*`).

### Catatan penting untuk tim
1. **Model input = 64×64×3** (bukan 224). Custom CNN, output softmax A–Z.
   Model yang dipakai: `braille_vision_f16_synth.tflite` (disalin ke `assets/models/`).
2. **Preprocessing klasifikasi = grayscale mentah `/255`** agar cocok dengan cara
   model dilatih (`load_and_preprocess`). Hasil **biner** dari modul DIP **hanya**
   dipakai untuk *segmentasi* (mencari posisi sel), bukan untuk diumpankan ke model.
   → Jika tim ML melatih ulang model pada citra biner, ubah `BrailleClassifier`
   agar memakai `BraillePreprocessor`.
3. **Optimasi lanjutan (belum):** inferensi berjalan di main isolate. Untuk perangkat
   low-end, pindahkan pipeline ke `Isolate` / `IsolateInterpreter` bila terasa nge-lag.
4. **Segmentasi multi-huruf** mengikuti notebook CV (projection profile); parameter
   `seg*` mungkin perlu di-tuning pada kondisi kamera nyata.
