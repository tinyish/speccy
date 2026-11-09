# Coverage audit: the 24 primitives against Material 3 and Untitled UI v8

Read-only audit of all 190 component sets in `raw/`, against the final 24
primitives (button, input, checkbox, select, slider, file-upload, form,
link, progress, dialog, popover, menu, radio-group, list, table, text,
container, divider, video, date-picker, tree-view, toast, otp-input,
image) and the composition format in `../spec-format/README.md`.

Updated after button got icons and container got `pressable` and roles
(see the catalog README): the rows that needed only those are now "yes".
The color input, added after this audit, is not re-counted here.
Calendar was brought back and then removed again, so it is still missing.

## 1. Verdict

Almost all of both kits composes: **178 of 190 sets can be built** (132 as
they are, 46 only once a gap below is closed). **12 cannot**: they need
three missing primitives (**chart**, **rich-text**, **calendar**) and a
color value that only a restored `input` type gives. Most of the work is in
the format, not the primitive list. The two gaps that blocked the most
sets, **semantic roles** (25) and **content inside pressables** (16), are
closed: 27 sets moved to "yes" (the rest still have another gap). The
biggest left are **rich options** (11), **scrolling** (7), **computed
values** (7) and **keyboard and focus** (6).

## 2. Missing primitives

Ranked by how many sets need them. "Can't be composed" means no
arrangement of the 24 plus states, interactions and `repeat` gives the
behavior.

### 2.1 chart (5 sets, Untitled only)

- **What no composition gives:** it maps data to geometry (scales, axes,
  lines, arcs, radar polygons), and a pointer over the plot picks the
  nearest datum (crosshair or marker, tooltip). It also needs an accessible
  data-table alternative. `container` and `progress` can only fake one bar.
- **Needed by:** Line and bar chart, Pie chart, Radar chart, Chart marker
  (its hover part), and Metric item (types Chart 01 to 04, a sparkline).
  Activity gauge does *not* need it: it is concentric circular `progress`
  in a stack.
- **Proposed:** `chart`: props `type` (line|bar|area|pie|radar), `rows`
  (model[]), `x` (field), `series` (fields[]), `legend` (bool); events
  `hover` (model, the datum) and `select` (model).

### 2.2 rich-text (5 sets, Untitled only)

- **What no composition gives:** formatted text the user edits in place.
  It holds marks over arbitrary ranges (bold, link, list, heading). It
  fires selection events, and a floating toolbar is anchored to the
  selection. `input` multiline holds plain text only. A toolbar of
  `button`s can be composed, but it has nothing to apply its commands to.
- **Needed by:** Text editor, Text editor toolbar, Text editor tooltip,
  Text highlight, and Modal (its "Text editor" example).
- **Proposed:** `rich-text`: props `value` (text: markdown or HTML),
  `marks` (text[], the formats allowed), `placeholder`, `disabled`; events
  `change` (text) and `select` (text, the selected range). Its toolbar is a
  part of it, configured by `marks`.

### 2.3 color (3 sets, Untitled only): restore `input type=color`, not a new primitive

- **What no composition gives:** choosing one color value. The in-page
  picker's saturation/brightness area is a two-axis control (one pointer
  and the arrow keys set two values at once), which `slider` (one axis)
  can't give. The hue and alpha sliders, the hex `input` and the swatch
  rows (`radio-group`) do compose.
- **Needed by:** Color picker, Color picker dropdown, Color picker modal.
- **Proposed:** add `color` to `input`'s types (value: hex text, `change`).
  The 47-entry catalog had this as `color-picker`, and it was dropped from
  the 24. The panel's look is Figma's. Its eyedropper is a platform action
  (§3). Add a `color-area` (x, y, change) primitive only if teams must
  specify the in-page panel itself.

### 2.4 calendar (1 set, Untitled only)

- **What no composition gives:** the week and day views place events by
  time: start time sets the y position, duration sets the height, and
  overlapping events share the width. The format has no layout driven by a
  value. The month view almost composes (a 7-column `container` grid, then
  `repeat` over days, each day a `button`), but the format can't produce
  the days of a month (§3, computed values) or move around the grid with
  the arrow keys (§3, keyboard).
- **Needed by:** Calendar (month, week and day views). The date pickers'
  grids are not affected: `date-picker` owns them.
- **Proposed:** `calendar`: props `view` (month|week|day), `date` (text),
  `events` (model[] with start, end, title); events `select-date` (text),
  `select-event` (model), `change-view` (text), `navigate` (text).
  Optional: `move` and `resize` (model) for drag-to-reschedule.

### Candidates rejected

| Candidate | Why it is not a primitive |
|---|---|
| icon | Glyphs are visual, so Figma owns how they look. `button` names one (`leadingIcon`, `trailingIcon`: a Material Symbols name) and is icon-only with no text, `label` naming it. A standalone icon is an `image` (`alt=""` when decorative). Images that come from data (avatars, flags, favicons) inside something pressable go in a pressable `container`. |
| scroll area, carousel snap, infinite scroll | Scrolling is a capability of `container`, not a widget (§3, scrolling). Neither kit has an infinite-scroll component. |
| drag and drop beyond list reordering | Only Tree view (moving a node to another parent) needs it, and that's a prop on `tree-view`. Bottom sheet's drag handle and Modal's image crop are gestures (§3). File drops belong to `file-upload`. |
| code block with copy | `text` (preformatted) plus a copy `button`. Syntax colors are visual. What's missing is the copy-to-clipboard action and a `pre` prop on `text`. |
| color area, eyedropper | See 2.3. The eyedropper is a platform action (§3). |
| rating | Neither kit has a rating input. Table cell's "Star ratings" is display only (`text` or `image`). An input would be a `radio-group`. |
| link vs button | Keep both: one navigates (it has an `href` and can open in a new tab), the other runs an action. Navigation, breadcrumbs and steps use a pressable `container` with `href` (a link) and `current` (aria-current). |
| keyboard shortcut / kbd | Showing one is `text`. Binding one (⌘K opens Command bar) is a format gap (§3, keyboard). |
| live region / announcements | `toast` is a live region. Inline Alert and Banner are a `container` with role `alert` or `status`. |
| resizable panels | No set in either kit has them. |
| virtualized long lists | Not a behavior, only how the implementation renders. `repeat` with scrolling covers it. |
| combobox / autocomplete (Search, Command bar) | `select` with `searchable` already has the behavior: typing filters, arrow keys move through the options and focus stays in the field. It lacks two props: free text (a value outside the options) and an inline list (always open, not a popup). |
| audio | Message's Audio type is `video` with an audio source. Widen `video` into a media primitive with `kind` audio|video. |
| tabs, accordion, carousel, navigation, breadcrumbs, pagination, stepper, toolbar, alert, avatar group (dropped from the 47) | All compose. Carousel, pagination and scrollable tabs still need the scrolling or computed-values gaps below closed. |

## 3. Format gaps

Capabilities the composition format lacks. The counts are sets from the
table in §4.

| Gap | What is missing | Sets | Which |
|---|---|---|---|
| **roles** (closed) | Was: a `container` couldn't take a semantic role or ARIA relation (`nav` landmark, `aria-current`, tablist/tab/tabpanel with `aria-controls`, `toolbar`, disclosure `aria-expanded`, `alert`/`status`). Now container has `role` (navigation, toolbar, tablist, tab, tabpanel, alert, status, group, region), `current` (page, step), `selected`, `expanded` and `controls`; how they combine is in the catalog README's composition rules, enforced once the catalog is in the editor. `link` itself still has no `current`: a pressable container with `href` carries it. | 0 (was 25) | Were: Navigation Rail, Navigation Rail: Expanded, Navigation Bar ×2, XR Navigation Rail and bar, Tabs, Toolbar, XR Toolbar, List (expandable), List item - Accordion (M); Alert, Banner, Sidebar navigation, Header navigation, Breadcrumbs, Pagination, Progress steps ×5, Horizontal and Vertical tabs, Code snippet (U) |
| **content inside pressables** (closed) | Was: `button` and `link` held only text, so avatars, flags and favicons from data, a badge on a nav item and whole clickable cards couldn't sit inside one. Now button has `leadingIcon` and `trailingIcon` (glyph names) and an icon-only form, and anything richer is a pressable `container` (a button, or a link with `href`) holding it. `button` and `link` still hold only text, and nothing pressable sits inside a pressable (a non-interactive badge on a nav item is `text`). | 0 (was 16) | Were: Stacked card, Horizontal card, Assistive chip, Input chip, Navigation Rail ×2, Navigation Bar ×2, XR Navigation ×2, Search bar (M); Sidebar navigation, Header navigation, Badge, Dropdown menu, Tag (U) |
| **rich options** | `options` and `items` are `text[]` in `select`, `menu`, `radio-group` and `button`. The kits need per-option icon, avatar or dot, supporting text, shortcut, badge, disabled, groups with section labels, and checkable menu items. Radio card items carry arbitrary content. Proposed: options become a model (label, value, description, image, shortcut, group, disabled, checked, children), or these primitives take children. Tabs no longer need it: a tab is a pressable container holding anything. | 11 | Menu, Menu (baseline), Menu item/Standard, Menu item/Vibrant (M); Select, Multi-select, Dropdown menu, Context menu, Radio group, Radio group item, Command bar (U) |
| **keyboard and focus** | No global shortcuts (⌘K), and no action that moves focus (focus the search field when the search view opens). Roving focus is closed for `tablist` and `toolbar` containers (a composition rule), but not for a grid. Proposed: `on` accepting key events (`"key:mod+k"`), and a `focus` action. | 6 | Search full-screen and docked ×4 (M); Command bar, Select (its shortcut hint) (U). The Calendar month grid needs grid roving focus too. |
| **scrolling** | `container` has `clip` but not scroll: no scroll axis, snap, scroll-to-item, or event when scrolled or at an edge (elevate on scroll, collapse a large app bar, load more). Proposed: `scroll` (x, y or both), `snap`, and `scrolled` and `end` events on container. | 7 | App bar, Carousel, Carousel - Full screen, Chip groups (single row), Scrollable list dialog, Tabs (scrollable) (M); Carousel image (U) |
| **computed values** | Bindings are paths and states set literals, so nothing can be computed: a count (+N avatars, character counter), an index ±1 (carousel next, number stepper), a page window with ellipses, appending to a local list (tags), the days of a month. Proposed: a small set of named derivations (`count`, `length`, `add`, `append`, `remove`, `range`), or else these have to become data operations. | 7 | Text field (M); Calendar, Pagination, Carousel image, Avatar group, Input field (counter, tags), Textarea input field (tags) (U) |
| **nesting** | Menu options are flat, so there are no submenus. Nested nav sections need a component that uses itself, and the format doesn't say whether that is allowed or how it ends (with `repeat` over `item.children` it would end naturally). | 5 | Menu, Menu (baseline) (M); Sidebar navigation, Dropdown menu, Context menu (U) |
| **hover reveal** | Only `popover` reacts to hover. A container can't show its own children while it is hovered or holds focus (row actions, a message's action panel). Proposed: `hover` and `focus-within` events on container, to enter and exit a state. | 2 | Message, Table (U). Common in real list rows too. |
| **platform actions** | No action for copying to the clipboard, or for reading a color with the eyedropper (or sharing). Proposed: a `copy` action (with text), plus `eyedrop` as a color-input feature. | 2 | Code snippet, Color picker (U). Modal and Slide out menu "Share project" examples copy a link too. |
| **gestures** | Drag outside of `list`: a sheet resized or dismissed by its handle, with snap heights; an image crop box. Proposed: `detents` and `draggable` on bottom `dialog`. Image crop is a candidate primitive if teams spec it. | 2 | Bottom sheet (M); Modal (its Image crop example) (U) |
| **timers** | Nothing is driven by time: a countdown, an auto-advancing carousel. `toast` should own its auto-dismiss duration. | 1 | Banner (Countdown) (U) |
| **breakpoints** (minor) | Untitled states by breakpoint (tabs collapse to a select, nav to a drawer) can only be written as a state's `about` ("on mobile"). That works, but nothing checks it. | - | Most Untitled sets with a Breakpoint property |

### Prop gaps on the 24

Not format changes, but props the kits need on primitives that exist:

- **select**: free-text value and an inline (always open) list, for
  combobox and command palette (Search ×4 (M), Command bar (U)); an
  empty-search message (Multi-select).
- **table**: per-column cell content as a component (avatar, badges,
  progress, select, actions, trend) (Table cell, Table); a `sort` event
  from headers and a select-all with indeterminate (Table header cell);
  single-selection mode (Table cell lead action).
- **slider**: `orientation` vertical (Standard slider, Centered slider).
- **date-picker**: presets and a footer (quick ranges, time slots),
  because it holds no children (Date picker dropdown, Date picker modal).
- **list**: keep the `swipe` event from the 47-entry `list` (List Item -
  Swipe).
- **toast**: content (image, avatar, progress) and `duration`
  (Notification, Snackbar).
- **tree-view**: checkable nodes with indeterminate parents, drag to move
  between parents, and an image or icon per node (Tree view, Advanced
  type).
- **file-upload**: files as a model with progress and status, not
  `text[]` (File upload).
- **input**: prefix and suffix text ("https://") and an input mask
  (payment) (Input field).
- **text**: `pre` (keep whitespace, monospace) (Code snippet).
- **video**: audio (Message).
- **checkbox**: keep `indeterminate` (Checkboxes, Checkbox, Table header
  cell, Tree view).

## 4. Component table

"Built from" names primitives. "Missing" names a primitive from §2, a
format gap from §3, or `prop:` from the prop gaps above.

### Material 3

**App bars**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| App bar | yes with gap | container, text, button, image, input | scrolling |
| XR/XR App Bar | yes | container, text, button | - |
| Bottom app bar | yes | container, button | - |

**Badges**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Badges | yes | button (badge), container (stack) | - |

**Buttons**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Segmented button | yes | radio-group (segmented); button (selected) for multi | - |
| Toggle button | yes | button (selected) | - |
| Button | yes | button | - |
| Button - text | yes | button | - |
| Button - elevated | yes | button | - |
| Button - outline | yes | button | - |
| Button - tonal | yes | button | - |
| Toggle button - elevated | yes | button (selected) | - |
| Toggle button - outline | yes | button (selected) | - |
| Toggle button - tonal | yes | button (selected) | - |
| Icon button | yes | button (label) | - |
| Icon button - standard | yes | button (label) | - |
| Icon button - outline | yes | button (label) | - |
| Icon button - tonal | yes | button (label) | - |
| Icon button togglable | yes | button (selected, label) | - |
| Icon button togglable - tonal | yes | button (selected, label) | - |
| Icon button togglable - outline | yes | button (selected, label) | - |
| Icon button togglable - standard | yes | button (selected, label) | - |
| Split button | yes | button (split menu) | - |
| FAB menu | yes | button, menu | - |
| Extended FAB | yes | button | - |
| FAB | yes | button | - |
| Connected button group | yes | radio-group (segmented); button (selected) for multi | - |
| Standard button group | yes | container, button | - |

**Cards**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Stacked card | yes | container (pressable), image, text, button | - |
| Horizontal card | yes | container (pressable), image, text, button | - |

**Carousel**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Carousel - Full screen | yes with gap | container, image, text | scrolling |
| Carousel | yes with gap | container, image, text | scrolling |

**Checkboxes**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Checkboxes | yes | checkbox | - |

**Chips**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Suggestion chip | yes | button | - |
| Filter chip | yes | button (selected, split menu) | - |
| Assistive chip | yes | button (leadingIcon); container (pressable) + image for a favicon | - |
| Input chip | yes | button (removable, leadingIcon); container + image beside its remove button | - |
| Chip groups | yes with gap | container (row, wrap), button | scrolling |

**Date & time pickers**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Docked input date picker [desktop] | yes | date-picker | - |
| Input date picker | yes | date-picker | - |
| Modal date picker | yes | date-picker | - |
| Dial picker | yes | input (time); the dial is presentation | - |
| Keyboard picker | yes | input (time); the dial is presentation | - |

**Dialogs**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Basic dialog | yes | dialog, text, list, container, button | - |
| List dialog | yes | dialog, text, list, container, button | - |
| Scrollable list dialog | yes with gap | dialog, list | scrolling |
| XR/XR Dialog | yes | dialog, text, list, container, button | - |

**Dividers**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Vertical/Middle-inset | yes | divider (+ text) | - |
| Vertical/Inset | yes | divider (+ text) | - |
| Vertical/Full-width | yes | divider (+ text) | - |
| Horizontal/Divider with subhead | yes | divider (+ text) | - |
| Horizontal/Middle-inset | yes | divider (+ text) | - |
| Horizontal/Inset | yes | divider (+ text) | - |
| Horizontal/Full-width | yes | divider (+ text) | - |

**Lists**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| List item/List Item: -4 Density (baseline) | yes | container, text, image, checkbox, button | - |
| List item/List Item: -2 Density (baseline) | yes | container, text, image, checkbox, button | - |
| List item/List Item: 0 Density (baseline) | yes | container, text, image, checkbox, button | - |
| List: -4 Density (baseline) | yes | list | - |
| List: -2 Density (baseline) | yes | list | - |
| List (baseline) | yes | list | - |
| List | yes | list, container (pressable, expanded, controls) | - |
| List item | yes | container, text, image, checkbox, button | - |
| List item - Accordion | yes | container (pressable, expanded, controls), container | - |
| List Item - Swipe | yes with gap | list, container, button | prop: list-swipe |

**Loading & progress**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Linear-determinate progress indicator | yes | progress | - |
| Linear-indeterminate progress indicator | yes | progress | - |
| Circular-determinate progress indicator | yes | progress | - |
| Circular-indeterminate progress indicator | yes | progress | - |
| Loading indicator | yes | progress | - |

**Menu**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Menu | yes with gap | menu | rich options, nesting |
| Menu item/Standard | yes with gap | menu (an option) | rich options |
| Menu item/Vibrant | yes with gap | menu (an option) | rich options |
| Menu (baseline) | yes with gap | menu | rich options, nesting |

**Navigation**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Navigation Rail | yes | container (navigation; pressable items with href, current), image, text | - |
| Navigation Rail: Expanded | yes | container (navigation; pressable items with href, current), image, text, dialog (left) | - |
| Navigation Bar: Horizontal items | yes | container (navigation; pressable items with href, current), image, text | - |
| Navigation Bar: Vertical items | yes | container (navigation; pressable items with href, current), image, text | - |
| XR/XR Navigation Rail | yes | container (navigation; pressable items with href, current), image, text | - |
| XR/XR Navigation bar | yes | container (navigation; pressable items with href, current), image, text | - |

**Radio button**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Radio buttons | yes | radio-group | - |

**Search**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Search bar | yes | input, button (icon only), container (pressable) + image for the avatar | - |
| Search full-screen layout | yes with gap | input, list, dialog/container | prop: select-combobox, keyboard |
| Search docked layout | yes with gap | input, list, dialog/container | prop: select-combobox, keyboard |
| Search full-screen layout (baseline) | yes with gap | input, list, dialog/container | prop: select-combobox, keyboard |
| Search docked layout (baseline) | yes with gap | input, list, dialog/container | prop: select-combobox, keyboard |

**Sheets**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Side Sheet | yes | dialog (right, modal or not); container | - |
| Bottom sheet | yes with gap | dialog (bottom) | gestures |

**Sliders**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Standard slider | yes with gap | slider | prop: slider-vertical |
| Centered slider | yes with gap | slider | prop: slider-vertical |
| Range slider | yes | slider (range) | - |

**Snackbar**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Snackbar | yes | toast | - |

**Switch**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Switch | yes | checkbox (switch) | - |

**Tabs**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Tabs | yes with gap | container (tablist, tab, tabpanel) | scrolling |

**Text fields**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Text field | yes with gap | input, button | computed values |

**Toolbars**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Toolbar | yes | container (toolbar), button | - |
| XR/XR Toolbar | yes | container (toolbar), button | - |

**Tooltips**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Plain Tooltip | yes | popover (hover) | - |
| Rich Tooltip | yes | popover (hover) | - |

### Untitled UI v8

**Activity feeds**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Activity feed | yes | list, container, image, text, link | - |

**Alerts & notifications**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Alert | yes | container (alert), text, button | - |
| Notification | yes with gap | toast | prop: toast-content |

**Application navigation**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Sidebar navigation | yes with gap | container (navigation, pressable items), link, button, dialog (left), popover, image | nesting |
| Header navigation | yes | container (navigation, pressable items), link, menu, popover, dialog | - |

**Breadcrumbs**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Breadcrumbs | yes | container (navigation; pressable with href, current page), link, text, menu | - |

**Calendars**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Calendar | no | container (grid), button, text (month view only) | calendar, computed values |

**Card headers**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Card header | yes | container, text, image, button | - |

**Charts**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Line and bar chart | no | - | chart |
| Activity gauge | yes | container (stack), progress, list | - |
| Pie chart | no | - | chart |
| Radar chart | no | - | chart |
| Chart marker | no | - | chart |

**Code snippets**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Code snippet | yes with gap | text, button, container (tablist, tab, tabpanel) | platform actions, prop: text-pre |

**Color pickers**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Color picker | no | slider, input, radio-group, select, button | color input, platform actions |
| Color picker dropdown | no | button, popover / dialog | color input |
| Color picker modal | no | button, popover / dialog | color input |

**Command menus**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Command bar | yes with gap | dialog, select (searchable) | prop: select-combobox, rich options, keyboard |

**Content dividers**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Content divider | yes | container, divider, text, button | - |

**Date pickers**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Date picker dropdown | yes with gap | date-picker, list | prop: date-picker-presets |
| Date picker modal | yes with gap | date-picker, list | prop: date-picker-presets |

**Empty states**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Empty state | yes | container, image, text, button | - |
| Illustration | yes | image | - |

**File upload**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| File upload | yes with gap | file-upload | prop: file-progress |

**Filters**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Filters dropdown menu | yes | button, popover, checkbox, select | - |
| Filters slideout menu | yes | dialog (right), form, checkbox, select, date-picker, slider | - |
| Filters bar | yes | container, radio-group, input, date-picker, button | - |

**Inline CTAs**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Inline CTA | yes | container, image, text, input, button | - |

**Loading indicators**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Loading indicator | yes | progress (indeterminate) | - |

**Messaging**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Message | yes with gap | container, text, image, video, link, button | hover reveal, prop: video-audio |
| Message action | yes | form, input (multiline), button, file-upload | - |

**Metrics**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Metric item | yes with gap | container, text, button (badge), menu | chart |

**Modals**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Modal | yes with gap | dialog + any content | rich-text, gestures |

**Page headers**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Page header | yes | container, text, image, link, button, input, radio-group | - |

**Pagination**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Pagination dot group | yes | radio-group | - |
| Pagination | yes with gap | container (navigation; pressable, current page), button, select | computed values |
| Carousel image | yes with gap | container (stack), image, button, radio-group | computed values, scrolling |

**Progress steps**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Progress steps / Progress minimal icons connected | yes | container (current step), text, image, divider | - |
| Progress steps / Progress minimal icons | yes | container (current step), text, image, divider | - |
| Progress steps / Progress text with line | yes | container (current step), text, image, divider | - |
| Progress steps / Progress icons centered | yes | container (current step), text, image, divider | - |
| Progress steps / Progress icons with text | yes | container (current step), text, image, divider | - |

**Section footers**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Section footer | yes | container, text, button, input, radio-group | - |

**Section headers**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Section header | yes | container, text, button, input, radio-group | - |
| Section label | yes | container, text, button, input, radio-group | - |

**Slideout menus**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Slide out menu | yes | dialog (right) + content | - |

**Tables**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Table header cell | yes with gap | table (header), checkbox | prop: table-sort |
| Table cell | yes with gap | table (cell) | prop: table-cells |
| Table | yes with gap | table | prop: table-cells, prop: table-sort, hover reveal |
| Table cell lead action | yes with gap | table (selectable) | prop: table-single |

**Tabs**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Horizontal tabs | yes | container (tablist, tab, tabpanel), select (mobile) | - |
| Vertical tabs | yes | container (tablist, tab, tabpanel), select (mobile) | - |

**Tree views**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Tree view | yes with gap | tree-view | prop: tree-check-move |

**Avatars**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Avatar label group | yes | container, image, text | - |
| Avatar profile photo | yes | image (fallback), container (stack) | - |
| Avatar group | yes with gap | container (row), image, button | computed values |
| Status icon | yes | container or image | - |
| Avatar | yes | image (fallback initials), container (stack) | - |

**Badges**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Badge | yes | button (badge, icons); container + image for a dot, flag or avatar | - |
| Badge group | yes | container, button (badge), text | - |

**Button groups**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Button group | yes | radio-group (segmented) or button (selected) | - |

**Buttons**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Buttons/Button | yes | button | - |
| Buttons/Social button | yes | button | - |
| Buttons/Social button group | yes | button | - |
| Mobile app store badge | yes | link | - |
| Buttons/Button close X | yes | button | - |
| Buttons/Button destructive | yes | button | - |
| Buttons/Button utility | yes | button | - |
| Buttons/Button loading icon | yes | progress (indeterminate) | - |

**Checkboxes**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Checkbox | yes | checkbox; radio-group for Type=Radio | - |

**Dropdowns**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Dropdown menu | yes with gap | menu, button | rich options, nesting |
| Context menu | yes with gap | menu (contextmenu) | rich options, nesting |

**Inputs**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Input field | yes with gap | input, select, button, container | computed values, prop: input-affix |
| Verification code input field | yes | otp-input | - |
| Textarea input field | yes with gap | input (multiline), button (removable) | computed values |

**Progress indicators**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Progress bar | yes | progress | - |
| Progress circle | yes | progress | - |

**Radio groups**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Radio group item | yes with gap | radio-group | rich options |
| Radio group | yes with gap | radio-group | rich options |

**Select**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Select | yes with gap | select | rich options, keyboard |
| Multi-select | yes with gap | select (multiple, searchable) | rich options |

**Sliders**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Slider | yes | slider (range) | - |

**Tags**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Tag | yes | button (removable, selected); container (pressable) + image for an avatar or flag | - |

**Text editors**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Text editor toolbar | no | - | rich-text |
| Text editor tooltip | no | - | rich-text |
| Text highlight | no | - | rich-text |
| Text editor | no | - | rich-text |

**Toggles**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Toggle | yes | checkbox (switch) | - |

**Tooltips**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Tooltip | yes | popover (hover) | - |
| Help icon | yes | button (label), popover (hover) | - |

**Video players**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Video player 16:9 | yes | video | - |

**Banners**

| Set | Buildable? | Built from | Missing |
|---|---|---|---|
| Banner | yes with gap | container (status or alert), text, button, input | timers |
