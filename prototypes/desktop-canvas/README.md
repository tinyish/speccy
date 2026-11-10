# Spike: the canvas in elixir-desktop's window

Throwaway. It runs the LiveView canvas spike (`../liveview-canvas`) inside
elixir-desktop's own window, the native WKWebView host from
`desktop_webview`, instead of Playwright's WebKit (`core.md`, Prototype
first 1): pan, zoom, drag and typing in place, plus a native File menu
and folder picker.

## Run

Elixir 1.18+ with Xcode's Swift; the host is built from source as in
`../cli-bundle`:

```sh
mix deps.get
bash deps/desktop_webview/scripts/build_macos.sh
mix run --no-halt                       # the window, on a temp copy of the example
SPEC_DIR=/some/copy mix run --no-halt   # or on a spec folder of your own
SELFTEST=1 mix run --no-halt            # runs the self-test and logs its report
EDW_TEST_RPC=1 mix run --no-halt        # starts the host with its test RPC (test.menu.list…)
```

It runs in development mode: the BEAM starts the host with
`--edw-no-beam`. The window and webview are the same as in the packaged
app (`../cli-bundle` proved the bundle); only who starts whom differs.

- **File > Open…** shows the native folder picker and loads the chosen
  folder on the canvas; a folder with no `screens/*.json` is ignored.
- The canvas is the spike's, as its README says: drag, double-click to
  edit, wheel pans, ⌘/ctrl+wheel and pinch zoom, space+drag pans.

## How it fits

- `lib/spike.ex` compiles every `defmodule` of `../liveview-canvas/canvas.exs`
  unchanged (its spec model, LiveView and layout). This app adds only its
  own router, endpoint, menu and a root layout that runs `lib/page.js`
  ahead of the spike's script.
- **Opening a folder** sets the spike's spec folder and reloads the
  window, so the LiveView remounts on it.
- **`lib/page.js`** holds the one workaround the view needed (pinch,
  below) and the self-test.
- **The self-test** (`SELFTEST=1`, which opens the page with
  `?selftest`) drives the hook with DOM events inside the real
  WKWebView: ten reorders, ten copy edits in the base, one in a state's
  frame, five outside writes to the file, then wheel, ⌘/ctrl+wheel,
  pinch, space+drag and middle-drag. It posts its report to the server,
  which prints it as `selftest {…}`. It edits the open folder's files.

## Findings

On an Apple-silicon Mac, macOS 26.1, Elixir 1.20.4 on OTP 29. Five
self-test runs, each reporting the median of its runs; the Playwright
column is `../liveview-canvas`'s:

| | Playwright WebKit | elixir-desktop WKWebView |
|---|---|---|
| Reorder, round trip (server) | 9.0 ms (1.4) | 4 to 7 ms (0.8 to 1.1) |
| Copy edit, round trip (server) | 3.0 ms (0.5) | 5 to 7 ms (0.7 to 1.3) |
| Outside file edit shown | 26 ms | 197 to 200 ms |
| 120 wheel pans, one a frame: frame time | | 10 ms median, 19 ms worst |

WKWebView rounds `performance.now()` to whole milliseconds. The outside
edit is the spike's 300 ms poll either way; the self-test's spacing lands
each write at the same point in the poll.

What the self-test checks, passing in every run: the page draws its five
frames and LiveView connects; every reorder and copy edit gets the
server's reply; a double-click makes the copy editable with focus and its
text selected; each outside write shows in the base frame; wheel,
⌘/ctrl+wheel, space+drag and middle-drag move the view by the expected
amounts; and the ⌘/ctrl+wheel and the synthetic pinch are cancelled. It
doesn't check that a plain pan wheel is cancelled, nor read the files.

Read from the files after the first run: the drag rewrote the screen's
order of instances, and the edit in the empty frame wrote
`states.empty.set` and left the base alone. The base copy edits' value
wasn't read back: the outside writes overwrite the same prop after them.

What the view and the host change:

- **A pinch may arrive as gesture events, not ctrl+wheel.** Not seen
  with a real pinch: `GestureEvent` is defined in the view (touch events
  aren't), and WebKit hands a pinch to the page as Safari's
  `gesturestart`/`gesturechange`/`gestureend` when magnification is off
  (the host's default), where Chromium sends ctrl+wheel. The spike's hook only zooms on ⌘/ctrl+wheel, so pinch would
  do nothing. `page.js` replays each `gesturechange` as a ctrl+wheel with
  the same ratio and cancels the gesture; the self-test's synthetic pinch
  of 1.5 zooms by exactly 1.5. The hook keeps the server/page split.
- **The host turns on swipe navigation**
  (`allowsBackForwardNavigationGestures`). The hook cancels every wheel
  event and the page has one history entry, so a two-finger swipe
  shouldn't navigate; to check by hand.
- **Menus.** `Desktop.Menu` works as documented; File > Open… lands in
  the main menu (checked with the host's `test.menu.list`). But the host
  places its own Edit menu before the app's (app, Edit, File), and builds
  every item with no key equivalent, so Open… can't have ⌘O. The
  smallest routes: a `key` attribute on `<item>` and the Edit menu after
  the app's first menu, upstream in `desktop_webview`'s
  `buildMenuItem`/`installMenubar`; until then the hook can catch ⌘O
  and push an event.
- **The folder picker** is `DesktopWebview.Dialog.choose_directory`
  (`desktop` itself has no dialog API): an app-modal `NSOpenPanel`
  (seen on screen, titled "Open a spec folder"). It blocks the calling
  process (the menu's) and the host's RPC until dismissed. If the BEAM
  dies while it is open, the host stays up and has to be killed.
- `Desktop.Window` adds its login key (`?k=…`) to the window's URL; the
  spike's endpoint, like the canvas spike's, doesn't check it.

Tried by hand, since the self-test's events are synthetic; Alberto ran
all seven on 2026-11-10 and every one passed:

1. Trackpad two-finger scroll pans smoothly, in both axes.
2. Pinch zooms around the pointer, once per step (if it zooms twice as
   fast, WebKit also sends ctrl+wheel and `page.js` must drop it).
3. A two-finger horizontal swipe doesn't navigate away.
4. ⌘+mouse wheel zooms; space+drag and middle-drag pan.
5. Dragging an instance in base shows the preview and drop line, and the
   order sticks.
6. Double-click copy, type (including an accent, ⌥e e, an emoji from
   ⌃⌘Space, and text through an IME such as Japanese Kana, where Enter
   must confirm the composition, not save), Enter saves, Esc cancels;
   ⌘A, ⌘C and ⌘V work inside the edit.
7. File > Open… shows the picker; choosing a spec folder shows it on the
   canvas; Cancel leaves it as it was.

## Not done

- Not run from the packaged bundle (`../cli-bundle` covers that).
- No native input synthesized: the hand checks above stand in.
- The endpoint doesn't use `Desktop.Endpoint`/`Desktop.Auth`, and
  LiveView runs with `check_origin: false`, as in the canvas spike.
- Open… reloads the page; the real editor opens a workspace.
