# Component catalog

A merged, behaviour-first list of speccy's primitives, read from two Figma
kits: Material 3 Design Kit and Untitled UI v8. `raw/` holds the 190
component sets as read from Figma; `catalog.json` is the result, and
`primitives/` one renderable file per entry (see `RENDER.md`).

A primitive has behaviour unique enough to be its own thing. Anything that
can be built from primitives is not one: it lives in `composed`, with the
primitives it is built from, as the seed of a future component library.

How it was built:

- **One entry per behaviour.** Sets that behave the same are merged across
  and within kits (Material's five button styles, FABs, icon buttons and
  Untitled's buttons are all `button`). Variants of one behaviour are a
  prop, not an entry: switch is a checkbox `role`, multi-select a select
  that is `multiple`, a sheet a dialog `placement`, a tooltip a popover
  opened on hover.
- **Props are behaviour.** Each Figma property is mapped to a prop or
  state, or listed under `dropped`: size, colour, hierarchy, density,
  shape, elevation, breakpoint and hover/focus/pressed states are
  dropped. Icons are kept as glyph names (button's `leadingIcon` and
  `trailingIcon`). Props and events use the `primitives.json` types, so an
  entry can be copied there, plus one new one: `model` / `model[]`, any
  data model, chosen by the instance that binds it, for structured values
  (tree items, table rows).
  Each such entry's notes say which fields the model needs. The checker
  doesn't support it yet.
- **Primitives only.** Components that can be composed from primitives
  (toolbar, tabs, card, navigation…) are in `composed`, each with its
  `builtFrom` and the sets it came from. Patterns (assemblies with app
  content: page header, empty state, activity feed, metric, chat message,
  message composer, filters, inline CTA, section header and footer) were
  left out on Alberto's call: their sets are in `skipped`.
- **Every set is accounted for once**, in an entry's or a composed item's
  `sources` (sub-parts, baseline and XR duplicates marked in the source
  name) or in `skipped`.
- Nine of the ten existing primitives keep their names (`existing: true`,
  * below); textarea is folded into `input`.

## Counts

24 primitives (119 sets); 15 composed (42 sets); 29 sets skipped (16 from the patterns left out, 11 from rich-text-editor, chart, code-block and calendar, which Alberto removed, Untitled's button loading spinner, and Untitled Illustration).

By category: actions 1, inputs 6, selection 3, navigation 2, feedback 2, overlays 3, data-display 3, layout 2, media 2.

From both kits: 13; Material only: 1; Untitled only: 8; neither (existing, no kit set): 2.

## Entries

Sorted by category (in the order above), then name. Material and Untitled list the source sets, or ✓ (count) when there are more than two.

| Name | Kind | Category | Element | Material | Untitled |
|---|---|---|---|---|---|
| button * | primitive | actions | `button` (icons, icon-only; + menu or remove button) | ✓ (25) | ✓ (8) |
| date-picker | primitive | inputs | `input type=date (with calendar popup)` | ✓ (3) | Date picker dropdown, Date picker modal |
| file-upload | primitive | inputs | `input type=file (with drop zone)` |  | File upload |
| form * | primitive | inputs | `form` |  |  |
| input * | primitive | inputs | `input` (textarea when multiline) | Text field | Input field, Textarea input field |
| otp-input | primitive | inputs | `input autocomplete=one-time-code (one box per digit)` |  | Verification code input field |
| slider | primitive | inputs | `input type=range` (two handles when range) | ✓ (3) | Slider |
| checkbox | primitive | selection | `input type=checkbox` (role=switch) | Checkboxes, Switch | Checkbox, Toggle |
| radio-group | primitive | selection | `role=radiogroup` (of radios or buttons) | ✓ (3) | ✓ (3) |
| select * | primitive | selection | `select` (listbox aria-multiselectable when multiple) |  | Select, Multi-select |
| link * | primitive | navigation | `a` |  | Mobile app store badge (store badge) |
| tree-view | primitive | navigation | `role=tree` |  | Tree view |
| progress | primitive | feedback | `progress` | ✓ (5) | ✓ (3) |
| toast | primitive | feedback | `role=status (live region)` | Snackbar | Notification |
| dialog * | primitive | overlays | `dialog` (modal or not, centred or on an edge) | ✓ (6) | Modal, Slide out menu |
| menu | primitive | overlays | `role=menu` (from a button or contextmenu) | ✓ (5) | Dropdown menu, Context menu |
| popover | primitive | overlays | `[popover] role=dialog` (role=tooltip on hover) | Rich Tooltip, Plain Tooltip | Tooltip, Help icon (help-icon trigger) |
| list * | primitive | data-display | `ul` | ✓ (9) |  |
| table | primitive | data-display | `table` |  | ✓ (4) |
| text * | primitive | data-display | `p` |  |  |
| container * | primitive | layout | `div` (a role; button or link when pressable) | Standard button group (layout group), Chip groups (layout group) | Buttons/Social button group (layout group) |
| divider | primitive | layout | `hr` | ✓ (7) | Content divider |
| image | primitive | media | `img` (fallback when no src) |  | ✓ (4) |
| video | primitive | media | `video` |  | Video player 16:9 |

## Composed

Built from primitives, not primitives themselves (Alberto's plan).

| Name | Built from |
|---|---|
| toolbar | container, button |
| search | input, button, menu |
| time-picker | select, input |
| color-picker | slider, button, input, popover |
| breadcrumbs | link, list |
| navigation | list, button, link |
| pagination | button |
| stepper | list, text |
| tabs | radio-group, container |
| alert | container, text, button |
| command-palette | dialog, input, menu |
| accordion | button, container |
| card | container |
| avatar-group | image |
| carousel | container, button |

## Judgement calls

- **checkbox and radio-group leave `input`.** Today they are `input` types; they carry a bool and a group value, so they are entries of their own and `input` keeps text-like types.
- **Chips are split by behaviour, not kept as "chip".** Assist and suggestion chips are `button`, filter chips `button` (selected), input chips a removable `button` (with Untitled Tag), chip groups `container`.
- **Combobox is a `searchable` prop** on select and menu, not an entry: no set is a combobox on its own (Untitled Select Type=Search is a variant).
- **progress merges** determinate, indeterminate and spinner/loading indicators: one control, value or none.
- **date-picker `value` is `text[]`** so one entry covers single dates and ranges.
- **Material's top app bar went with page-header**, which was left out as a pattern; it could come back as an `app-bar` primitive.
- **Structured values bind to data models** (Alberto's call): tree-view and table take `model[]`; a range slider keeps start and end, and date-picker a `text[]` of dates.
- **text and form have no kit set**; they stay for completeness. Untitled Illustration is the only skipped set.
- **One button** (Alberto's call): toggle-button and split-button are folded into `button`, which takes a `size` (sm, md, lg), `selected` for toggles, and optional `options` with `open` for a split menu.
- **No loading states** (Alberto's call): button's `loading` and file-upload's `uploading` are gone. `progress` stays: it is the indicator itself, not a state of something else.
- **Tag and badge are buttons too** (Alberto's call): a small button, `selected` for a selected tag, `removable` (with a `remove` event) for input chips; tag's count goes into the text.
- **Primitives must be their own thing** (Alberto's call): toolbar, search, time-picker, color-picker, breadcrumbs, navigation, pagination, stepper, tabs, alert, command-palette, accordion, card, avatar-group and carousel are composed from primitives, and moved to `composed`.
- **Variants of one behaviour are props** (Alberto's call): textarea is input `multiline`; switch is checkbox `role: switch`; multi-select is select `multiple` (`values`, and `change` carries a list, one item when single); range-slider is slider `range` (`start`, `end`, with `changeStart` and `changeEnd` since the vocabulary has no number pair); sheet is dialog `placement` (left, right, bottom) and `modal`; tooltip is popover `trigger: hover` (text only, no actions); context-menu is menu `trigger: contextmenu`, which is why menu takes children (the area it wraps); segmented-control is a horizontal radio-group (`orientation`), one template.
- **avatar became `image`** (Alberto's call): a picture with a `fallback` (initials) shown when there is no src or it fails (`broken`). Status, verified mark and name beside it are composed; Untitled's avatar sets moved to it, and avatar-group is composed from it.
- **Icons are Material Symbols names** (Alberto's call): button takes `leadingIcon` and `trailingIcon`, each a name from fonts.google.com/icons (`save`, `close`). A name says which glyph; how it looks stays in Figma. With no `text` the button is icon-only, and `label` is its accessible name. Icon is still not a primitive.
- **Containers can be pressed and carry roles** (Alberto's call): `pressable` (with a `press` event) makes a container a button, or a link with `href`, so cards and nav items are containers holding other primitives. `role` gives it a landmark or widget role (navigation, toolbar, tablist, tab, tabpanel, alert, status, group, region); `current` (page, step), `selected`, `expanded` and `controls` give aria-current, aria-selected, aria-expanded and aria-controls. Tabs, navigation, accordions and inline alerts compose from it; how they combine is in Composition rules below.
- **Examples are not states**: sizes, icons and icon-only are shown as a primitive file's `examples` (see `RENDER.md`), not as states, which stay behaviour.
- **After the coverage pass** (`coverage.md`, Alberto's call): `color` is an input type, so colour pickers compose. Chart and rich-text stay out. Most remaining gaps are in the composition format (rich options, scrolling, computed values, keyboard shortcuts and focus, nesting); roles and content inside pressables were closed by button icons and pressable containers. See `coverage.md`.

## Composition rules

Enforced when the catalog moves into the editor: they constrain how
instances combine, so the editor's spec checker owns them, not
`validate.mjs`, which checks one primitive file at a time.

- **Nothing pressable inside a pressable.** No button, link, input or
  other control, and no pressable container, inside a pressable container
  or a button. A card with its own actions is a container holding a
  pressable area and the buttons side by side.
- **`tab` only inside `tablist`**, and a `tabpanel` belongs to a `tab`: the
  tab's `controls` names the panel's id.
- **`controls` names an existing container id**, in the same spec.
- **`current` only on pressables or links.**
- **`tablist` and `toolbar` give arrow-key roving focus** to their
  pressable children: the group is one Tab stop, and the arrow keys move
  between its items.
- **`alert` and `status` are live regions**: what they show is announced
  when it appears (alert interrupts, status waits).
- **Calendar is out for now** (Alberto's call): it came back after the coverage pass and was removed again; its Untitled set is in `skipped`, and `coverage.md` keeps what it would need.
