# UI & design

<!-- Extracted from README.md so the README stays an overview. -->

<p align="center">
  <b>Glassmorphism</b> &nbsp;&middot;&nbsp; <b>Liquid Glass Effects</b> &nbsp;&middot;&nbsp; <b>Performance Toggle</b> &nbsp;&middot;&nbsp; <b>Custom Route Transitions</b> &nbsp;&middot;&nbsp; <b>Responsive Layout</b> &nbsp;&middot;&nbsp; <b>macOS-Style Dock</b>
</p>

<p align="center">
  <em>The visual identity of PlayTorrio is built on a custom glassmorphism design system with GPU-accelerated shader effects. Every surface has depth. Every transition is deliberate. And for devices that need it, a single toggle disables the expensive effects while preserving the aesthetic.</em>
</p>

### Glassmorphism System

The app uses the `liquid_glass_easy` package which applies real-time GPU shader effects including:
- **Frosted glass** — backdrop blur with dynamic intensity
- **Refraction simulation** — content appears to bend behind glass surfaces
- **Jelly deformation** — subtle elastic response to scroll and touch
- **Optical borders** — light-edge highlights that simulate physical glass thickness
- **Hover lensing** — magnification and distortion under the cursor on desktop

### Performance-Conscious Fallback

The `GlassSettings` service controls a global `ValueNotifier<bool>` toggle — "Full Liquid Glass." When enabled, all GPU shader effects are active for the premium experience. When disabled, the app falls back to lightweight gradient and blur approximations that preserve the visual intent without the GPU cost. Users can toggle this in Settings at any time. The toggle persists via `SharedPreferences`.

Key performance optimizations:
- **`RepaintBoundary`** — widget subtrees that don't need shader recomputation are isolated
- **Shader pre-warming** — a sweep animation on the dock pre-compiles GPU shaders before user interaction
- **`PerformanceLiquidLens`** — optimized shader presets for common patterns (dock, sheet, menu button, menu)
- **Fallback gradients** — when glass is disabled, styled gradients maintain the frosted look without shader overhead

### Custom Route Transitions

| Transition | Duration | Effect | Used For |
|:-----------|:---------|:-------|:---------|
| **LiquidRevealRoute** | 750ms | Circular mask expands from tap point revealing the new page beneath | Movie details, manga details, search, settings |
| **CinematicSlideRoute** | 600ms | Page slides up while fading in with a slight scale — cinematic entrance | Watch screen, player screen |
| **ZoomFadeSlide** | 400ms | Combines zoom-out + fade-out + slide-up — elegant exit | Audiobook player entrance |

### Liquid Dock

A macOS-style animated dock sits at the bottom of the home screen providing navigation to Manga, Audiobooks, and Music sections. Dock icons scale up with proximity to the cursor — a lens magnification effect. Arrow buttons appear when dock items overflow the available width. The dock pre-warms GPU shaders during its initial build to eliminate first-interaction jank.

### Responsive Card System

Movie and manga cards adapt to screen width through factory sizing classes:

```
Screen Width < 600px  >> Card width: 138px  (compact mobile)
Screen Width 600-900  >> Card width: ~155px (tablet)
Screen Width 900-1200 >> Card width: ~175px (small desktop)
Screen Width > 1200px >> Card width: 205px  (large desktop)
```

Cards feature hover animations — subtle lift with shadow expansion on mouse enter, return on exit. A shimmer loading skeleton (`PosterSkeleton`) displays while cover art loads. Missing posters fall back to an icon placeholder.

### Custom Scroll Track

A glass-styled scrollbar with:
- **Drag-to-scroll** thumb
- **Arrow buttons** at each end for incremental scroll
- **Magnetic snap** — thumb gravitates toward nearest position
- **Animated opacity** — visible on hover, fades when idle
- **Dual orientation** — vertical and horizontal variants

### Section Components

- **`SectionHeader`** — Title + optional subtitle + "See All" link that navigates to full catalog
- **`MovieSliderSection`** — Horizontal scrollable row with animated slide-in arrow buttons. Arrows appear on hover (desktop) or are always visible (mobile). Scrolls 80% of viewport width per arrow press.
- **`SliderArrow`** — Glass circle button with hover/press state animations

### Theme

```
Background: #080A0F (deep near-black with blue undertone)
Seed Color:  #7C5CFF (vibrant purple — used for accents, buttons, focus rings)
Surface:     Glass with 10-20% opacity over background
Text:        White primary, 70% opacity secondary
Brightness:  Dark (forced — no light mode)
Material:    Material 3 (latest Material Design spec)
```

Scroll overscroll effects are disabled globally for a clean, native-feeling scroll experience. The debug banner is suppressed. The app runs in immersive sticky mode — system UI (status bar, navigation bar) auto-hides for full-screen content consumption.

<br/>
