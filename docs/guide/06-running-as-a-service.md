# Running Runbook Mac as a Service

The "service" question for the Mac app comes in two flavors:

1. **Auto-launch the app** at login so the GUI is always available without manually opening it.
2. **Schedule runbooks** to fire on a recurring basis without the app being open at all.

These are independent. You can do either, both, or neither. This page covers both, plus how the auto-update flow works and how the app and cron-launched runs share log files.

For the underlying CLI's scheduling docs (which apply equally whether you schedule from the GUI or the terminal), see the [runbook CLI Running as a Service guide](https://github.com/msjurset/runbook/blob/master/docs/guide/06-running-as-a-service.md).

- [Auto-launch at login](#auto-launch-at-login)
- [Scheduling runbooks (cron)](#scheduling-runbooks-cron)
- [How the GUI and cron-launched runs share state](#how-the-gui-and-cron-launched-runs-share-state)
- [The CLI auto-update flow](#the-cli-auto-update-flow)
- [Log management for long-running setups](#log-management-for-long-running-setups)

---

## Auto-launch at login

To have Runbook Mac open every time you log in:

**System Settings → General → Login Items & Extensions → Open at Login → click `+` → select `Runbook.app`.**

That's it. macOS handles the launch at login. To remove, select Runbook in the same list and click `−`.

There is no "launch at login" toggle in the app's own Settings. The macOS Login Items panel is the only path.

### Whether you should auto-launch

The Mac app is a **viewer and launcher** for runbooks — it has no background work it does on its own. Auto-launching is only useful if:

- You want the app available immediately when you log in (just like Mail or Slack).
- You frequently kick off runbooks from the GUI and want to skip the "Cmd-Space, type Runbook" step.

If your usage is dominated by **scheduled** runs that fire from cron without the GUI, there's no benefit to auto-launching — cron-launched runs work whether the app is open or not.

### Closing the window vs. quitting

macOS apps can be running with no window visible. If you close the Runbook window with Cmd-W, the app stays running in the dock; click the dock icon to reopen the window. Cmd-Q quits the app entirely. Closing the window does **not** cancel any in-flight runs — they continue in the background and the tray re-attaches when you reopen the window.

---

## Scheduling runbooks (cron)

Scheduled runbooks fire **whether the GUI is open or not**. The schedule lives in your user crontab; cron is a system service that runs all the time. The app is just a tool for managing crontab entries.

### Add a schedule from the GUI

1. Sidebar → **Schedules**.
2. Click **Add Schedule** at the top right.
3. Pick a runbook from the dropdown; enter a cron expression.
4. Click **Save**.

The app shells out to `runbook cron add <name> "<schedule>"`. The CLI installs a crontab line tagged with `# runbook: <name>`:

```
0 3 * * 0 /Users/you/.local/bin/runbook run --no-tui --yes nightly-backup >> /Users/you/.runbook/history/nightly-backup.log 2>&1 # runbook: nightly-backup
```

The trailing `# runbook: <name>` comment is what makes `runbook cron list` and `runbook cron remove` distinguish runbook-managed entries from your other (manually-installed) crontab lines.

### Add a schedule from the terminal

Equivalent — same tag, same crontab line:

```sh
runbook cron add nightly-backup "0 3 * * 0"
```

Both paths reach the same end state. `runbook cron list` from a terminal shows the same entries as the GUI's Schedules view.

### What runs at the scheduled time

When cron fires, it executes the line above. The CLI runs the runbook with:

- `--no-tui` — no terminal UI; plain streaming output
- `--yes` — auto-accepts any `confirm:` prompts
- `>> ~/.runbook/history/<name>.log 2>&1` — appends stdout+stderr to a log file

The GUI is not involved. The runbook's history record lands in `~/.runbook/history/`, the captured stdout is in the log file, and the next time you open the GUI's History view, the new run appears.

### Variables in scheduled runs

Cron's environment is minimal. The crontab line doesn't carry `--var` flags, so a scheduled runbook only sees:

- **YAML defaults** — the most reliable source for unattended runs.
- **`RUNBOOK_VAR_<NAME>` environment variables** — only if you've set them in your shell environment AND cron's environment inherits them (it usually doesn't).
- **No `--var` overrides** (you'd have to manually edit the crontab line to add them).
- **No interactive prompts** (cron has no TTY — required-but-no-default variables would just fail).
- **`op://` references** — resolved through the keychain cache. Pre-warm with `runbook auth <name>` (or via Settings → Credentials) before the first scheduled run, otherwise the run hits 1Password Touch ID and fails (no human to approve).

For a runbook to be cron-friendly, every variable must have a default OR be sourced from `op://` (with cache pre-warmed).

### Multiple schedules per runbook

Add `runbook cron add` more than once with different schedules. Both lines coexist; the GUI's Schedules view shows them as separate rows. Remove via the GUI's row Delete button or via `runbook cron remove <name> "<specific schedule>"` from the terminal.

### Removing a schedule

- **From the GUI:** Schedules view → row Delete button (trash icon).
- **From the terminal:** `runbook cron remove <name>` (removes all schedules for that runbook) or `runbook cron remove <name> "<schedule>"` (removes one specific schedule).

The GUI calls the same CLI command under the hood.

### What the GUI does NOT manage

- **Existing crontab entries that you installed manually** (without the `# runbook:` tag). The GUI ignores them entirely. They're safe — `runbook cron remove` won't delete untagged lines.
- **launchd-installed schedules.** The Mac app doesn't do anything with `launchctl` / `~/Library/LaunchAgents/` plists. If you prefer launchd over cron, manage those with a launchd-aware tool; the Schedules view stays empty.

---

## How the GUI and cron-launched runs share state

The same set of files on disk:

| File | Written by GUI runs | Written by cron runs |
|------|--------------------|--------------------|
| `~/.runbook/history/*.json` | ✓ | ✓ |
| `~/.runbook/logs/<name>-<timestamp>.log` | ✓ (every run) | ✓ if `log: enabled` in YAML |
| `~/.runbook/history/<name>.log` | ✗ | ✓ (always — via crontab redirect) |
| `~/.runbook/logs/index.json` | ✓ | ✓ if `log: enabled` |

Cron-launched runs **always** produce a log file: the crontab line redirects stdout to `~/.runbook/history/<name>.log`. This is independent of whether the YAML has `log: enabled`.

GUI-launched runs always produce a log file too, but in `~/.runbook/logs/<name>-<timestamp>.log` — written by `RunSessionStore.persistLog` at the end of the session.

If the YAML has `log: enabled: true`, the CLI writes its own file too, in addition to whichever of the above. Multiple files for the same run is harmless; the LogIndex points at one of them and the History view's per-step extraction uses a fallback search if the index miss.

### Why two log directories?

Historical reasons:

- `~/.runbook/history/` was originally just for JSON records. Then `runbook cron add` added stdout redirection there too because it was already a per-runbook dir.
- `~/.runbook/logs/` was added when the YAML `log:` config was introduced — a place for "user-configured" log files.
- Then the Mac app added per-run persistence to `~/.runbook/logs/`.

The result: cron's logs are in `history/`, everything else is in `logs/`. Documenting it is easier than fixing it without breaking existing setups.

### Reading logs across both sources

The `StepLogExtractor.findLogURL` resolution chain checks both directories:

1. **Index hit** — `LogIndex.logPath(for: record)` (most reliable).
2. **`~/.runbook/logs/<name>.log`** — if mtime ≥ record's start time − 60s.
3. **`~/.runbook/history/<name>.log`** — same mtime gate.
4. **Newest matching `.log` or `.gz`** in `~/.runbook/logs/` or `~/.runbook/logs/archive/`.

The mtime gate is the safety net — a stale append-mode log from a previous run can't leak content into a newer history record because its mtime is too old.

---

## The CLI auto-update flow

The CLI is updated independently from the app. The app checks for new CLI versions on launch and shows a banner when one is available.

### The check itself

On `RunbookMacApp.onAppear`:

1. `CLIInstaller.checkInstalledVersion()` reads the local `runbook --version`.
2. If the last check was less than 24 hours ago (per `UserDefaults` key `lastCLIUpdateCheck`), skip the network check.
3. Otherwise, hit `https://api.github.com/repos/msjurset/runbook/releases/latest` and compare versions.
4. If `latestVersion > installedVersion`, set `isUpdateAvailable = true`.

### The banner

When `isUpdateAvailable` is true, a thin banner docks at the top of the window:

```
┃ Runbook CLI v1.3.0 available     [Update] [×] ┃
```

- **Update** — runs `CLIInstaller.install()` async: downloads the tarball from GitHub Releases, extracts to a temp dir, copies the binary, man page, and zsh completions into place. Re-checks version on completion.
- **×** — dismisses the banner for this session. It will reappear on the next app launch if the update is still pending.

### Manual update

Settings → Runbook CLI → **Check for Updates**. Forces an immediate check (bypasses the 24h throttle) and offers Install if a new version is found.

### Update failed

If the install fails (network issue, permission error, architecture mismatch), the error appears in the banner. Common causes:

- **Network unreachable.** Retry from a network with GitHub access.
- **Permission denied** writing to the install directory. The default is `~/.local/bin/`; ensure your user owns it.
- **Wrong architecture.** The installer auto-detects arm64 vs amd64 from the running app; if you've moved a binary between machines this could mismatch. Reinstall via `brew install msjurset/tap/runbook` or download the right tarball manually.

### What gets updated

Just the CLI:

- `<install-dir>/runbook` — the binary
- `<install-dir>/share/man/man1/runbook.1` — the man page (if writable)
- One of the standard zsh completion dirs (`~/.oh-my-zsh/...`, `/usr/local/share/...`, `/opt/homebrew/share/...`) — first writable wins

The Mac app itself updates separately via Sparkle (or whatever auto-update path the cask-distributed bundle uses). The CLI auto-update is a separate flow.

---

## Log management for long-running setups

If you have schedules firing many times a day for months, log files grow. The app does **not** rotate logs automatically. Three approaches:

### 1. External rotation

`logrotate` (Linux) or `newsyslog` (macOS) can rotate `~/.runbook/logs/*.log` and `~/.runbook/history/*.log` on size or time triggers. After rotation moves files to `~/.runbook/logs/archive/`, run `runbook log reindex` to update the LogIndex so the History view's per-step extractor can still find them.

Example macOS `newsyslog` config (`/etc/newsyslog.d/runbook.conf`):

```
# logfilename                                              [owner:group] mode count size when flags
/Users/you/.runbook/logs/*.log                              :          644  10    1024 *    JZ
/Users/you/.runbook/history/*.log                           :          644  10    1024 *    JZ
```

(Rotates when a file hits 1 MB; keeps 10 archived versions; gzips.)

After newsyslog runs, run `runbook log reindex` either manually or as a separate runbook.

### 2. Use the runbook itself to rotate logs

Schedule a runbook that compresses and archives weekly. See [CLI Running as a Service → Log rotation](https://github.com/msjurset/runbook/blob/master/docs/guide/06-running-as-a-service.md#rotation) for the full pattern.

### 3. Use append-mode YAML config and ignore the duplication

`log: mode: append` keeps a single growing file. Pair with external rotation. The duplicate file from `RunSessionStore.persistLog` (in `logs/`) is per-run and stays small — you mostly just need to rotate the append-mode `<name>.log` file.

---

## Where to go next

- [Reference](04-reference.md) — keyboard shortcuts, file locations, settings.
- [Troubleshooting](05-troubleshooting.md) — schedule issues, log content mismatches, CLI updates.
- [CLI Running as a Service](https://github.com/msjurset/runbook/blob/master/docs/guide/06-running-as-a-service.md) — deeper dive into the cron model and Windows Task Scheduler equivalent.
