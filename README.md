# Scrubby

**Swipe through browser tabs and windows on your Mac's trackpad, like dragging a scrollbar.**

- **Three fingers sideways** in your browser: move to the next or previous tab. Keep dragging to move across several tabs in one swipe.
- **Four fingers sideways** anywhere: move through your open windows, like ⌘-Tab but for windows. The window's name flashes on screen as you go.

Scrubby is a tiny menu bar app. It's free and open source, and it uses only standard macOS features.

<!-- TODO: add a demo GIF here, e.g. docs/demo.gif -->

## Install

Download `Scrubby.zip` from the [latest release](../../releases/latest), unzip it, and drag **Scrubby** to your Applications folder.

Or build it yourself (needs Xcode 15 or later):

```bash
git clone https://github.com/Kudostoy0u/Scrubby.git
cd Scrubby
scripts/build-app.sh
cp -R build/Scrubby.app /Applications/
```

If macOS says the app can't be opened because it's from an unidentified developer, right-click Scrubby in Applications and choose **Open**.

## Setup

Scrubby opens a setup screen the first time it runs, with a checkmark for each step once it's done:

1. **Allow Scrubby to control your Mac.** Open System Settings → Privacy & Security → **Accessibility** (called **Device Control and Data Access** on newer macOS) and turn on Scrubby. Scrubby needs this to see trackpad swipes and to press the tab-switching shortcut for you.
2. **Free up the swipes macOS is using.** In System Settings → Trackpad → More Gestures:
   - Set **Swipe between pages** to **Scroll left or right with two fingers**, or turn it off.
   - Turn off **Swipe between full-screen applications**.

## Supported browsers

Brave, Chrome, Arc, Dia, Edge, Vivaldi, Opera, Chromium, Firefox, Zen and Safari. You can turn tab swiping off for any of them in Settings.

## Settings

Click the hand icon in the menu bar → **Settings…** to:

- turn each gesture on or off
- change how far you swipe before the first tab or window switch, and between further ones
- choose which browsers tab swiping works in
- open Scrubby when you log in

## How it works

macOS doesn't let apps receive three- and four-finger swipes directly. Scrubby combines two signals instead:

- **Finger count** comes from the trackpad's touch events. macOS often sends these with no fingers listed, even in the middle of a swipe, so Scrubby ignores those and remembers the last real count for a moment.
- **Movement** comes from the smooth sideways scroll events the trackpad sends while several fingers drag. Every so many points of movement moves one tab or window.

Each swipe is set as a tab swipe, a window swipe or a normal scroll when it starts, and stays that way until your fingers lift. Scrubby blocks the scroll events of tab and window swipes, along with the coasting scroll that follows them, so the page doesn't scroll and the browser doesn't go back or forward.

Tabs are switched with each browser's own shortcut: ⌘⌥← / ⌘⌥→, or ⌃⇧⇥ / ⌃⇥ in Safari.

## Development

```bash
swift build                 # debug build
scripts/build-app.sh        # release .app in build/, signed for this Mac only
```

The code is in `Sources/Scrubby`:

| File | What it does |
| --- | --- |
| `GestureEngine.swift` | Listens for trackpad events and turns swipes into actions |
| `WindowSwitcher.swift` | Finds the windows on the current Space and focuses the next one |
| `Browsers.swift` | Supported browsers and their tab shortcuts |
| `SettingsView.swift` | The Settings and setup window |
| `SystemStatus.swift` | Checks permissions and trackpad settings |
| `HUD.swift` | The on-screen window name |

**Permission resets after rebuilding:** macOS ties the Accessibility permission to the app's signature. Builds signed for this Mac only get a new signature every time, so after reinstalling a new build you may need to turn Scrubby off and on again in the Accessibility list (or remove it and add it back).

## Releasing

People can open a release without warnings only if it's signed with a Developer ID and notarized by Apple, which needs an [Apple Developer account](https://developer.apple.com/programs/).

```bash
scripts/release.sh 0.2.0
```

This builds the app, signs it with your Developer ID, notarizes it with Apple, tags the commit and publishes `Scrubby.zip` as a GitHub release. The one-time setup it needs is listed at the top of `scripts/release.sh`. A Homebrew cask template is in `packaging/scrubby.rb`, and the script keeps its version and checksum up to date.

The app icon is drawn by `scripts/make-icon.swift`. Run `swift scripts/make-icon.swift` to regenerate `Resources/AppIcon.icns`.

## License

MIT
