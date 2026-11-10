# MVP 2: the desktop window

Bead: spec-eai

The editor page (part 006) in elixir-desktop's window, packaged as a
macOS app, from what the two prototypes proved: `prototypes/cli-bundle`
(the bundle, the `speccy` launcher, `open`) and `prototypes/desktop-canvas`
(the canvas in the window, the menu, the folder picker).

## Program design

### The app and its build

- `mix.exs` gains `desktop`, `desktop_webview` and `desktop_deployment`
  (`runtime: false`) from GitHub, the package name and identifier, and a
  `speccy` release whose steps assemble, make the release writable and
  build the installer, as `prototypes/cli-bundle/mix.exs` does.
- `rel/env.sh.eex` keeps the folder the host was launched with as
  `SPECCY_OPEN`; `rel/speccy` is the launcher, `cli-bundle`'s `speccy`
  script, shipped as `Contents/MacOS/speccy`.
- `bin/build-app` does what `cli-bundle`'s README does by hand: builds the
  host from source with Swift, the installer, sets `instances = single`
  in the host's ini, copies the launcher in and signs ad hoc. The
  project's README says how to build and install it.

### The window

- The window runs only where there is a host: in the release, and in
  development with `SPECCY_WINDOW=1` (the BEAM starts the host, as
  `desktop-canvas` runs). Tests, `mix phx.server` and Playwright get the
  plain local server, as today.
- One `Desktop.Window` on the editor page, with `SpeccyWeb.Menu` as its
  menu bar. Opening a spec points it at `/?spec=<dir>`
  (`Desktop.Window.load_url/2`); the spec shown before is replaced.
- A spec is opened from File > Open…, ⌘O, File > Open Recent, a
  `speccy open` reaching the running app (`{:open_file, [dir]}` from
  `Desktop.Env`) and, at launch, `SPECCY_OPEN`. Every route calls one
  function, which also records the folder in the recent specs. A folder
  that holds no spec shows the page's no-spec message, naming it, and
  isn't recorded.

### The menu

- `SpeccyWeb.Menu`, a `Desktop.Menu`: File > Open… and File > Open
  Recent, the recent specs newest first. The Edit menu is the host's.
- Open… calls `DesktopWebview.Dialog.choose_directory/1` in a task of
  its own, since the picker blocks its caller until dismissed.
- The host gives menu items no key equivalents
  (`decisions.md#shortcuts-in-page`): the page catches ⌘O and pushes an
  event that runs Open…. Only when the window is on; in a browser ⌘O is
  the browser's.

### Recent specs

`~/.speccy/recent.json`: a JSON list of absolute folder paths, newest
first, at most ten, rewritten on every open; a folder that no longer
holds a spec is dropped when read. It touches a file, so it lives in
`lib/speccy_web/` (`conventions.md#pure-core`).

### Keeping other pages out

- `SpeccyWeb.Endpoint` uses `Desktop.Endpoint`, which finds the port the
  release picks at random. It listens on 127.0.0.1 only.
- With the window on, the router's browser pipeline plugs
  `Desktop.Auth`: a request needs the per-launch key the window's URL
  carries (`?k=`, added by `Desktop.Window`), and then holds it in its
  session.
- LiveView checks origin in every environment: dev's
  `check_origin: false` goes. Without the window there is no key, so the
  origin check is what keeps another page in a browser from driving the
  editor.
- The endpoint refuses a request whose `Host` isn't `localhost` or
  `127.0.0.1`, in every environment, so a page reached through DNS
  rebinding can't read the editor back (Alberto, 2026-11-10). Phoenix
  routes sockets before any plug, so LiveView's socket is guarded by
  the origin check alone, which refuses a rebinding page's origin.

### Pinch

A trackpad pinch reaches the page as WebKit's gesture events, not
ctrl+wheel (`core.md` § The editor): the canvas hook (part 006) zooms on
`gesturestart`/`gesturechange`/`gestureend` too, the way
`prototypes/desktop-canvas/lib/page.js` replays them, but in the hook.

## Tests

- **Recent specs**, on a temp home: an open goes to the front, a folder
  opened again moves up and isn't doubled, the eleventh drops the
  oldest, and a folder with no spec is dropped when read.
- **Opening**, without a host: each route reaches the one function; a
  folder with no spec isn't recorded.
- **Keeping other pages out**, `Phoenix.ConnTest` with the auth plug on:
  a request without the key is refused with 401; one with
  `Desktop.Auth.login_key/0` gets the page, and the next request in that
  session needs no key. LiveView's socket refuses a foreign origin. A
  request with another `Host` is refused.
- **By hand**, the host can't run in the suite: the checks in Done when.

## Done when

Alberto builds the app with `bin/build-app` and, with it:

- `speccy open` on the `tasks` fixture opens it, the app closed, and
  again with another spec while it runs;
- File > Open…, ⌘O and File > Open Recent each open a spec, and Cancel
  leaves the one shown;
- a pinch zooms the canvas, and an edit he makes to a file in his editor
  shows without a reload.

## Out of this part

- Installing the `speccy` command on the PATH from the app's menu
  (`core.md` § The command line): linked by hand, as in `cli-bundle`.
- Signing beyond ad hoc, notarizing, an icon of its own.
- One window per open spec.
