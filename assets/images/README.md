# Images

- `adazalogo.png` — ADAZA logo (preferred). Shown on the landing splash and the
  sign-in card.
- `bg_main.jpg` — landing page background.
- `adazalogo.jpg` — legacy logo, kept as a backup.

Referenced from `lib/features/auth/presentation/landing_screen.dart` and
`sign_in_card.dart`, bundled via `assets/images/` in `pubspec.yaml`. Each load
has an `errorBuilder` fallback to the text mark, so a missing file won't crash.
