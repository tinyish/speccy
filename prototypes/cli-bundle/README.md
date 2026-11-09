# Spike: the speccy command from the app bundle

Throwaway. It tests whether the `speccy` command can ship inside the
elixir-desktop app and run from the same release without a window
(`core.md`, Prototype first 1): `speccy check` answering in under a
second, and `speccy open` reaching an app that is already running.

## Build and run

Elixir 1.18+ with Xcode's Swift. `desktop_webview`'s host isn't published,
so it is built from source first:

```sh
mix deps.get
mkdir -p priv && sips -s format png -z 1024 1024 \
  /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns \
  --out priv/icon.png                        # any 1024px PNG; not committed
bash deps/desktop_webview/scripts/build_macos.sh
MIX_ENV=prod mix desktop.installer          # _build/prod/Speccy.app and .dmg
C=_build/prod/Speccy.app/Contents
sed -i '' 's/^mode = reconnect$/mode = reconnect\ninstances = single\ninstance_id = speccy-spike/' $C/Resources/DesktopWebView.ini
cp speccy $C/MacOS/speccy && codesign -f -s - --deep _build/prod/Speccy.app
ln -s "$PWD/$C/MacOS/speccy" ~/bin/speccy   # any folder on PATH
speccy check ../spec-format/example
speccy open ../spec-format/example
```

The app is one window on a local page that lists every folder it was
asked to open (`/opened.json`). `speccy check` only decodes every JSON
file; the real checker's cost is the core's, not the launcher's.

## How it fits together

- **The bundle** is elixir-desktop's host-first layout:
  `Contents/MacOS/DesktopWebView` (a native WKWebView host from
  `desktop_webview`) spawns the release in `Contents/Resources/beam/`.
- **The command** is `Contents/MacOS/speccy`, a shell script, linked onto
  PATH. `speccy open` hands the folder to the host; everything else runs
  `beam/bin/speccy eval 'Speccy.CLI.main(System.argv())' "$@"` with
  `RELEASE_DISTRIBUTION=none`. `eval` loads the code without starting the
  application, so no window, endpoint or workspace starts.
- **Opening a running app** is the host's single-instance mode: a second
  launch finds the first host's control socket, sends it the folder, and
  exits 0; the app gets `{:open_file, [path]}` from `Desktop.Env`.
- **Opening a closed app** launches the host with the folder. The host
  passes it on as `bin/speccy start <dir>`, but the release's `start`
  drops extra arguments, so `rel/env.sh.eex` exports it as `SPECCY_OPEN`
  and the app reads that at boot.

## Findings

On an Apple-silicon Mac, Elixir 1.20.4 on OTP 29, through the PATH link:

| | Time |
|---|---|
| `speccy check` on the example (8 files), first run | 0.60 s |
| the same, warm (4 runs) | 0.15 s |
| the same, with the app running | 0.14 s |
| `speccy open`, app closed, until the app has the folder | 1.08 s |
| `speccy open`, app running, until the app has the folder | under 0.3 s |

Every check passes: arguments and exit codes come through `eval` (0
clean, 1 on a broken file, 2 on a bad command), nothing listens while
`check` runs, a second `open` leaves one host process, and `check`
doesn't clash with a running app. The bundle is 63 MB.

What it took, for the real build:

- `desktop`, `desktop_webview` and `desktop_deployment` come from GitHub:
  hex's `desktop` is from March 2024, and the other two aren't on hex.
  `desktop_webview` must be overridden to take `desktop` from git too.
- The host binary is built from source with Swift (no published binary
  yet).
- `desktop_deployment` writes the macOS host's ini itself, without
  `instances = single`; the spike patches the built bundle. The real
  build needs an option upstream, or the same patch as a release step.
- Homebrew's Erlang ships its runtime files read-only, which breaks the
  installer's ad-hoc codesign; a release step makes them writable first.
- The installer needs `priv/icon.png`.
- `mix deps.get` reports an advisory on `saxy` (XML comment injection in
  its encoder), pulled in by `desktop` for Linux's D-Bus; nothing speccy
  runs encodes XML with it.

## Not done

- Not signed with a Developer ID or notarized; ad-hoc only, run from the
  build folder rather than installed from the DMG.
- `open` from Finder or the Dock (Apple Events), and how the app installs
  the PATH link from its menu.
- No LiveView: the window shows a plain page. The canvas in this window
  is the next prototype.
