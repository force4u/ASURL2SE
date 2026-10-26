# ASURL2SE

English | [日本語](README.ja.md)

A tiny macOS app that catches `applescript:` URLs and turns them into a new Script Editor document.

- Version: 0.1de
- Bundle ID: `com.cocolog-nifty.quicktimer.ASURL2SE`
- Building it produces `ASURL2SE.app`
- License: CC0 1.0 (public domain)

---

## ⚠️ This app was made by Claude

**The source code and this README were written by Claude, an AI made by Anthropic.**
The human author decided what the app should do, tested it on a real Mac, and reported bugs. Claude wrote the code. (All the author supplied was the spec ideas and a rough AppleScript draft.)

- Model ID configured for the session that wrote it: `claude-sonnet-5-5` (the model that actually answered may have been a different one)
- Claude wrote the code in an environment where it could not build or run the app. Everything was tested by hand on the author's Mac.
- So there may be bugs. Use it at your own risk.

---

## What is this for?

On the author's Mac, Script Editor in macOS 27 no longer accepts the `applescript:` URL scheme (this is what the author observed). Chromium-based browsers also stopped handing these URLs to other apps (also confirmed by the author).

That means "Open in Script Editor" links on web pages don't work anymore. This app **receives the URL on Script Editor's behalf and puts the script from the URL into a new Script Editor document.**

The author understands the change is meant to stop ClickFix-style scams, and doesn't object to it. This app is a personal tool for "look at the contents, decide for yourself, and run it yourself."

## What it does

| Trigger | What happens |
|---|---|
| Click an `applescript:` link in a browser | Decodes the URL and creates a new Script Editor document |
| Double-click an `.inetloc` file (via Finder) | Same |
| Drop an `.inetloc` file onto the app icon | Same |
| Launch the app while the clipboard holds an `applescript:` URL | Same |
| Launch the app while the clipboard holds plain text | Puts that text into a new Script Editor document (it doesn't have to be AppleScript) |
| Launch the app while the clipboard is empty | Opens the settings window |
| Launch the app while holding the Option key | Opens the settings window |
| Click the Dock icon while the app is already running | Same as launching it |
| Menu: Settings… (⌘,) | Opens the settings window |

- The app **quits by itself 60 seconds** after it finishes handling something. It doesn't count down while the settings window is open, and starts over from 60 when you close it.
- What the author has actually tested: clicking links in Safari, and double-clicking / dropping `.inetloc` files. Firefox, Arc and others haven't been tried.

### What the settings window does

- Changes the destination (default app) for `applescript:` URLs. The list shows this app plus any other app that can receive `applescript:` URLs.
- Turns the "review before opening" dialog on or off (separately for URLs and for the clipboard). Both are **off** by default.
- Settings are stored in `UserDefaults`. To reset them, run `defaults delete com.cocolog-nifty.quicktimer.ASURL2SE`.

## Safety notes

- **It never runs the script, and never saves it.** It only puts the text into a new Script Editor document. Whether to run it is up to you, after you've read it.
- The URL's `action` / `name` / `directory` / `appid` parameters are ignored. `insert` / `append` are treated as "new document" too. The received values never decide where something is saved or what it's called.
- The received text is not pasted into any AppleScript source. It's passed to `osascript` as an argument (data).
- **The review dialog is off by default**, because this is a personal tool. If other people will use it, or if you tend to click links without looking closely, turn "review before opening" on in the settings window.

## Requirements

- macOS 27 or later (Apple Silicon only; Intel isn't considered)
- Xcode to build it

## Display language

Menus, dialogs and the settings window are shown in Japanese if your primary macOS language (System Settings → General → Language & Region, the top one) is Japanese, and in English otherwise.

To try a different language for this app only, run this in Terminal and relaunch the app:

```
defaults write com.cocolog-nifty.quicktimer.ASURL2SE AppleLanguages '("ja")'
```

To undo it, run `defaults delete com.cocolog-nifty.quicktimer.ASURL2SE AppleLanguages`.

## How to build

1. Open the Xcode project in this repository.
2. Leave signing on **Sign to Run Locally** (ad-hoc signing) and run with `⌘R`.
3. Put the resulting `ASURL2SE.app` in `/Applications`, then pick it as the destination in the settings window.

You don't need an Apple Developer Program membership. It's meant to be built and used on your own Mac.

### Xcode project settings (if you recreate the project from scratch)

- Start from the macOS → App template (Swift / Storyboard). Afterwards, delete `Main.storyboard`, `ViewController.swift` and the template's `AppDelegate.swift`, and empty "Main storyboard file base name" in Build Settings.
- **Turn App Sandbox off.** With it on, Apple Events from `osascript` to Script Editor don't go through (the author got a `-600` error).
- In the Info tab, add a URL Type with URL Schemes `applescript` and Role `Viewer`.
- In the Info tab, add `Privacy - AppleEvents Sending Usage Description` (`NSAppleEventsUsageDescription`). Writing it in both languages lets it be read either way. (Example: `Script Editor に新規書類を作成するために使用します。 / Used to create a new document in Script Editor.`)
- Architectures: `arm64`.
- If the template links any iOS-related SDKs, remove them. (The author removed them at the same time as turning the Sandbox off, so it isn't clear which one fixed the problem.)

### Permission dialogs on first use

- The first time the app operates Script Editor, you get an Automation (Apple Events) permission dialog.
- Reading the clipboard may also ask for permission (on the author's Mac it appeared only the first time).

## Source layout

| File | Role |
|---|---|
| `main.swift` | Starts the app |
| `AppDelegate.swift` | Receiving URLs, checking the clipboard, parsing and decoding URLs, menus, the 60-second auto-quit |
| `ScriptEditorBridge.swift` | Creates a new document in Script Editor via `osascript` (with a timeout) |
| `SettingsWindowController.swift` | The settings window and storing the settings |
| `L10n.swift` | Switches the on-screen text between Japanese and English |

URL decoding is written by hand instead of using `URLComponents`. Safari's "Copy Link Address" turns the percent-encoded Japanese parts back into readable characters, so you end up with a URL that mixes `%XX` and raw Japanese. When Foundation parsed such a URL, the `%` seemed to get encoded again, leaving undecoded `%0D` and `%20` in the result.

The source comments are in Japanese.

## Known caveats

- Only tested on the author's Mac (macOS 27). There's no guarantee it works elsewhere.
- If Script Editor isn't running, an "open file" dialog may appear when it starts (the author saw this when launching it from Terminal).
- Chromium-based browsers don't pass `applescript:` URLs to other apps. Use "Copy Link Address" and then launch this app.

## License

[CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/deed.en).
To the extent possible, all copyright and related rights are waived. Copy, modify, redistribute, or use it commercially, with no need to ask. No warranty.

(The code was generated by an AI, so its legal status may differ from country to country. The author is not a legal expert.)
