# Runbook Mac

Native macOS app for browsing, executing, and managing operational runbooks. A GUI frontend for the [runbook](https://github.com/msjurset/runbook) CLI tool.

![Runbook detail view](screenshot1.png)

![YAML editor with syntax highlighting](screenshot2.png)

## Features

- **Three-Panel Layout** — Sidebar for navigation, searchable runbook list with metadata, and runbook detail view
- **Runbook Detail** — View variables, steps with type icons, notification config, and recent run history at a glance
- **Expandable Steps** — Click any step to expand its full configuration (command, host, URL, headers, etc.)
- **Inline Editing** — Double-click any value in an expanded step to edit it in place; auto-saves to YAML on focus loss
- **Execute Runbooks** — Run with live streaming output, variable inputs, stop button (⌘.), dry run mode, and success/failure status
- **Runner Output** — Copy all output, search within output with match navigation, save logs, and syntax-highlighted output for Homebrew/Pi-hole/SSH
- **Auto-Logging** — Per-runbook log config with `new` (per-run file) and `append` (cumulative) modes; log viewer with section picker for append-mode files
- **YAML Editor** — Syntax-highlighted editor with color-coded keys, strings, booleans, numbers, comments, template expressions, and `op://` references
- **Auto-Complete** — Press Tab for context-aware YAML completions (top-level keys, step fields, type values, error policies)
- **Auto-Indent** — Smart indentation after colon-terminated lines
- **Templates** — Runbooks in `templates/` directories are shown separately with visual distinction; create new runbooks from templates or duplicate existing ones
- **Pin Runbooks** — Pin frequently-used runbooks to the top of the list; persisted across sessions
- **Keyboard Navigation** — ⌘1-4 for sidebar sections, ⌘K to quick-jump to any runbook by name
- **Diff Preview** — Review changes before saving in the YAML editor
- **Run History** — Browse all past runs with expandable per-step results, timing, errors, and name filtering
- **Cron Scheduling** — Add, view, and remove crontab entries from the GUI with natural language descriptions
- **Repository Management** — Pull git repos or single YAML files, list, update, and remove pulled repos
- **SSH Key Caching** — Cache 1Password SSH keys in system keychain via `runbook auth` to avoid Touch ID prompts on repeat runs
- **Help System** — Menu bar Help (⌘?) with 14 topics + contextual ? button on each view
- **Validation** — Validate YAML structure without running via the CLI
- **Desktop Notifications** — Test notifications from the app

## Requirements

- macOS 15.0 (Sequoia) or later
- [runbook](https://github.com/msjurset/runbook) CLI installed and available in your `PATH`

## Install

### Homebrew

```sh
brew install --cask msjurset/tap/runbook-mac
```

This also installs the `runbook` CLI if you don't already have it.

### From source

```sh
make deploy
```

This builds the app, creates the `.app` bundle with icon, and installs to `/Applications/Runbook.app`.

## Build

```
make build                    # Compile release binary
make bundle                   # Build + create .app bundle
make icon                     # Generate app icon (if missing)
make release VERSION=1.2.0    # Bump version, commit, and tag
```

## Architecture

The Mac app is a **frontend** — it does not reimplement the runbook engine. All execution is delegated to the `runbook` CLI binary via `Process`:

- `runbook run --no-tui --yes <name>` for execution with live output streaming
- `runbook completion-names` for dynamic runbook discovery
- `runbook validate`, `runbook cron`, `runbook pull`, `runbook notify` for management

The shared contract between the app and CLI is:
- YAML runbook files in `~/.runbook/books/`
- Templates in `templates/` subdirectories (discovered but shown separately)
- JSON history records in `~/.runbook/history/`
- Run logs in `~/.runbook/logs/`
- Pinned runbooks in `~/.runbook/pinned.json`
- YAML backups in `~/.runbook/backups/` (created before every save and delete)
- The `runbook` binary in `$PATH` or `~/.local/bin/`

## Project Structure

```
Sources/RunbookMac/
  Models/           Runbook, HistoryRecord, RunbookTemplate (Codable structs)
  Services/         RunbookCLI (Process bridge), RunbookStore (file I/O + YAML), CronDescription
  Views/
    Sidebar/        Navigation sidebar, runbook list with search, browser split view
    Detail/         Runbook detail, runner with output controls, create-from-template
    Editor/         YAML editor with syntax highlighting + completion
    History/        Run history browser
    Settings/       Cron and pull management, step flow visualization
    Help/           Help system with structured content
Tests/
  RunbookMacTests/  Unit tests (models, templates, cron, completions)
  UITests/          XCUITest UI tests (navigation, layout, selection)
```

## License

MIT
