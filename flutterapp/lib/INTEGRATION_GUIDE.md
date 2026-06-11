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

- [ ] Tambahkan TFLite / OpenCV dependency ke `pubspec.yaml`
- [ ] Implementasi konversi `CameraImage` (YUV420 → format model)
- [ ] Isi zona integrasi di `CameraService.startStream()`
- [ ] Test `DetectionState` transitions (idle → detecting → detected)
- [ ] Pastikan `onFrameResult` tidak dipanggil terlalu sering (throttle jika perlu)
- [ ] Hapus `_MockControlBar` dari `scanner_screen.dart`
- [ ] Update bahasa TTS sesuai kebutuhan multi-bahasa (opsional)
