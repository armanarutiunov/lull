# Lull

A macOS menu bar app that tells you whether it's safe to turn off the display and leave
your Mac running overnight on the charger.

- 🟢 **Safe to leave**: idle and cool
- 🟡 **Keep an eye on it**: moderate sustained load, warming up, or memory pressure
- 🔴 **Not safe to leave**: heavy sustained load, running hot, or draining the battery while plugged in

The verdict comes from the last 5 minutes of CPU load, temperature, memory pressure and
battery current, so short spikes don't change it. Click the icon to see the reasons and quit
whatever is responsible.

Requires macOS 26.

## Install

Download the latest zip from [Releases](https://github.com/armanarutiunov/lull/releases),
unzip, and move `Lull.app` to `/Applications`. The app isn't notarized, so on first launch
open **System Settings → Privacy & Security** and click **Open Anyway**.

## Reading the state from a script or an agent

Lull writes its current state every 30 seconds to:

```
~/Library/Application Support/Lull/status.json
```

The app binary also prints it:

```sh
/Applications/Lull.app/Contents/MacOS/Lull status          # human-readable summary
/Applications/Lull.app/Contents/MacOS/Lull status --json   # raw JSON
```

To type just `lull status`, link it somewhere on your `PATH`:

```sh
ln -s /Applications/Lull.app/Contents/MacOS/Lull ~/.local/bin/lull
```

If `updatedAt` is more than a couple of minutes old, Lull isn't running.
