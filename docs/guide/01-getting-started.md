# Getting Started

A ten-minute tour. By the end you'll have Runbook Mac installed, the CLI auto-installed (if you didn't already have it), one runbook visible in the list, and you'll have run it from the GUI and watched the output stream into the console tray.

If anything feels magical, skip ahead to [Concepts](02-concepts.md) afterwards — it explains the three-panel layout, the tray, and how the app bridges to the CLI.

## 1. Install

### Homebrew (recommended)

```sh
brew install --cask msjurset/tap/runbook-mac
```

This drops `Runbook.app` into `/Applications/`. The cask also depends on the `runbook` CLI, so Homebrew installs that too if it's missing.

### From source

If you have the repo checked out:

```sh
make deploy
```

Builds the universal binary, packages the `.app` bundle, and copies it into `/Applications/Runbook.app`.

## 2. First launch

Open `Runbook.app` (Cmd-Space, type "Runbook", Return — or double-click in Finder).

### CLI auto-install

If you installed via Homebrew cask, the `runbook` CLI is already on `PATH`. Skip to step 3.

If you installed from source (or installed the app some other way), the app checks for the CLI at first launch. If it's missing, the **CLI Setup sheet** opens automatically:

- **Step 1 — Install CLI** — pick an install directory (default `~/.local/bin`), click Install. The app downloads the latest CLI release from GitHub, extracts it, and copies the binary, man page, and zsh completions into place. If the install directory isn't on your `PATH`, the sheet warns you.
- **Step 2 — Pull shared runbooks** — gated until step 1 completes. Optional: pulls `github.com/msjurset/runbooks` (a starter collection) into your books directory so the runbook list isn't empty on first launch. Skip if you'd rather start blank.

Click **Done** when the CLI is installed.

> **Already have the CLI?** The setup sheet detects it and skips Step 1. You'll only see Step 2 (the optional starter pull).

> **Manual install fallback:** if auto-install fails (network issue, wrong architecture detection), the sheet shows the manual command: `brew install msjurset/tap/runbook`. Run that, then click Done.

### CLI auto-update

After the first launch, Runbook Mac checks for new CLI releases once per 24 hours in the background. If a newer version is available, a thin **CLI Update Banner** appears at the top of the window: `Runbook CLI vX.Y.Z available · [Update] [×]`. Click Update to install in place; click × to dismiss for this session.

## 3. The three-panel layout

After setup completes, you land in the main window:

```
┌──────────────┬───────────────────────┬─────────────────────────────────────┐
│              │                       │                                     │
│   Sidebar    │    Runbook List       │    Runbook Detail                   │
│              │                       │                                     │
│  Runbooks    │  ┌─────────────────┐  │   Name: deploy-app                  │
│              │  │ deploy-app      │  │   Description: ...                  │
│  Management  │  │ 5 steps · 3 vars│  │                                     │
│   History    │  └─────────────────┘  │   Variables (3)                     │
│   Schedules  │                       │     version, host, api_token        │
│   Repos      │  ┌─────────────────┐  │                                     │
│              │  │ nightly-backup  │  │   Steps (5)                         │
│              │  │ 3 steps         │  │     1. [http] Pre-flight health     │
│              │  └─────────────────┘  │     2. [confirm] Confirm deploy     │
│              │                       │     ...                             │
│              │  Templates ▸          │                                     │
│              │                       │   Recent runs                       │
│              │                       │     ✓ 3 hours ago · 12.4s           │
│   + ↻ ⚙      │                       │                                     │
└──────────────┴───────────────────────┴─────────────────────────────────────┘
```

**Sidebar (left)** — top-level navigation. The four sections:

- **Runbooks** — browse and run your runbooks. This is the main workspace.
- **History** — see every prior run with per-step log slices.
- **Schedules** — manage `runbook cron` entries (add, edit, remove, see step flow charts).
- **Repositories** — manage pulled collections (`runbook pull`).

The toolbar at the bottom of the sidebar has three icon buttons: `+` (new runbook), `↻` (refresh from disk), `⚙` (Settings).

**Runbook List (center)** — search-filtered list of every runbook discovered in `~/.runbook/books/`. Templates appear in a separate collapsible section at the bottom. Pinned runbooks float to the top with a pin icon. Right-click any row for: Run, Dry Run, Schedule, Pin/Unpin, Duplicate, Delete.

**Runbook Detail (right)** — the selected runbook, broken into sections: header (name, description, summary counts), Variables, Steps, Notifications config, Recent Runs. The toolbar at the top has a `?` (help), pencil (edit YAML), Schedule, and Run button.

## 4. Run a runbook

Click any runbook in the list. In the detail panel's toolbar, click **Run**.

If the runbook has variables, the **Run Confirm Sheet** opens:

```
┌────────────────────────────────────────────┐
│  Run: deploy-app                           │
│  Deploy the application                    │
│                                            │
│  Variables                                 │
│   version  ┃ 1.2.3                ┃        │
│   host     ┃ prod-web-01          ┃        │
│   api_token ┃ (op:// hidden)      ┃        │
│                                            │
│  ☐ Dry Run                                 │
│                                            │
│            [ Cancel ]  [ Run ]             │
└────────────────────────────────────────────┘
```

Each declared variable gets a row, pre-filled with its YAML default (op:// secrets are not pre-filled — they resolve at runtime via 1Password). Toggle **Dry Run** to validate without executing. Click **Run**.

If the runbook has **no variables**, clicking Run skips the sheet and starts immediately.

## 5. The console tray

A panel slides up from the bottom of the window the moment a run starts:

```
┌────────────────────────────────────────────────────────────────┐
│  ▶ deploy-app                                          12s ▾   │
├────────────────────────────────────────────────────────────────┤
│  Running: deploy-app — Deploy the application (5 steps)        │
│  ▸ Step 1: Pre-flight health                                   │
│    │ HTTP 200 OK                                               │
│    │ {"status":"healthy","version":"1.2.2"}                    │
│    ✓ done                                                      │
│  ▸ Step 2: Confirm deploy                                      │
│    ...                                                         │
│                                                                │
│  [ Find ] 47 lines [ Copy ] [ Stop ⌘. ]      [ Save ]          │
└────────────────────────────────────────────────────────────────┘
```

**Tabs at the top** — one per active session. Multiple runs can be active simultaneously; each gets its own tab. Click a tab to switch which one's output is showing. Each tab has a status icon (▶ running / ✓ succeeded / ✗ failed / ⊘ cancelled), the runbook name, an elapsed timer, and an `×` to stop and dismiss.

**Output area** — streams the CLI's stdout line by line as it arrives. Each line is colorized by `~/.runbook/highlights.yaml` rules (errors red, warnings yellow, success green by default; customizable — see the [Cookbook](03-cookbook.md#customize-output-highlighting)).

**Output toolbar** — Find (⌘F to search the output with match navigation), line count, Copy All (to clipboard), Stop (⌘. to cancel a running session), Retry + Dry checkbox (after a session terminates), Save (write the output to a `.log` file via the standard save panel).

**Collapse** — click the chevron at the top right to collapse the tray to a one-line status bar. Click again to expand.

> **Concurrent runs are first-class.** Launching a run never blocks the rest of the app: keep editing, navigate sections, kick off another run. The tray's tab strip flexes to share the bar.

## 6. Inspect history

Click **History** in the sidebar. You'll see a list of every prior run, newest first:

```
┌──────────────────────────────────────────────────────────────────┐
│  Search: [                                            ]          │
├──────────────────────────────────────────────────────────────────┤
│  ▾ ✓ deploy-app          2 minutes ago    5 steps    12.4s      │
│      ✓ Pre-flight health         200ms                           │
│      ✓ Confirm deploy            1.2s                            │
│      ▾ ✓ Deploy                  8.3s                            │
│        │ Restarting nginx...                                     │
│        │ Done.                                                   │
│        ✓ done                                                    │
│      ✓ Wait for service          1.8s                            │
│      ✓ Post-flight health        900ms                           │
│      [ View Full Log ]                                           │
│  ▸ ✓ deploy-app          1 hour ago       5 steps    11.8s     │
│  ▸ ✗ nightly-backup      yesterday        3 steps    2m 14s    │
└──────────────────────────────────────────────────────────────────┘
```

Click a row's chevron to expand. Each step inside has its **own** chevron — click that to load and display the actual log slice for **that specific step in that specific run** (not the latest), with the same color highlighting as the live console.

The "View Full Log" button at the bottom of an expanded run opens the full log file in a separate viewer with run-section navigation (for append-mode logs that contain multiple runs).

## 7. Where to next

You've now seen the three core surfaces — Runbooks, the run flow, and History. Three more sections to know about:

- **Schedules** (sidebar → Schedules) — add/edit/remove cron entries via a GUI. Each schedule shows a status dot, last-run badge, next-run countdown, and a clickable step flow chart. See [Cookbook → Schedule via the cron UI](03-cookbook.md#schedule-a-runbook-via-the-cron-ui).
- **Repositories** (sidebar → Repositories) — pull shared runbook collections, list pulled repos, refresh, remove. See [Cookbook → Pull a shared collection](03-cookbook.md#pull-a-shared-collection).
- **Editor** (pencil button on Runbook Detail) — full YAML editor with syntax highlighting, tab completion, validation, and diff preview before save. See [Cookbook → Edit YAML with diff preview](03-cookbook.md#edit-yaml-with-diff-preview).

For a deeper mental model:

- [Concepts](02-concepts.md) — how the app and the CLI compose, what state lives where.
- [Cookbook](03-cookbook.md) — recipes per UI surface.
- [Reference](04-reference.md) — keyboard shortcuts, file locations, settings.

For when something doesn't work:

- [Troubleshooting](05-troubleshooting.md) — CLI not found, runs missing from history, log content from a different run, etc.
