# Tiny Week Zine

An 8-page, one-sheet, one-cut week planner zine builder: pick a layout per day,
decorate with stickers or your own photos, then print the imposed A4 sheet,
fold, cut once, and staple. A Flutter port of the single-file web version.

Runs on Android phones and tablets, web (itch.io), Windows, macOS, Linux and iOS.
Android applicationId: `com.stagfoo.tiny_week_zine`.

- `flutter test` checks sticker drag, pinch-rotate, delete and week maths.
- `scripts/build_itch.sh` builds the web version into `dist/tiny-week-zine-web-<version>.zip`.
- `flutter build apk --release --target-platform android-arm64 --split-per-abi` builds the APK.
  It is signed with the committed `android/app/debug.keystore`, so every build
  installs as an update over the last. Fine for itch; not a Play Store key.
- `.github/workflows/build.yml` (run by hand, or by pushing a tag) builds web,
  Android, Linux, Windows and macOS. Desktop builds need CI: this PC has no cmake.

## Releases and Obtainium
Bump `version:` in `pubspec.yaml` (both parts, e.g. `1.0.1+2`), commit, then
`git tag 1.0.1 && git push origin main 1.0.1`. CI builds everything and
publishes a GitHub release with one APK, which Obtainium picks up from
`https://github.com/stagfoo/tiny-week-zine` (the repo must be public).

## itch.io
One project, **Kind of project: HTML**, with these uploads:

| Channel | File | itch settings |
|---|---|---|
| web | web zip | tick *played in the browser*; viewport ~1000 × 900, mobile friendly, fullscreen button |
| android | `.apk` | platform: Android |
| windows / linux / mac | CI artifacts | platform: Windows / Linux / macOS |

To have CI push everything with butler, add a repo secret `BUTLER_API_KEY`
(itch.io → Settings → API keys) and a repo variable `ITCH_GAME`
(e.g. `yourname/tiny-week-zine`). The macOS build is unsigned, so the first
launch needs right-click → Open.
