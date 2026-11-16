# Radio Log

A Farming Simulator 25 mod. It shows the current radio station and song on screen and keeps a daily log of what you listened to.

## What it does

- Shows the station and song in a dark box at the bottom centre of the screen while the radio is playing.
- Writes a daily log to `Documents/My Games/FarmingSimulator2025/modSettings/RadioLog/YYYY-MM-DD.txt`.
- Logs how each song started (you switched station, or the next song came on), how long you listened and how it ended.
- Adds your total time on a station when you heard two or more songs there.
- Leaves out songs you heard for less than 5 seconds, so flicking through stations does not fill the log.
- Works with the built-in stations and online radio streams, in single player and multiplayer.

Example log:

```
20:31:35  SWITCHED TO  Simulator Radio  |  Number 1   [listened 0:22, played to the end]
20:31:57  next song    Simulator Radio  |  Crazy In Love   [listened 3:13, played to the end]
20:35:10  next song    Simulator Radio  |  Blinding Lights   [listened 2:30, radio turned off]
          -- 6:05 on Simulator Radio
20:37:40  RADIO OFF
```

The game does not tell mods how long a song is, so "listened" is the time you actually heard it. A matching `.xml` file is kept next to each `.txt` so that several play sessions on one day go into the same log.

## Install

1. Zip the contents of this repository (`modDesc.xml` at the top level of the zip) as `FS25_RadioLog.zip`.
2. Put the zip in `Documents/My Games/FarmingSimulator2025/mods/`. Do not unzip it.
3. Enable the mod in your savegame.

The zip name must not contain spaces or brackets, such as `(1)`. The game skips those files.

## Settings

Edit the values at the top of `scripts/RadioLog.lua`:

| Setting | Default | Meaning |
| --- | --- | --- |
| `SHOW_HUD` | `true` | Show the station and song on screen. |
| `HUD_POS_X`, `HUD_POS_Y` | `0.5`, `0.045` | Position of the box, from 0 to 1. `HUD_POS_Y` is its bottom edge. |
| `HUD_ALIGN` | `"center"` | `"right"` makes `HUD_POS_X` the right edge of the box. |
| `HUD_TEXT_SIZE` | `0.019` | Text size. |
| `HUD_BOX_COLOR` | `{0, 0, 0, 0.75}` | Box colour. The last number is how solid it is. |
| `MIN_LISTEN_SECONDS` | `5` | Songs heard for less than this are left out of the log. |
| `LOG_RADIO_OFF` | `true` | Write a `RADIO OFF` line when the radio stops. |
