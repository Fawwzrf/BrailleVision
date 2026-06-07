// lib/features/scanner/scanner.dart
//
// ─── Barrel Export — Scanner Feature ─────────────────────────
//
// Import seluruh layer scanner cukup dari satu baris:
//   import 'package:braillevision/features/scanner/scanner.dart';
//
// LAYER OVERVIEW:
//
//  ┌─────────────────────────────────────────────┐
//  │  PRESENTATION (UI hanya, tanpa logika)      │
//  │  ├── ScannerScreen       (halaman utama)    │
//  │  ├── ViewfinderOverlay   (kotak pemindai)   │
//  │  ├── ResultPanel         (area terjemahan)  │
//  │  └── PermissionGate      (UI izin kamera)   │
//  ├─────────────────────────────────────────────┤
//  │  PROVIDERS (state management — Riverpod)    │
//  │  ├── ScannerState        (data model)       │
//  │  ├── ScannerNotifier     (business logic)   │
//  │  └── scannerProvider     (provider instance)│
//  ├─────────────────────────────────────────────┤
//  │  SERVICES (I/O & platform channels)         │
//  │  ├── CameraService  + FrameResultCallback   │
//  │  ├── DetectionState (idle/detecting/detect) │
//  │  └── TtsService     + TtsState              │
//  └─────────────────────────────────────────────┘

// ─── Presentation ─────────────────────────────────────────────
export 'presentation/screens/scanner_screen.dart'
    show ScannerScreen;

export 'presentation/widgets/viewfinder_overlay.dart'
    show ViewfinderOverlay;

export 'presentation/widgets/result_panel.dart'
    show ResultPanel;

export 'presentation/widgets/permission_gate.dart'
    show PermissionGate;

// ─── Providers ────────────────────────────────────────────────
export 'providers/scanner_provider.dart'
    show
        ScannerState,
        ScannerNotifier,
        scannerProvider;

// ─── Services ─────────────────────────────────────────────────
export 'services/camera_service.dart'
    show
        CameraService,
        DetectionState,
        FrameResultCallback;

export 'services/tts_service.dart'
    show
        TtsService,
        TtsState;
