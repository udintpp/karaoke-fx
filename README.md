# Karaoke FX 🎤🎵

Aplikasi karaoke profesional berbasis Flutter dengan **efek audio terpisah** untuk Mikrofon dan Media.

## ✨ Fitur Utama

### 🎤 Microphone FX (Real-time Vocal Effects)
| Efek | Parameter |
|------|-----------|
| **Echo / Delay** | Delay Time, Feedback, Wet Mix |
| **Reverb** | Room Size, Damping, Wet Mix |
| **Pitch Shift** | ±12 semitones |
| **Chorus** | Depth, Rate, Wet Mix |
| **Noise Gate** | Threshold |
| **Compressor** | Threshold, Ratio |
| **3-Band EQ** | Bass, Mid, Treble |
| **Input Gain** | 0x – 2x |

### 🎵 Media FX (Background Music)
| Efek | Parameter |
|------|-----------|
| **5-Band EQ** | 60Hz, 250Hz, 1kHz, 4kHz, 12kHz |
| **Bass Boost** | Strength 0-100 |
| **Stereo Widener** | Width 0-2x |
| **Room Reverb** | Wet Mix |
| **Speed** | 0.5x – 2.0x |
| **Pitch** | 0.5x – 2.0x |

### 🎭 Presets Vokal (9 presets)
- Dry (No FX) • Studio Vocal • Concert Hall
- Karaoke Club • Megaphone • Robot • Deep Voice
- Helium • Bathroom

## 🏗️ Tech Stack
- **Flutter 3.24+** (Dart)
- `flutter_sound` — Mic recording & monitoring
- `just_audio` — Media playback
- `audio_session` — Audio routing
- `provider` — State management
- `flutter_animate` — Animations
- `google_fonts` — Poppins font

## 🚀 Build Online (GitHub Actions)

1. Push ke GitHub → otomatis build APK
2. Buka tab **Actions** di GitHub
3. Download artifact `karaoke-fx-debug-apk`

## 📱 Permissions
- `RECORD_AUDIO` — Akses mikrofon
- `MODIFY_AUDIO_SETTINGS` — Routing audio
- `READ_MEDIA_AUDIO` — Buka file musik
- `FOREGROUND_SERVICE` — Background audio

## 🗂️ Struktur Project
```
lib/
├── main.dart
├── theme/
│   └── app_theme.dart
├── models/
│   └── fx_settings.dart
├── providers/
│   ├── mic_fx_provider.dart
│   └── media_fx_provider.dart
├── screens/
│   ├── home_screen.dart
│   ├── mic_fx_screen.dart
│   └── media_fx_screen.dart
└── widgets/
    ├── fx_slider.dart
    ├── fx_toggle_card.dart
    ├── vu_meter.dart
    ├── preset_chips.dart
    └── media_player_card.dart
```
