# Reference

Quick-lookup tables. For the underlying CLI's reference (subcommands, flags, YAML schema, template variables), see the [runbook CLI Reference](https://github.com/msjurset/runbook/blob/master/docs/guide/04-reference.md).

## Keyboard shortcuts

### Global

| Shortcut | Action |
|----------|--------|
| ⌘K | Open Quick Jump |
| ⌘1 | Go to Runbooks section |
| ⌘2 | Go to History section |
| ⌘3 | Go to Schedules section |
| ⌘4 | Go to Repositories section |
| ⌘? | Open Help window |
| ⌘, | Open Settings (standard macOS) |
| ⌘N | New Runbook (when Runbooks section focused) |
| ⌘Q | Quit Runbook Mac |

### Console tray

| Shortcut | Action |
|----------|--------|
| ⌘F | Toggle search bar |
| ⌘. (period) | Stop the currently-shown running session |
| Return | (in search bar) Next match |
| Shift-Return | (in search bar) Previous match |
| Escape | Close search bar |

### Quick Jump (⌘K sheet)

| Shortcut | Action |
|----------|--------|
| ↑ / ↓ | Navigate matches |
| Return | Select the highlighted match |
| Escape | Dismiss without selecting |

### YAML editor

| Shortcut | Action |
|----------|--------|
| Tab | Insert completion (or Tab if no completion available) |
| Cmd-S | Save (opens Diff sheet if changed) |
| Cmd-W | Close popout multi-line editor (saves) |
| Escape | Cancel inline edit without saving |

### Schedules view (per-row, while editing)

| Shortcut | Action |
|----------|--------|
| Return | Save edit |
| Escape | Cancel edit |

---

## Sidebar sections

| Section | What it shows | What it bridges to in the CLI |
|---------|---------------|-------------------------------|
| Runbooks | Searchable list + detail of every YAML file under `~/.runbook/books/`; templates in a separate section | `runbook list`, `runbook show`, `runbook run`, `runbook validate` |
| History | Every prior run, newest first; per-step expansion with log slices | `runbook history` (CLI shows table; GUI shows tree) |
| Schedules | All `runbook cron`-managed crontab entries | `runbook cron list`, `runbook cron add`, `runbook cron remove` |
| Repositories | Pulled git collections | `runbook pull list`, `runbook pull`, `runbook pull remove` |

The sidebar's bottom toolbar:

| Button | Action |
|--------|--------|
| `+` | Open New Runbook sheet |
| `↻` | Reload runbooks from disk (`store.loadAll()`) |
| `⚙` | Open Settings |

---

## Runbook list

### Per-row affordances

| Affordance | Action |
|-----------|--------|
| Click | Select runbook in detail view |
| Pin icon | Toggle pinned status |
| Right-click | Context menu: Run, Dry Run, Schedule, Pin/Unpin, Duplicate, Delete |

### Context menu actions

| Action | What it does |
|--------|--------------|
| Run | Open Run Confirm Sheet (or run immediately if no variables) |
| Dry Run | Same as Run but with `--dry-run` |
| Schedule | Open Schedule sheet for this runbook |
| Pin / Unpin | Toggle pinned status |
| Duplicate | Open Create-from-Template sheet pre-loaded with this runbook's YAML |
| Delete | Confirm + delete the YAML file (backup written to `~/.runbook/backups/`) |

### Templates section

Runbooks placed in any `templates/` subdirectory are listed here separately. They get an orange `template` badge and the context menu's primary action is **New from Template** instead of Run.

---

## Runbook detail

### Toolbar (top of detail view)

| Button | Action |
|--------|--------|
| `?` | Contextual help popover |
| Pencil | Open YAML editor sheet |
| Schedule | Open Schedule sheet |
| Run (green) | Open Run Confirm Sheet (or run immediately if no variables) |

### Sections

| Section | When shown |
|---------|-----------|
| Header (name, description, summary counts) | Always |
| Variables | If `variables:` is non-empty |
| Steps (expandable) | Always |
| Notifications | If `notify:` is set |
| Recent Runs (last 5) | If history records exist for this runbook |

### Step row collapsed badges

| Badge | Source field |
|-------|-------------|
| `[shell]` / `[ssh]` / `[http]` / `[confirm]` | `type:` |
| Yellow chat bubble | `confirm:` is set |
| Clock | `timeout:` is set |
| `↻` | `on_error: retry` |
| `→` | `capture:` is set |
| `?` | `condition:` is set |
| `‖` | `parallel: true` |

### Step row expanded sections

| Section | When shown |
|---------|-----------|
| Shell config (command, dir) | Step has `shell:` |
| SSH config (host, user, port, key, command, agent_auth) | Step has `ssh:` |
| HTTP config (method, url, headers, body) | Step has `http:` |
| Confirm prompt | `confirm:` is set |
| Options (timeout, on_error, retries, capture, condition, parallel) | Any of these set |

Editable fields support double-click to edit inline; multi-line fields (shell.command, ssh.command, http.body) open the popout editor.

---

## Run Confirm sheet

| Element | Notes |
|---------|-------|
| Variables grid | One row per declared variable; pre-filled from YAML default (op:// values shown but not pre-filled into the input) |
| Dry Run checkbox | Toggle to add `--dry-run` to the CLI invocation |
| Cancel button | Dismiss without running |
| Run / Dry Run button | Button text reflects the Dry Run toggle state |

---

## Console tray

### Tabs

| Element | Action |
|---------|--------|
| Tab body (click) | Switch the tray's focus to that session |
| Tab × | Stop (if running) and dismiss the session |
| Status icon | ▶ running / ✓ succeeded / ✗ failed / ⊘ cancelled |
| `dry` badge | Shown if the session was a dry run |
| Elapsed | Updates every minute (≥ 1 minute) or every second (< 1 minute) |

### Output toolbar

| Button | When shown | Action |
|--------|-----------|--------|
| Find / 🔍 | Always (when output present) | Toggle search bar (⌘F) |
| Line count | Always | Read-only count of output lines |
| Copy All | Always | Copy entire output to clipboard |
| Stop | While running | Cancel the session (⌘.) |
| Dry checkbox | Terminal sessions | Flip dry/real mode for next retry |
| Retry | Terminal sessions | Re-run in place (same tab/ID) with current Dry setting |
| Save | Always | Write output to a `.log` file via NSSavePanel; recorded in LogIndex |

### Collapse states

| State | What's visible |
|-------|---------------|
| Expanded | Tab strip + output area + toolbar |
| Collapsed | Single-line status bar with status icon + name + elapsed + chevron |

---

## YAML editor

### Toolbar

| Button | Action |
|--------|--------|
| Validate | Write current buffer to temp file, run `runbook validate`, show result |
| Save | Open Diff sheet (if changed) → confirm → write to disk |
| Cancel | Discard changes (with confirmation if unsaved) |

### Tab completion contexts

| At cursor position | Suggestions |
|-------------------|-------------|
| Top-level (no indent) | `name:`, `description:`, `variables:`, `steps:`, `notify:`, `log:` |
| Inside `steps:` item | `name:`, `type:`, `shell:`, `ssh:`, `http:`, `condition:`, `confirm:`, `on_error:`, `retries:`, `timeout:`, `capture:`, `parallel:` |
| `type:` value | `shell`, `ssh`, `http` |
| `on_error:` value | `abort`, `continue`, `retry` |
| `mode:` value (under `log:`) | `new`, `append` |
| `on:` value (under `notify:`) | `always`, `success`, `failure` |

### Auto-indent

After a colon-terminated line and Return, the editor inserts two spaces of indent. Tab again to indent further; Shift-Tab to outdent.

### Syntax highlighting colors

| Token | Color |
|-------|-------|
| YAML keys | Blue |
| Strings | Green |
| Booleans (`true`, `false`) | Orange |
| Numbers | Purple |
| Comments | Gray |
| Template expressions (`{{...}}`) | Cyan |
| `op://` references | Pink |

(Colors above are the default; subject to system Light/Dark mode adjustments.)

---

## History view

### Per-run row

| Element | Source |
|---------|--------|
| Status icon (✓/✗) | `success` field of history JSON |
| Runbook name | `runbook_name` |
| Date | `started_at` (relative format: "2 minutes ago", "yesterday", etc.) |
| Step count | `step_count` |
| Duration | `duration` |

### Per-step expansion

| Element | Notes |
|---------|-------|
| Status icon | success / failed / skipped |
| Step name + duration | From `steps[]` array |
| Error text | Shown if `error` field is non-empty |
| Chevron (right side) | Click to expand and load the log slice for this step |
| Log slice | Loaded lazily via `StepLogExtractor`; up to 240pt scrollable |
| View Full Log | Bottom of expanded run; opens Log Viewer sheet |

---

## Log Viewer sheet

| Element | Action |
|---------|--------|
| Run picker (top) | Select a run section (only for append-mode logs with multiple runs) |
| Text view | Read-only; selectable; supports system Cmd-F |
| Line count | Read-only |
| Copy | Copy entire content to clipboard |

---

## Schedules view

### Per-schedule row (collapsed)

| Element | Source |
|---------|--------|
| Status dot | gray = no history; green = last run succeeded; red = last run failed |
| Runbook name | First positional arg of the crontab line |
| Last-run badge | "✓ 5h ago" / "✗ 2d ago" / "Never run" |
| Cron expression | First five fields of the crontab line |
| Description | `CronDescription.describe(<expr>)` — English |
| Next run | `CronNextRun.next(<expr>)` formatted as friendly date + countdown |
| Edit / Delete buttons | Right side |
| Chevron | Expand to show step flow chart |

### Per-schedule row (expanded)

The step flow chart renders below the row. Each step pill:

| Color | Step type |
|-------|-----------|
| Blue | shell |
| Orange | ssh |
| Green | http |
| Gray | confirm-only |

| Interaction | Action |
|------------|--------|
| Hover | Tooltip with step name |
| Click | Flyout with step config |
| Right-click | Flyout with last-run log slice |
| Double-click | Navigate to runbook detail view, expand that step |

---

## Repositories view

### Per-repo row

| Element | Source |
|---------|--------|
| Repo name | Directory name under `~/.runbook/books/` |
| Runbook count | Discovered count inside the repo |
| Update button | `runbook pull <url>` (re-pull, fast-forward) |
| Remove button | `runbook pull remove <name>` (deletes the directory) |

The "Pull New Repository" button at the top opens a sheet with a single URL input.

---

## Settings

### Sections

| Section | Contents |
|---------|----------|
| Runbook CLI | Installed version, install/update buttons, Check for Updates, error display |
| Runbook Directory | Current path (TextField), Browse, Reset to default (`~/.runbook/books`) |
| Credentials | Pre-warm button (calls `goback auth`), output/error display |
| Editor | Font size slider (9–24pt) |

---

## File locations

| Path | Purpose | Format |
|------|---------|--------|
| `~/.runbook/books/` | Runbook discovery root | Directory of YAML files (and one-level subdirs) |
| `~/.runbook/books/*.yaml` | Local runbooks | YAML |
| `~/.runbook/books/<repo>/` | Pulled repos | Git checkout |
| `~/.runbook/books/**/templates/` | Template runbooks | Excluded from normal listing |
| `~/.runbook/history/` | Run records (CLI-written) | JSON files, one per run |
| `~/.runbook/history/*.json` | Single run record | JSON |
| `~/.runbook/history/<name>.log` | Cron-launched run output | Plain text, append-only |
| `~/.runbook/logs/` | App-launched run output (and YAML-`log:`-driven) | Plain text |
| `~/.runbook/logs/index.json` | Map of (name, timestamp) → log path | JSON |
| `~/.runbook/logs/archive/` | Convention for rotated logs | `.log` and `.gz` |
| `~/.runbook/pinned.json` | Pinned runbook names | JSON array of strings |
| `~/.runbook/backups/` | Pre-write/pre-delete YAML backups | Timestamped `.yaml.bak` files |
| `~/.runbook/highlights.yaml` | Output color rules | YAML |

The runbook directory (`~/.runbook/books/`) is configurable via Settings → Runbook Directory.

---

## `~/.runbook/highlights.yaml` schema

```yaml
rules:
  - pattern: '<regex>'              # Go-style regex (RE2)
    color: <name-or-hex>            # red, green, blue, orange, yellow, purple, cyan, gray, white, pink, teal, or #RRGGBB
    bold: <bool>                    # optional, default false
```

First-match-wins per line. If the file is missing or malformed, falls back to built-in defaults:

```yaml
rules:
  - pattern: '(?i)error|failed|fatal'
    color: red
    bold: true
  - pattern: '(?i)warn'
    color: orange
  - pattern: '(?i)success|done|ok|200'
    color: green
  - pattern: '✓|✗|⊘'
    color: gray
```

The same file is consumed by `runbook` from the terminal in TUI mode, so edits apply to both surfaces.

---

## `~/.runbook/pinned.json` schema

```json
["deploy-app", "nightly-backup", "weekly-summary"]
```

A flat JSON array of runbook names (strings, matching the YAML `name:` field). Edit manually if you want to bulk-pin or import a known set.

---

## Help topics (⌘?)

The Help system has 14 topics, accessible from the Help menu (⌘?) or the contextual `?` buttons throughout the app:

1. Getting Started
2. Basic Concepts
3. Running Runbooks
4. Variables
5. Notifications
6. Scheduling
7. Repositories
8. Editor
9. History
10. Keyboard
11. Settings
12. Troubleshooting
13. FAQ

(The exact list is defined in `Sources/RunbookMac/Views/Help/HelpContent.swift`.)

---

## Version compatibility

| Runbook Mac | Minimum CLI version | Notes |
|-------------|--------------------|----|
| All current versions | 1.0.0+ | The app's CLI auto-update flow keeps this in sync; if you're running an old CLI, the update banner prompts you to upgrade. |

When the app detects a CLI mismatch (older than expected), some features may be missing — the app exposes UI for CLI commands like `runbook log reindex` that don't exist in old CLI builds. The auto-update banner is the right path; click Update.

---

## See also

- [Getting Started](01-getting-started.md) — install + first-run walkthrough.
- [Concepts](02-concepts.md) — mental model.
- [Cookbook](03-cookbook.md) — recipes per UI surface.
- [Troubleshooting](05-troubleshooting.md) — symptom-driven fixes.
- [runbook CLI Reference](https://github.com/msjurset/runbook/blob/master/docs/guide/04-reference.md) — YAML schema, subcommands, flags.
