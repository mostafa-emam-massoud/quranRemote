# Adding a mushaf font

The reader works out of the box with the system serif face, which renders
Uthmani text correctly. A proper mushaf font makes it look like a printed
mushaf.

1. Download a Qur'an font — for example **KFGQPC HAFS Uthmanic Script** from
   the King Fahd Glorious Qur'an Printing Complex (fonts.qurancomplex.gov.sa),
   or Amiri Quran / Scheherazade New from Google Fonts.
2. Drop the `.ttf`/`.otf` file into this folder and drag it into the
   **QuranRemote** target in Xcode (tick "Copy items if needed" and the
   QuranRemote target).
3. Add the file name to `Config/QuranRemote-Info.plist`:

   ```xml
   <key>UIAppFonts</key>
   <array>
       <string>UthmanicHafs1Ver18.ttf</string>
   </array>
   ```

4. Make sure the font's **PostScript family name** is in
   `MushafFont.preferredFamilies` in `QuranRemote/Theme.swift`. The names
   already listed cover the common Qur'an fonts; Settings → About shows which
   one the app actually picked up.

Font files are gitignored, so licensing stays your call rather than this
repository's.
