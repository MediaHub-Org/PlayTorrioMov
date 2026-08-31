# FVP / libmdk Optimization Guide
### Getting max performance, zero-lag playback, and crash-free stability across Android, iOS, Windows, macOS, and Linux

`fvp` is the Flutter plugin that wraps [libmdk](https://github.com/wang-bin/mdk-sdk) (by wang-bin, same author as MDK/QtAV) to replace or extend `video_player` on every desktop + mobile platform. Because it's a thin Dart/FFI layer over a native C++ engine, **almost all of your real performance tuning happens through decoder selection, renderer choice, and fallback chains** — not Dart code. This guide covers all of it.

---

## 1. Baseline Setup (do this first)

```dart
import 'package:fvp/fvp.dart' as fvp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  fvp.registerWith(); // registers fvp as the video_player backend
  runApp(const MyApp());
}
```

Notes:
- Since Flutter 3.27, `fvp` **must be a direct dependency** in your app's `pubspec.yaml` (not just transitive) or the plugin registration can silently fail.
- You can scope which platforms use `fvp` vs the official `video_player` implementation:
```dart
fvp.registerWith(options: {'platforms': ['windows', 'linux', 'macos']});
```
On Android/iOS the official `video_player` (ExoPlayer/AVPlayer) is already hardware-accelerated and stable, so many teams only use `fvp` where `video_player` has no native support (Windows/Linux), and optionally on macOS/iOS for the extra format/codec support. This alone reduces your crash surface, since you're only depending on libmdk where you must.

---

## 2. The #1 performance lever: decoder priority lists

libmdk tries decoders **in the order you give it**, falling back to the next one on failure. This is your single biggest lever for both performance *and* stability — a well-ordered list gets hardware acceleration when available and silently degrades instead of crashing when it isn't.

```dart
fvp.registerWith(options: {
  'video.decoders': [
    'D3D11',    // or MFT, VT, AMediaCodec, etc — platform specific, see below
    'FFmpeg',   // universal software fallback — ALWAYS keep this last
  ],
});
```

**Never ship a decoder list without `FFmpeg` as the final fallback.** It's the software decoder that works on every codec/container libmdk supports. Without it, an unsupported hardware path just fails and the video shows nothing (or your player crashes if you don't have error handling — see Section 6).

### Recommended lists per platform

| Platform | Recommended order | Why |
|---|---|---|
| **Windows** | `MFT:d3d=11`, `D3D11`, `FFmpeg` | MDK's own `MFT` implementation outperforms FFmpeg's D3D11VA path and supports more codecs (VP9/HEVC/AV1 via MS Store extensions). `D3D11` (FFmpeg's d3d11va) is a solid second. |
| **Windows (older/low-power HW)** | `MFT:d3d=12`, `MFT:d3d=11`, `FFmpeg` | `d3d=12` has meaningfully lower memory load (~1/4 less than `d3d=11`) and true 0-copy, but slightly less universally supported — that's why it's tried first, not alone. |
| **macOS / iOS** | `VT`, `FFmpeg` | `VT` is MDK's own VideoToolbox implementation — faster (async mode ~25% higher decode fps) and supports more pixel formats/codecs (10-bit H264, ProRes, ARM VP9) than ffmpeg's own `VideoToolbox` decoder. |
| **Android** | `AMediaCodec`, `FFmpeg` | MDK's own NDK-based MediaCodec wrapper, supports async decode + tunneled playback. Far better than ffmpeg's `MediaCodec` wrapper. |
| **Linux (desktop, Intel/AMD)** | `VAAPI`, `FFmpeg` | Standard hardware path on Linux. Needs `LIBVA_DRIVER_NAME` set correctly (see Section 5). |
| **Linux (NVIDIA)** | `CUDA`, `VDPAU`, `FFmpeg` | Prefer `CUDA` (MDK's own NVDEC wrapper) first, `VDPAU` as legacy fallback. |
| **Embedded Linux (Raspberry Pi)** | `V4L2M2M`, `FFmpeg` (with system ffmpeg ≥4.0, not the bundled one) | Needs the Pi's own ffmpeg build with v4l2 hw accel + DRM prime output; delete the bundled `libffmpeg.so` from the app bundle. |
| **Rockchip SBCs** | `rkmpp`, `FFmpeg` | Or the standalone `rockchip` decoder. Needs `ffmpeg-rockchip` build. |

### Setting decoder-specific properties
You can pass options inline in the decoder name string:
```dart
'video.decoders': ['MFT:d3d=11:copy=0', 'FFmpeg']
```
or globally for all decoders via `Player.setProperty`.

Key properties worth tuning:
- `copy=0` — avoid GPU→CPU memory copies wherever the property exists (`MFT`, `D3D11`, `CUDA`, `VT`, `VAAPI`, `AMediaCodec`). This is the single biggest win for **zero-copy rendering** — frames stay on the GPU from decode to display, which is where most of your "smoothness" comes from. Only set `copy=1`/`2` if you need CPU-side pixel access (e.g. custom filters).
- `threads=0` (FFmpeg-family) — uses `logical cores + 1`. Leave this default unless you're CPU-starved elsewhere in your app.
- `async=1` (`VT`, `AMediaCodec`) — enables async decoding, generally on by default and faster; don't turn it off unless you hit ordering bugs with B-frames.
- `sw_fallback` — leave at default (`0`) and rely on your **decoder list** for fallback instead of this flag; the docs explicitly note this is more reliable ("otherwise won't try the next decoder if failed").

---

## 3. Renderer / rendering pipeline

`fvp` auto-selects the optimal render backend per platform — you generally don't need to override this:

| Platform | Render API |
|---|---|
| Windows | Direct3D 11 |
| macOS / iOS | Metal |
| Linux | OpenGL |
| Android | OpenGL (Impeller-compatible) |

The performance-critical part isn't *which* API is used — it's whether you're getting a **zero-copy path** from decoder output to renderer input. That's controlled by the decoder `copy=0` properties above, plus (on Linux especially) `interop` settings for VAAPI (`x11`, `drm2`, `dri3`) which determine whether frames need a CPU round-trip or stay in GPU memory as a DRM-prime/EGL image.

On Linux with VAAPI, if you see high CPU usage despite "hardware decoding," check:
```
export LIBVA_DRIVER_NAME=i965   # or iHD for newer intel, radeonsi for amd, nvidia for nvidia-vaapi-driver
```
and ensure you called the equivalent of `SetGlobalOption("X11Display", ...)` — without it, 0-copy rendering can silently fail back to a slower path.

---

## 4. Reducing perceived lag: low latency & buffering

For network streams (RTSP/RTMP/HLS/live), enable low-latency mode:
```dart
fvp.registerWith(options: {
  'lowLatency': 1,
});
```
This reduces internal buffering depth, trading a bit of resilience against network jitter for lower glass-to-glass delay. Use it for live/interactive streams; leave it off for VOD where a slightly larger buffer smooths over network hiccups without visible stutter.

For local/VOD playback, lag is almost always a **decode-speed** or **first-frame** problem, not a buffering problem — which is why decoder selection (Section 2) matters more than buffer tuning for local files.

Other useful player-level properties (via the backend `Player` API in `package:fvp/mdk.dart`):
- `fastSeekTo()` — keyframe-only seeking for instant scrubbing instead of frame-accurate (slower) seeking.
- Frame drop control via decoder `drop` property (`nonref`, `bidir`, `nonintra`, `nonkey`) — useful if you need to keep up with a live source rather than falling progressively behind.

---

## 5. Platform-specific checklist

### Android
- Use `AMediaCodec` first, `FFmpeg` fallback.
- Prefer NDK mode (`java=0`, default) over Java API — noticeably lower overhead.
- `surface=1` (default) decodes directly to a `SurfaceTexture`/`AImage` — keep this; `surface=0` (ByteBuffer output) is much slower and only useful for pixel inspection.
- minSdk must be ≥21 (Flutter's own requirement for fvp is Flutter >3.19 for this reason).

### iOS / macOS
- Use `VT` first. Default `copy=0` gives best performance; only raise it if you need CPU pixel access.
- Subtitle rendering (libass) requires manually adding `ass.framework` to the Xcode project on iOS — it isn't auto-added like on the other platforms.
- To pick up the newest mdk-sdk via CocoaPods: `pod cache clean mdk && rm -rf ios/Pods && pod install` (or `macos/Pods`).

### Windows
- `MFT:d3d=11` first; consider `MFT:d3d=12` as a first-try for lower memory footprint on modern GPUs, falling back to `d3d=11`.
- Watch out for `shader_resource=1` — it enables true 0-copy sampling but is reported to cause decode errors on some GPU/driver combos. Test on your target hardware before shipping it enabled.
- Win7 is supported but only via `d3d=11`/`d3d=9` paths, not `d3d=12`.

### Linux
- Set `LIBVA_DRIVER_NAME` explicitly rather than relying on autodetection.
- **Do not install Flutter via snap** — it injects `CPLUS_INCLUDE_PATH`/`LIBRARY_PATH` env vars that can break the native C++ build fvp needs to compile; this is explicitly called out as broken for Android builds under snap.
- For dual-GPU laptops, use `switcherooctl` to force decode onto the discrete GPU if the integrated one lacks a codec.

### Embedded Linux (Raspberry Pi / Rockchip)
- Delete the bundled `libffmpeg.so.*` and rely on the OS-provided ffmpeg with hardware accel compiled in.
- Rockchip: build `ffmpeg-rockchip`, and set `export GL_UBO=1` on Linux 6.x kernels to dodge a Mali driver bug.

---

## 6. Crash-free playback: fallback strategy & error handling

This is the part most teams skip — and it's why "video players crash." Treat every layer as something that *can* fail and provide the next-best option.

### 6.1 Decoder-list fallback (already covered) — always end in `FFmpeg`
This alone prevents the majority of hardware-decoder-related crashes: instead of erroring out on an unsupported codec/profile/GPU driver combo, libmdk quietly steps down to software decoding.

### 6.2 Always listen for playback errors
```dart
_controller.addListener(() {
  final value = _controller.value;
  if (value.hasError && !value.isCompleted) {
    // Log it, and here is where you decide: retry with a different
    // decoder list, show a "can't play this file" UI, or fall back
    // to a different rendering path entirely.
  }
});
```
Never assume `initialize()` or a media change always succeeds — wrap `initialize()`/`play()` calls in `try/catch` in addition to the listener, since some native errors surface as thrown exceptions rather than value-changes.

### 6.3 Application-level fallback tiers
A robust "never crash, always show something" strategy looks like:

1. **Try `fvp` with full hardware decoder list.**
2. On `hasError` → **retry with software-only list** (`['FFmpeg']`) before giving up. This recovers from broken/partially-supported hardware decoders (e.g. a GPU driver that reports HEVC support but chokes on a specific profile).
3. On repeated failure → **fall back to the official `video_player` implementation** for that platform if available (don't call `fvp.registerWith()` for that specific controller instance, or scope fvp to only the platforms where you know it's stable, per Section 1).
4. On total failure → show a clear "this file/stream can't be played" state instead of a frozen or blank surface — never leave the user staring at a silently-broken texture.

### 6.4 Lifecycle safety (a common real-world crash source)
- **Always `dispose()` controllers** in `dispose()`/`didUpdateWidget` — leaked native `Player` instances are a top cause of memory growth and eventual native crashes on long-running apps (e.g. playlist/feed-style video apps).
- If you're reusing a single `Player` instance across many media items (recommended for feed-style UIs — the backend API supports this, see `multi_textures.dart` example), change `Player.media` rather than disposing/recreating the player each time; constant create/destroy cycles are a known source of native-layer instability under rapid swiping.
- Be careful with hot reload during development — native player state and Flutter's texture registration can get out of sync; a full restart is sometimes needed after decoder/renderer config changes.

### 6.5 Subtitle-related crashes
If you enable subtitles, ensure `libass` is actually present for the platform (it's auto-bundled for Windows/macOS/Android/OHOS, but **iOS requires manually adding `ass.framework`**, and Linux needs a system package). A missing libass on a platform expecting it can cause failures specifically when subtitle-containing media loads — bundle a fallback font (`subfont.ttf`) too, since a missing glyph font is a separate, quieter failure mode (broken subtitle rendering, not a crash, but still a "polish" issue worth closing).

---

## 7. Quick-reference: the "just make it fast and stable" defaults

If you don't want to hand-tune per platform, this is a sane universal starting config:

```dart
import 'package:fvp/fvp.dart' as fvp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  fvp.registerWith(options: {
    // Only use fvp where the official video_player has no native backend,
    // plus anywhere you need libmdk's extra codec support.
    'platforms': ['windows', 'linux', 'macos', 'android', 'ios'],

    'video.decoders': Platform.isWindows
        ? ['MFT:d3d=11', 'D3D11', 'FFmpeg']
        : Platform.isMacOS || Platform.isIOS
            ? ['VT', 'FFmpeg']
            : Platform.isAndroid
                ? ['AMediaCodec', 'FFmpeg']
                : ['VAAPI', 'CUDA', 'FFmpeg'], // linux

    'lowLatency': 0, // set to 1 only for live/RTSP/RTMP streams
  });

  runApp(const MyApp());
}
```

Pair this with the error-listener + dispose discipline from Section 6, and you have hardware-accelerated, zero-copy-where-possible playback on every platform, with a software fallback that guarantees *something* plays instead of the app crashing or freezing.

---

## 8. Where to go deeper

- Decoder property reference (per-decoder options like `copy`, `hwcontext`, `interop`): `mdk-sdk` wiki → **Decoders**
- Global engine-wide options (logging, plugin loading, EGL image handling): `mdk-sdk` wiki → **Global Options**
- Render backend internals: `mdk-sdk` wiki → **Render API** / **Zero Copy Renderer**
- Full player API (seek modes, snapshot, record, media info): `mdk-sdk` wiki → **Player APIs**
- Live examples for multi-texture reuse, custom renderers, RTMP record: `wang-bin/mdk-examples` (flutter folder)

Test everything on **real target hardware**, not just emulators/simulators — decoder availability, driver quirks (Intel iHD vs i965, Mali GL bugs, NVIDIA VA-API driver support) are the actual source of most "works on my machine" playback bugs, and no amount of Dart-side tuning substitutes for verifying the decoder list you shipped actually negotiates hardware acceleration on the device you care about.