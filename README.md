# Runbook Mac

Native macOS app for browsing, executing, and managing operational runbooks. A GUI frontend for the [runbook](https://github.com/msjurset/runbook) CLI tool.

![Runbook detail view](screenshot1.png)

![YAML editor with syntax highlighting](screenshot2.png)

## Features

- **Browse Runbooks** — Sidebar navigation of all runbooks in `~/.runbook/books/` with automatic discovery of subdirectories (pulled repos)
- **Runbook Detail** — View variables, steps with type icons, notification config, and recent run history at a glance
- **Expandable Steps** — Click any step to expand its full configuration (command, host, URL, headers, etc.)
- **Inline Editing** — Double-click any value in an expanded step to edit it in place; auto-saves to YAML on focus loss
- **Execute Runbooks** — Run with live streaming output, variable inputs, and success/failure status
- **YAML Editor** — Syntax-highlighted editor with color-coded keys, strings, booleans, numbers, comments, template expressions, and `op://` references
- **Auto-Complete** — Press Tab for context-aware YAML completions (top-level keys, step fields, type values, error policies)
- **Auto-Indent** — Smart indentation after colon-terminated lines
- **Template Selector** — Create new runbooks from templates: Blank, SSH Deploy, Health Check, Server Maintenance
- **Run History** — Browse all past runs with expandable per-step results, timing, errors, and name filtering
- **Cron Scheduling** — Add, view, and remove crontab entries from the GUI
- **Repository Management** — Pull git repos or single YAML files, list and remove pulled repos
- **Help System** — Menu bar Help (⌘?) with 13 topics + contextual ? button on each view
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
make build       # Compile release binary
make bundle      # Build + create .app bundle
make icon        # Generate app icon (if missing)
```

## Architecture

The Mac app is a **frontend** — it does not reimplement the runbook engine. All execution is delegated to the `runbook` CLI binary via `Process`:

- `runbook run --no-tui --yes <name>` for execution with live output streaming
- `runbook completion-names` for dynamic runbook discovery
- `runbook validate`, `runbook cron`, `runbook pull`, `runbook notify` for management

The shared contract between the app and CLI is:
- YAML runbook files in `~/.runbook/books/`
- JSON history records in `~/.runbook/history/`
- The `runbook` binary in `$PATH` or `~/.local/bin/`

## Project Structure

```
Sources/RunbookMac/
  Models/           Runbook, HistoryRecord, RunbookTemplate (Codable structs)
  Services/         RunbookCLI (Process bridge), RunbookStore (file I/O + YAML)
  Views/
    Sidebar/        Navigation sidebar
    Detail/         Runbook detail, runner, editable config rows
    Editor/         YAML editor with syntax highlighting + completion
    History/        Run history browser
    Settings/       Cron and pull management
    Help/           Help system with structured content
```

## License

MIT
