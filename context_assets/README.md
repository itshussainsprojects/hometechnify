# HomeTechnify — Handoff Assets

These are all the **binary assets** added during the change session (they can't
be replicated from `CONTEXT.md` text). Copy the `assets/` contents here into the
target repo's `assets/` folder, preserving the same subfolders.

## What's inside
```
assets/
  anim/techy/f001.webp .. f085.webp   ← Techy mascot animation (85 frames, watermark-free)
  images/techy_wave.webp              ← Techy still (waving pose) for headers/login/home
  fonts/PlusJakartaSans-Regular.ttf   ← app font (weight 400)
  fonts/PlusJakartaSans-Medium.ttf    ← 500
  fonts/PlusJakartaSans-SemiBold.ttf  ← 600
  fonts/PlusJakartaSans-Bold.ttf      ← 700
  fonts/PlusJakartaSans-ExtraBold.ttf ← 800
```

## How the target AI should wire them (already described in CONTEXT.md §4.2/§4.3/§7)
1. Copy `assets/anim/techy/`, `assets/images/techy_wave.webp`, `assets/fonts/*.ttf`
   into the target repo under the same paths.
2. In `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/anim/techy/
       - assets/images/techy_wave.webp
     fonts:
       - family: PlusJakartaSans
         fonts:
           - asset: assets/fonts/PlusJakartaSans-Regular.ttf
             weight: 400
           - asset: assets/fonts/PlusJakartaSans-Medium.ttf
             weight: 500
           - asset: assets/fonts/PlusJakartaSans-SemiBold.ttf
             weight: 600
           - asset: assets/fonts/PlusJakartaSans-Bold.ttf
             weight: 700
           - asset: assets/fonts/PlusJakartaSans-ExtraBold.ttf
             weight: 800
   ```
3. `flutter pub get`. The `TechyFrameAnimation` widget expects frames named
   `f001.webp` .. `f085.webp` in `assets/anim/techy/`.

## Fonts license
Plus Jakarta Sans — SIL Open Font License (free for commercial use).
Source: https://github.com/tokotype/PlusJakartaSans

## If you'd rather regenerate the mascot frames from the source video
See `CONTEXT.md` §7 for the exact ffmpeg commands (crops out the watermark).
