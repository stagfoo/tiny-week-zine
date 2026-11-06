# Tiny Week Zine — itch.io page

Everything to set up the project page. Images are in this folder:
`cover.png`, `banner.png`, `screens/*.png`. Re-render them with
`flutter test tool/itch_art_test.dart` and `flutter test tool/screens_test.dart`.

## Project settings

| Field | Value |
|---|---|
| Title | Tiny Week Zine |
| Short description | A one-sheet week planner you print, fold and cut into an 8-page zine. |
| Classification | Tools |
| Kind of project | HTML |
| Pricing | Your call: *No payments*, or *Pay what you want* with $0 minimum |
| Cover image | `cover.png` (1260×1000, itch scales it to 630×500) |
| Screenshots | `screens/editor-wide.png`, `screens/sheet-wide.png`, `screens/editor-phone.png` |
| Tags | planner, zine, printable, journal, bullet-journal, stationery, stickers, weekly-planner, cute, paper |

## Uploads (from a GitHub release)

| File | itch settings |
|---|---|
| `tiny-week-zine-web.zip` | tick **This file will be played in the browser** |
| `tiny-week-zine.apk` | platform: Android |
| `tiny-week-zine-windows-x64.zip` | platform: Windows |
| `tiny-week-zine-macos.tar.gz` | platform: macOS |
| `tiny-week-zine-linux-x64.tar.gz` | platform: Linux |

Embed options: viewport **1100 × 860**, **Mobile friendly**, **Fullscreen button** on,
orientation *default*. Or set `BUTLER_API_KEY` + `ITCH_GAME` on the repo and CI pushes
all five on every tagged release.

## Theme (Edit theme)

| Setting | Value |
|---|---|
| Banner | `banner.png` |
| Background | `#EEEBE3` (warm paper) |
| Background 2 (column) | `#EEEBE3` |
| Text | `#141413` (ink) |
| Links | `#1E8A4C` (the one green) |
| Buttons | `#141413`, so download buttons read as solid ink |
| Header font | *Archivo Black* if it's in itch's list, otherwise *Oswald* |
| Body font | *IBM Plex Mono* if it's in itch's list, otherwise *Space Mono* |
| Layout | screenshots in the right column; no background image |

## Description (paste into the editor)

---

**A week planner you print on one sheet of A4, fold, cut once, and fill in by hand.**

Pick a layout for each day, decorate the pages with stickers or your own photos,
then print. The app lays all eight pages out on the sheet the right way round:
crease, make one cut, fold, and you're holding a tiny booklet for the week.

### WHAT'S INSIDE

- **8 pages:** a cover and one page for each day, Monday to Sunday
- **Covers:** Blank · This week · Weekly boxes · Habit tracker
- **Days:** Daily · Grid note · Drafting · Modular · Routine · Check list
- **187 stickers** in 13 packs (bunnies, cats, mushrooms, fries, witches,
  planner bits), drawn by me, plus any picture of your own
- **Text boxes** in any Google Font, and **shapes**: boxes, circles, lines, arrows
- **Black-and-white dithering** for pictures, for a photocopied look
- **Book images:** search public domain illustrations from the Internet Archive
- Pages print blank, ready for pen

### PRINTING

- One A4 sheet, single-sided, printed at **actual size**
- **Check printer** reads how much your printer can't reach at each end
  (Linux and macOS). **Print test page** measures it on any printer
- If an end gets cut off, the sheet gets a strip to trim first, so all eight
  pages stay the same size

### HOW TO FOLD

1. Crease into 8 panels, then unfold
2. Cut the green dashed line through the middle two panels
3. Fold lengthwise, push the ends together, flatten into a booklet
4. Staple a few weeks together through the marks by the spine

### RUNS ON

Your browser right here, Android (phones and tablets), Windows, macOS and Linux.
Everything stays on your device: no account, no uploads.

---
