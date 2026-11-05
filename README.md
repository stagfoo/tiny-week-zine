# Tiny Week Zine

An 8-page, one-sheet, one-cut week planner zine builder: pick a layout per day,
decorate with stickers or your own photos, then print the imposed A4 sheet,
fold, cut once, and staple. A Flutter port of the single-file web version.

Runs on web (itch.io), Android, iOS, Windows, macOS and Linux.

- `flutter test` checks sticker drag, pinch-rotate, delete and week maths.
- `scripts/build_itch.sh` builds the web version into `dist/tiny-week-zine-web-<version>.zip`.

## itch.io
Create a project with **Kind of project: HTML**, upload the zip, tick
**This file will be played in the browser**, and set the viewport to around
1000 × 900 with **Mobile friendly** and the fullscreen button on.
