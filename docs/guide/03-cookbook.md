# Cookbook

Recipes for every major UI surface in Runbook Mac. Each entry follows a consistent shape:

- **When to reach for this** — the situation it solves
- **How to do it** — step-by-step, with the relevant panel and controls
- **Variations** — adaptations for related cases
- **Gotchas** — failure modes specific to this workflow
- **Notes** — keyboard shortcuts, performance considerations, undo behavior

These recipes assume you've read [Getting Started](01-getting-started.md) and are familiar with the three-panel layout.

---

## Looking for runbook recipes? Start with the CLI cookbook

The recipes on **this** page are about **using the Mac app** — clicking the right button, expanding the right row, finding the right panel. They don't tell you what to put inside your runbooks.

For that — **what to write in a YAML, what step types to use, how to combine them into real workflows like a deploy or a scheduled backup** — the [**runbook CLI Cookbook**](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md) is the foundational source. The YAML you'd write is identical whether you author it in the Mac app's editor or in `vim`, so every CLI cookbook recipe applies equally.

A curated map into the CLI cookbook by topic:

| What you want to do | CLI cookbook recipe |
|---------------------|---------------------|
| **Step types** | |
| Run a shell command and capture its output for later steps | [Capture output and feed it forward](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#capture-output-and-feed-it-forward) |
| Probe an HTTP endpoint | [HTTP GET healthcheck](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#http-get-healthcheck) |
| Trigger a webhook with a JSON body | [POST JSON payload](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#post-json-payload) |
| SSH to a remote host using your agent | [SSH with agent auth](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#ssh-with-agent-auth) |
| SSH using a 1Password-stored key (cron-friendly) | [SSH with 1Password-stored key](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#ssh-with-1password-stored-key) |
| **Variables and secrets** | |
| Prompt the user for a required value | [Prompt for a required variable](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#prompt-for-a-required-variable) |
| Reference a 1Password secret cleanly | [1Password secret as a variable](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#1password-secret-as-a-variable) |
| **Flow control** | |
| Pause and ask before a destructive step | [Confirm before destructive step](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#confirm-before-destructive-step) |
| Probe several services concurrently | [Parallel health probes](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#parallel-health-probes) |
| Retry a flaky step with a backoff | [Retry with exponential backoff](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#retry-with-exponential-backoff) |
| Skip a step unless an environment matches | [Conditional step](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#conditional-step) |
| **Scheduled runs** | |
| Hourly automated health check | [Hourly health check via cron](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#hourly-health-check-via-cron) |
| Nightly backup with notification | [Nightly backup](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#nightly-backup) |
| **Notifications** | |
| Slack only when something fails | [Slack on failure only](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#slack-on-failure-only) |
| Email digest with per-step status | [Email digest with per-step status](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#email-digest-with-per-step-status) |
| **Sharing** | |
| Pull a shared runbook collection | [Pull a shared runbook collection](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#pull-a-shared-runbook-collection) |
| Publish your own collection for a team | [Publish your own runbook collection](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#publish-your-own-runbook-collection) |
| Author a template that ships with the collection | [Author a template for a shared collection](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#author-a-template-for-a-shared-collection) |
| **End-to-end runbooks** | |
| Production deploy with pre/post-flight and rollback gate | [Deploy with rollback gate](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#deploy-with-rollback-gate) |
| Multi-region health probe with email summary | [Multi-region health probe](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#multi-region-health-probe) |

When you've found a recipe you want to try, the Mac app workflows below tell you how to bring it to life: [Create a runbook](#create-a-runbook), [Edit YAML with diff preview](#edit-yaml-with-diff-preview), [Run a runbook](#run-a-runbook), and so on.

---

## Table of contents

- **Running** — [run a runbook](#run-a-runbook), [run with custom variables](#run-with-custom-variables), [dry run from the run sheet](#dry-run-from-the-run-sheet), [retry with the dry checkbox](#retry-with-the-dry-checkbox), [stop a running session](#stop-a-running-session), [run multiple concurrently](#run-multiple-concurrently)
- **Authoring** — [create a runbook](#create-a-runbook), [scaffold from a template](#scaffold-from-a-template), [edit a step inline](#edit-a-step-inline), [edit YAML with diff preview](#edit-yaml-with-diff-preview), [validate before saving](#validate-before-saving)
- **Observation** — [browse history](#browse-history), [see a step's actual log slice](#see-a-steps-actual-log-slice), [view a full log file](#view-a-full-log-file), [search within console output](#search-within-console-output), [save run output](#save-run-output)
- **Scheduling** — [schedule via the cron UI](#schedule-a-runbook-via-the-cron-ui), [edit a schedule](#edit-a-schedule), [inspect via the step flow chart](#inspect-via-the-step-flow-chart), [navigate from chart to runbook step](#navigate-from-chart-to-runbook-step)
- **Sharing** — [pull a shared collection](#pull-a-shared-collection), [refresh a pulled collection](#refresh-a-pulled-collection), [remove a pulled collection](#remove-a-pulled-collection)
- **Customization** — [pin a runbook](#pin-a-runbook), [customize output highlighting](#customize-output-highlighting), [change the editor font size](#change-the-editor-font-size), [change the runbook directory](#change-the-runbook-directory), [pre-warm 1Password secrets](#pre-warm-1password-secrets)
- **Navigation** — [Quick Jump to a runbook](#quick-jump-to-a-runbook), [keyboard shortcuts](#keyboard-shortcuts)

---

## Running

### Run a runbook

**When to reach for this:** the most common action in the app. You've selected a runbook in the list and you want to execute it.

**How:**

1. Click a runbook in the list (or use Quick Jump — `⌘K`).
2. Click **Run** in the detail toolbar (top right).
3. If the runbook has variables, the **Run Confirm Sheet** opens with each variable pre-filled from its YAML default. Tweak as needed and click Run.
4. The console tray slides up with the run streaming line by line.

**Variations:**

- **No variables:** clicking Run skips the sheet and starts immediately.
- **From the list (right-click):** Run, Dry Run, and Schedule are available from the context menu without opening the detail view.

**Gotchas:**

- Variables whose default starts with `op://` are **not** pre-filled in the sheet — they're treated as secrets and resolve at runtime via the 1Password CLI on first run, then are cached in the system keychain. The sheet's variable input for an `op://` default shows the path (read-only); the actual secret never enters the GUI's memory.
- The run sheet has no field validation. If you supply something invalid (a malformed URL, a non-existent host), the failure surfaces when the step actually runs, in the tray.

**Notes:** every run is captured to a per-run log file at `~/.runbook/logs/<name>-<timestamp>.log` regardless of whether the YAML has `log: enabled`. This is what makes the History view's per-step log slices work even for ad-hoc GUI runs.

---

### Run with custom variables

**When to reach for this:** the YAML defaults aren't what you want for this particular run.

**How:**

1. Open the Run Confirm Sheet (Run button on the detail view).
2. Each declared variable has a row with a text field. Type the value you want.
3. Click Run.

**Variations:**

- **From the right-click menu:** the same sheet opens.
- **For unattended runs:** you can't supply variables when Run is invoked from a menu shortcut (no sheet is opened). For unattended-with-vars, schedule via cron or use the terminal.

**Notes:** the variable values you type for one run are not remembered for the next run. Each Run sheet starts fresh from the YAML defaults. If you constantly find yourself typing the same override, it's probably time to update the YAML default.

---

### Dry run from the Run sheet

**When to reach for this:** you want to see what would happen — variable resolution, step plan — without any side effects.

**How:**

1. Open the Run Confirm Sheet.
2. Toggle the **Dry Run** checkbox at the bottom.
3. Click **Dry Run** (the button text changes when the toggle is on).

**What happens:** the CLI runs with `--dry-run`. Output is the resolved variable map plus the step plan; nothing is actually executed. Same console tray, same history record (with `dry: true` annotation in the tab badge).

**Notes:** dry-running a runbook with `confirm:` steps doesn't prompt — `--yes` is passed to the CLI in either real or dry mode. The dry run flows past the confirm without asking.

---

### Retry with the dry checkbox

**When to reach for this:** a run just failed (or succeeded but you want to verify), and you want to re-run with a different real/dry mode without leaving the tray.

**How:**

1. The session is now terminal (✓ / ✗ / ⊘ icon in the tab).
2. In the output toolbar (bottom of the tray), look for **Retry** and the **Dry** checkbox right next to it.
3. Toggle Dry on or off as desired.
4. Click **Retry**.

**What happens:** the same tab clears its output, resets the elapsed timer, and re-runs the runbook with the new dry/real choice. Same session ID — no new tab is created.

**Variations:**

- **With different variables:** Retry doesn't open the Run sheet. To change variables on retry, you'd have to dismiss the session, open the Run sheet again, and start fresh. This is a deliberate trade-off — Retry is for the iteration pattern "re-run identically with one toggle flipped," not "re-run with substantial parameter changes."

**Gotchas:**

- Retry only appears on **terminal** sessions. While a session is running, the toolbar shows Stop instead.

**Notes:** the retry path captures a fresh log file (different timestamp); both end up in `~/.runbook/logs/`. History records both as separate runs.

---

### Stop a running session

**When to reach for this:** the run is taking too long, or you realized you ran the wrong thing.

**How:**

- Click the **Stop** button in the output toolbar, or
- Press **⌘.** (Cmd-period) while the tray has focus, or
- Click the **×** on the session's tab.

**What happens:** the underlying `Task` is cancelled, which propagates a `CancellationError` to the CLI subprocess. The CLI's `signal.NotifyContext` catches the `os.Interrupt` and aborts the in-flight step. Subsequent steps are marked `skipped`. The session moves to a `cancelled` terminal state and the captured output (up to the cancel point) is persisted to a log file.

**Variations:**

- **Tab × is "stop and dismiss":** clicking × on a still-running tab atomically cancels the run *and* removes the tab from the strip. There's a brief 150ms delay so the cancel animation can play.
- **⌘. only affects the currently-shown session.** If you have three concurrent runs and only want to cancel one, click that one's tab first.

**Notes:** cancellation is graceful — the CLI flushes any in-flight stdout before exiting. You'll see partial output up to the cancel boundary, then a final `— Cancelled —` marker line.

---

### Run multiple concurrently

**When to reach for this:** independent runbooks where you don't want to wait for one to finish before starting the next.

**How:**

1. Start the first run (Run button).
2. Without dismissing the tray, navigate to another runbook in the list.
3. Click Run on it. A second tab appears in the tray's tab strip.
4. Click any tab to switch which one's output is showing.

**What happens:** each session has its own `Task`, its own subprocess, its own captured output. They're fully independent. The tray's tab strip flexes to share the bar — three tabs each take ~33% width; six tabs each take ~16%.

**Variations:**

- **Up to 5 terminal sessions retained.** Active (running) sessions never count against the limit. The 6th terminal session pushes out the oldest terminal one.
- **Stop one without affecting others:** click that tab's × or use `⌘.` while it's the focused tab.

**Gotchas:**

- All concurrent runs share the same CLI binary and the same keychain. If two runs both depend on a fresh 1Password Touch ID prompt, the second one queues on the first.
- Logs are still per-run (each session writes its own file at termination). No interleaving.

**Notes:** runs from cron also count — if a cron-launched run is in flight when you click Run on something else, both run concurrently in their respective subprocess pipes. Cron runs don't show up in the tray (no foreground UI), but their history records appear in the History view.

---

## Authoring

### Create a runbook

**When to reach for this:** starting fresh — no template fits, or you want a known-clean starting point.

**How:**

1. Click `+` in the sidebar's bottom toolbar.
2. The **New Runbook** sheet opens with a template picker on the left (Blank + every template discovered) and a code editor on the right.
3. Choose **Blank** in the picker. The editor pre-fills with a one-step shell scaffold.
4. Type a name in the Name field at the top.
5. Edit the YAML to taste.
6. Click **Create**.

**What happens:** the runbook is saved to `~/.runbook/books/<name>.yaml` and the list refreshes to include it.

**Variations:**

- **Cancel** discards the in-progress draft. The editor doesn't persist drafts — close the sheet and the unsaved YAML is gone.
- **Name collision:** if `<name>.yaml` already exists, the Create button reports the conflict. Rename or delete the existing file first.

**Notes:** the `name:` field inside the YAML is what matters for `runbook run <name>` — but `runbook create` puts the new file at `<name>.yaml` and replaces the YAML's `name:` with the field you typed. So filename and `name:` start in sync; you can drift them later by editing.

---

### Scaffold from a template

**When to reach for this:** you're starting a runbook of a familiar shape (SSH deploy, HTTP healthcheck, scheduled backup) and don't want to write boilerplate.

**How:**

1. Click `+` in the sidebar's bottom toolbar.
2. In the template picker, select the template you want.
3. The editor pre-fills with the template's YAML, with `name:` replaced by an empty placeholder.
4. Type a name; tweak the steps; click **Create**.

**Variations:**

- **From the Runbook List:** templates appear in their own collapsible "Templates" section at the bottom, with an orange `template` badge. Right-click a template → "New from Template" opens the same sheet with that template pre-selected.
- **From the Detail view of a template:** the Run/Schedule buttons are replaced by "New from Template", which opens the sheet.

**Gotchas:**

- The template's `name:` field is replaced by `runbook create`. Don't bake meaning into a template's name — pick something descriptive (`ssh-remote-template`, not `template-1`).

**Notes:** authoring your own templates is straightforward — just save a YAML file under `~/.runbook/books/<name>/templates/<thing>.yaml`. Anything in a `templates/` subdirectory is automatically classified as a template. See the [CLI Cookbook → Author a template](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#author-a-template-for-a-shared-collection) for the full publish workflow.

---

### Edit a step inline

**When to reach for this:** you want to tweak one field — change a host, swap a command, flip `on_error` — without opening the full editor.

**How:**

1. In the Runbook Detail view, click a step row to expand it.
2. Find the field you want to change. Each editable value has a subtle hover state.
3. **Double-click** the value. It becomes a text field.
4. Edit, then either:
   - **Single-line value (host, timeout, capture name):** Press Return or click outside to save.
   - **Multi-line value (shell.command, ssh.command, http.body):** A popout editor opens with Bash/JSON syntax highlighting. Edit; press Cmd-W or click outside to save.
5. The detail view refreshes to show the persisted change.

**What happens:** the edit is applied immediately to the YAML file on disk. There's no Save button for inline edits — blur is the commit. The store re-loads the runbook so the detail view reflects the new state.

**Variations:**

- **Cancel an inline edit:** press Escape before blurring. The field reverts to its previous value.

**Gotchas:**

- Inline edits write to disk directly. There's no diff preview. If you change something accidentally and tab away, the change is saved. The `~/.runbook/backups/` directory has the previous version (every save creates a backup) so it's recoverable, but there's no in-app "undo" button. If safety matters more than speed, use the full YAML editor (next recipe).

**Notes:** the multi-line popout for shell commands is itself a separate sheet. Edits in the popout commit when the popout closes; they don't sync back to a still-open main editor. If you have both the YAML editor and a popout open, close the popout first, then the editor sees the persisted change on its next reload.

---

### Edit YAML with diff preview

**When to reach for this:** structural changes — adding steps, restructuring variables, rewriting a notify block. Anything where you want to see exactly what you're committing before it lands.

**How:**

1. In the Runbook Detail view, click the pencil icon in the toolbar.
2. The **Editor sheet** opens with the runbook's full YAML, syntax-highlighted.
3. Edit. Use Tab for context-aware completions (top-level keys, step types, error policies). Auto-indent fires after colon-terminated lines.
4. Click **Validate** (the toolbar button) to lint without saving — shows ✓ valid or a parse-error inline.
5. Click **Save**. If the YAML changed, the **Diff sheet** opens showing old vs. new side by side.
6. Confirm the diff and click Save again to commit.

**Variations:**

- **Discard changes:** Cancel button at the top dismisses the editor without saving. A confirmation prompts if there are unsaved changes.
- **Increase font size:** Settings → Editor → font size slider (9–24pt). Applies live to the open editor.

**Gotchas:**

- Validate writes the current buffer to a temp file and runs `runbook validate` on it. If the validate command fails for an environment reason (CLI not on PATH), the failure shows but it's about the validator, not the YAML. Check the CLI install status in Settings.
- **Save can fail after a successful Validate.** If the file write errors out (disk full, permission denied), the editor shows the error but doesn't revert your text. The buffer is still your in-progress edit; copy it to clipboard if you need to bail out cleanly.

**Notes:** every save creates a `~/.runbook/backups/<name>-<timestamp>.yaml.bak` of the previous content. Restore by copying back manually. There's no in-app restore UI.

---

### Validate before saving

**When to reach for this:** complex YAML where a typo could be expensive to discover by running.

**How:** in the YAML editor, click **Validate** in the toolbar. The result shows:

- **✓ valid (N steps)** — green, the YAML parses and every required field is present.
- **✗ N error(s)** — red, with the parse error or missing-field message.

**What happens:** the editor writes the current buffer to a temp file and runs `runbook validate <temp-path>`. The CLI is the source of truth for "is this YAML structurally correct" — the editor doesn't try to validate independently.

**Notes:** Validate doesn't catch *all* problems. A YAML that parses cleanly may still have:

- Variable references like `{{.foo}}` to undeclared variables (renders to empty at runtime, no error).
- `condition:` templates that never render to `"true"` (silent skip).
- Cross-step capture dependencies that race in a parallel group.

For these, Dry Run is the next layer of validation — it resolves variables and shows the planned step list, surfacing variable typos and obvious template issues.

---

## Observation

### Browse history

**When to reach for this:** "did this thing run last night?" / "what was the result of that deploy?" / "why did this fail at 3 AM?"

**How:**

1. Click **History** in the sidebar.
2. The list shows every run, newest first, with status icon + runbook name + relative date + step count + duration.
3. Filter with the search field at the top — matches against the runbook name.
4. Click a row's chevron to expand and see the per-step status list.

**Variations:**

- **Per-runbook history** is also visible inline: the Runbook Detail view's "Recent Runs" section shows the last 5 runs of the selected runbook.

**Notes:** the History view re-reads `~/.runbook/history/*.json` on each navigation to the section. If a run completes while you're already on the History view, click the search field and clear it (or click another sidebar item and back) to refresh.

---

### See a step's actual log slice

**When to reach for this:** you want to see what step 3 actually printed during the run that happened at 2:43 PM yesterday — not just its success/failure status.

**How:**

1. In the History view, expand a run.
2. Each step in the expanded section has its **own** chevron next to its name. Click it.
3. The app loads that step's log slice from the run's log file and displays it in a 240pt scrollable box, syntax-highlighted via `~/.runbook/highlights.yaml`.

**What happens:** `StepLogExtractor.findLogURL(for: record)` resolves the log file path:

1. **Index hit** — `LogIndex.logPath(for: record)` matches a precise log file.
2. **`~/.runbook/logs/<name>.log`** — if mtime is within 60s of the record's start time.
3. **`~/.runbook/history/<name>.log`** — same mtime gate.
4. **Newest matching `.log` or `.gz`** in `~/.runbook/logs/` or `~/.runbook/logs/archive/` — same mtime gate.

The mtime gate is what prevents a stale append-mode log from leaking content into an unrelated newer history record. Then `extractStepLines(logURL, stepName, record, runIndexFromEnd)` parses the file's run-section markers (`--- run: <ts>` or `Running: <name>` banner), scopes to the matching run section, and slices out the body lines for the named step.

**Gotchas:**

- **No log content** for a run → the run was launched without `log: enabled` in YAML *and* before the app's per-run log persistence (added 2026-04-28) was in place. Older runs don't have logs, period. Newer runs (app-launched and cron-launched both) always do.
- **Wrong content** (color shows green but you remember a failure) → likely the file resolution picked the wrong file. Check `~/.runbook/logs/index.json` and run `runbook log reindex` if rotation has shuffled things.

**Notes:** the per-step expansion is lazy — the file isn't read until you click the chevron. For runs with many steps, this matters; expanding the run row itself is cheap, but each step expansion is one file read + parse.

---

### View a full log file

**When to reach for this:** the per-step slice doesn't include enough context, or you want to see steps not in this run's history record.

**How:**

1. In the History view, expand a run.
2. Click the **View Full Log** button at the bottom of the expanded section.
3. The Log Viewer sheet opens.

**What you get:** the full file contents. If it's a `.gz` archive, the app decompresses it on the fly via `/usr/bin/gunzip -c`. If the file is **append-mode** (multiple runs), the sheet has a **picker** at the top listing each run's start timestamp; the app tries to pre-select the run matching the current history record. Switch via the picker to see other runs in the same file.

**Variations:**

- **Copy** the full text to clipboard via the toolbar.
- **Search** within the viewer (no separate find UI; use Cmd-F in the text view).

**Notes:** the viewer is read-only. To prune a long append-mode log, edit it externally with your favorite text editor, then run `runbook log reindex` so the LogIndex re-syncs to the new file shape.

---

### Search within console output

**When to reach for this:** a long-running runbook with hundreds of output lines, and you're hunting for a specific string.

**How:**

1. With the console tray expanded and your target session focused, press **⌘F** (or click the magnifying-glass icon in the toolbar).
2. The search bar appears. Type your query.
3. Each match is highlighted in yellow inline. The current match is brighter yellow.
4. Use the **prev / next** buttons (or Return / Shift-Return) to navigate.
5. Press Escape or click × to close the search bar.

**Notes:** search is plain substring (case-insensitive). No regex. For regex matches over a finished log, use Save to write the output to a file and run grep on it.

---

### Save run output

**When to reach for this:** you want a log of a run that didn't have `log: enabled` configured (rare these days — the app persists every run automatically — but still useful when you specifically want it somewhere outside `~/.runbook/logs/`).

**How:**

1. With the session shown in the tray, click **Save** in the output toolbar.
2. The standard macOS save panel opens. Pick a location and filename.
3. Click Save.

**What happens:** the captured output is written to your chosen path. The save also records the path in `LogIndex` so the History view can find the file later if it needs to.

**Notes:** this is useful when you want to share output with someone, attach it to a ticket, or keep a permanent record outside the rotating `~/.runbook/logs/`. The same content is also saved automatically to `~/.runbook/logs/<name>-<timestamp>.log`; Save is for getting a copy somewhere intentional.

---

## Scheduling

### Schedule a runbook via the cron UI

**When to reach for this:** you want a runbook to fire on a recurring schedule without using the terminal.

**How:**

1. Click **Schedules** in the sidebar.
2. Click **Add Schedule** (top right).
3. The Add form opens inline. Pick a runbook from the dropdown and enter a cron expression (e.g. `0 3 * * 0` for 3 AM Sunday).
4. As you type, the human-readable description renders below the field ("Every Sunday at 3:00 AM"). The next-run countdown also previews live.
5. Click **Save**.

**What happens:** the app calls `runbook cron add <name> "<schedule>"` via `RunbookCLI`. The CLI installs a crontab line tagged with `# runbook: <name>` (so `runbook cron list` and `runbook cron remove` can find it without disturbing other crontab entries). The Schedules view refreshes to show the new entry.

**Variations:**

- **Multiple schedules per runbook:** call Add Schedule again. Both lines coexist; you can remove either independently.
- **Same schedule from the runbook list:** right-click a runbook → Schedule. Opens a sheet with the same form.
- **Same schedule from the detail view:** Schedule button in the toolbar.

**Gotchas:**

- `runbook cron` requires the `crontab` binary, which is Unix-only. On macOS it's at `/usr/sbin/crontab` and runbook finds it. There's no "schedules" support on Linux through the GUI either — but the GUI works on Linux (in theory) and the CLI's cron subcommand works there.
- Crontab access on macOS Catalina+ requires Full Disk Access for `cron` itself: System Settings → Privacy & Security → Full Disk Access → add `/usr/sbin/cron`. Without this, scheduled runs install but never fire.

**Notes:** the schedule is set; the next time cron decides to fire it (`0 3 * * 0` = next Sunday at 3 AM), the runbook executes with `--no-tui --yes` and stdout appended to `~/.runbook/history/<name>.log`. The History view picks up the resulting record automatically.

---

### Edit a schedule

**When to reach for this:** changing the cron expression for an existing schedule.

**How:**

1. Schedules view → find the schedule row.
2. Click the **Edit** button (pencil icon) on the right.
3. The cron expression field becomes editable inline.
4. Edit. The description and next-run preview update live.
5. Click **Save** (or press Return).

**What happens:** the app removes the old crontab line and installs a new one. There's a brief window where neither exists, but cron's tick is per-minute, so unless you happen to edit during the precise tick, no schedule fires are missed.

**Variations:**

- **Cancel an edit:** click the × or press Escape — the field reverts.

---

### Inspect via the step flow chart

**When to reach for this:** you want a visual overview of what a scheduled runbook actually does, without opening its detail view.

**How:**

1. Schedules view → expand the chevron on a schedule row.
2. The step flow chart renders below the row: a custom-drawn canvas showing each step as a colored box (blue=shell, orange=ssh, green=http, gray=confirm), connected by arrows.
3. **Hover** a step → tooltip with the step name.
4. **Click** a step → flyout with the step's full config (command, host, URL, headers, options).
5. **Right-click** a step → flyout with the **last run's log slice** for that specific step.
6. **Double-click** a step → navigates to the runbook detail view with that step pre-expanded.

**The color legend** is always visible below the chart — you don't need to remember which color is which step type.

**Gotchas:**

- The right-click flyout only shows content if the step has actually run at least once. For a brand-new schedule, the right-click flyout shows "no log entries for this step."
- The flyout positioning is anchored to the center of the clicked pill. If you click near the edge of a pill, the flyout still appears centered on the pill, not at the cursor.

**Notes:** the chart is a custom SwiftUI `Canvas` (drawn with `context.draw` calls), not HTML or SVG. The chart exists primarily so you can quickly scan a schedule's structure without round-tripping to the detail view; it's not interactive in the deeper "drag to reorder" sense.

---

### Navigate from chart to runbook step

**When to reach for this:** you spotted something interesting in the chart's flyout (a host you forgot about, an unexpected step type) and you want to jump to that step in the runbook detail view to investigate further.

**How:**

1. **Double-click** the step pill in the chart.
2. The sidebar switches to **Runbooks**, the runbook is selected, and the runbook detail view scrolls to the step you clicked. The step is auto-expanded.

**What happens:** the canvas posts a `runbookNavigateToStep` notification. ContentView receives it, switches `sidebarSelection` to `.runbooks`, sets `selectedRunbook` to the right one, then 180ms later posts a `runbookExpandStep` notification. The detail view's listener catches that, inserts the step into its `expandedSteps` set, and scrolls to it via `ScrollViewReader`. The two-phase notification + delay handles the case where the detail view isn't yet mounted at the moment the user double-clicks.

**Notes:** there's no back button for "return to schedules from where I jumped" — use the sidebar to switch back manually.

---

## Sharing

> The shared collections workflow is documented in depth in the [CLI Cookbook → Sharing and templates](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#sharing-and-templates). The Mac app's Repositories view is a GUI for the `runbook pull` flow described there.

### Pull a shared collection

**When to reach for this:** your team (or a public source) maintains a git repo of runbooks and you want them all locally.

**How:**

1. Click **Repositories** in the sidebar.
2. Click **Pull New Repository** (top right).
3. The Pull sheet opens. Paste a git URL or a `.yaml` URL. Click Pull.
4. The CLI clones the repo (or downloads the file) into `~/.runbook/books/`. The Repositories list refreshes to show the new entry; the Runbook list refreshes to show the runbooks inside.

**What happens:** the app calls `runbook pull <url>` via `RunbookCLI`. The CLI does a `git clone --depth 1` for repos or an HTTP GET for single files. New runbooks become discoverable immediately by name.

**Gotchas:**

- **Authenticated repos:** if the remote requires SSH or token auth, the underlying `git clone` uses your normal git credentials (`~/.ssh/...`, git credential helpers). The app doesn't intercept auth; the pull will fail visibly if credentials aren't available.
- **Single-file pulls:** detected by the `.yaml` / `.yml` extension. Anything else is treated as a git URL.

---

### Refresh a pulled collection

**When to reach for this:** the upstream collection has new runbooks (or updates to existing ones) and you want to fast-forward your local copy.

**How:**

1. Repositories view → find the repo row → click **Update** (refresh icon).
2. The CLI runs `git pull --ff-only` in the existing checkout. The list refreshes when complete.

**Variations:**

- **Hands-off keep-fresh:** create a runbook that pulls the collections you care about, schedule it via cron. See the [CLI Cookbook → Keep pulled collections fresh](https://github.com/msjurset/runbook/blob/master/docs/guide/03-cookbook.md#keep-pulled-collections-fresh) for the full pattern.

**Gotchas:**

- **Local edits in pulled repos block the fast-forward.** If you've manually edited a YAML inside `~/.runbook/books/<repo>/`, the pull fails. Either commit/stash the change upstream, or move your local-only runbooks out of the pulled directory.

---

### Remove a pulled collection

**When to reach for this:** you no longer want a collection's runbooks discoverable.

**How:**

1. Repositories view → find the repo row → click **Remove** (trash icon).
2. Confirm the prompt.

**What happens:** the CLI calls `runbook pull remove <repo-name>` which removes the entire `~/.runbook/books/<repo-name>/` directory. **Irreversible** — but a fresh `runbook pull <url>` re-clones from the remote.

**Notes:** local-only runbooks living inside that subdirectory are gone too. Move them out before removing the repo if you want to keep them.

---

## Customization

### Pin a runbook

**When to reach for this:** a few runbooks you use constantly, lost in a list of dozens.

**How:**

- **Right-click** the runbook in the list → **Pin** (or **Unpin** if already pinned).
- Or, hover over a row's pin icon (left side) and click.

**What happens:** the runbook's name is added to `~/.runbook/pinned.json` (a JSON array). Pinned runbooks float to the top of the list, sorted alphabetically among themselves; unpinned runbooks below, also alphabetically.

**Notes:** persisted across app launches. Edit `pinned.json` manually if you want to bulk-pin (it's just `["name1", "name2", ...]`).

---

### Customize output highlighting

**When to reach for this:** the default colors don't match your conventions, or your runbooks emit domain-specific markers (`PASS`, `RETRY`, etc.) you want highlighted.

**How:**

1. Open `~/.runbook/highlights.yaml` in your favorite editor.
2. Edit the rules:

   ```yaml
   rules:
     - pattern: '(?i)pass'
       color: green
       bold: true
     - pattern: '(?i)retry'
       color: orange
     - pattern: '(?i)fail|error|fatal'
       color: red
       bold: true
   ```

3. Save. The next line rendered in the tray (or the History view, or the Log Viewer) uses the new rules. No app restart.

**Color names:** red, green, blue, orange, yellow, purple, cyan, gray, white, pink, teal. Or hex `#RRGGBB`.

**First-match wins** per line — order rules from most-specific to most-generic.

**Gotchas:**

- If the YAML is malformed, the highlighter silently falls back to the built-in defaults. Test with a known-bad input file (e.g. `runbook-mac/highlights-test.yaml` style) before relying on it for production runbooks.

**Notes:** the file is shared with `~/.runbook/highlights.yaml` consumed by the CLI's TUI mode (when running `runbook run` interactively in a terminal). Edit once, both render the same.

---

### Change the editor font size

**When to reach for this:** the default 12pt is too small for your screen, or too big for a packed view.

**How:**

1. Sidebar → ⚙ (Settings) at the bottom.
2. Settings → Editor section → font size slider (9–24pt).
3. The size applies live — open the editor and the change is already in effect.

**Notes:** font choice is monospaced and not user-configurable.

---

### Change the runbook directory

**When to reach for this:** you want runbooks somewhere other than `~/.runbook/books/` — e.g. an iCloud-synced folder, a shared NAS mount, a different volume.

**How:**

1. Settings → **Runbook Directory** section → click **Browse**.
2. Pick the new directory. The app validates that it's writable.
3. The Runbook list refreshes to discover from the new location.

**Variations:**

- **Reset to default:** click **Reset** in the same section.

**Gotchas:**

- The CLI doesn't know about this app-only setting unless you also pass `--dir <path>` to `runbook` invocations. The app passes the configured directory to every CLI call automatically (via `--dir`). When running `runbook` from the terminal directly, you'll either need to set up an alias or pass `--dir` manually.
- Cron-installed schedules use the CLI's default (`~/.runbook/books/`) regardless of the GUI setting. If you've moved the runbook directory, scheduled runs won't find runbooks by name unless you also reconfigure the CLI's default.

**Notes:** for most users, the default is fine. The setting exists for unusual environments (multi-user shared system, encrypted volume, etc.).

---

### Pre-warm 1Password secrets

**When to reach for this:** before scheduling a runbook that uses `op://` references, so the cron-launched run can read from the keychain without prompting Touch ID.

**How:**

1. Settings → **Credentials** section → click **Pre-warm**.
2. (This calls `goback auth` interactively if you have goback installed, which resolves all op:// secrets visible to it and caches them in the login keychain.)

**Variations:**

- **Per-runbook pre-warm via CLI:** `runbook auth <name>` resolves and caches just the secrets that runbook references. More targeted; lower keychain footprint.
- **Combine both:** the GUI pre-warm covers system-wide secrets, the per-runbook auth covers anything that runbook specifically needs.

**Gotchas:**

- **goback isn't installed by default.** If the Pre-warm button is disabled, install goback first (`brew install msjurset/tap/goback`) or use `runbook auth <name>` from the terminal.
- **Cached secrets don't auto-expire.** They sit in the keychain until cleared. To clear: `runbook auth --clear <name>` for a specific runbook, or use Keychain Access to delete entries with service name `runbook` or `goback`.

---

## Navigation

### Quick Jump to a runbook

**When to reach for this:** a runbook list with dozens of entries, and you know the name of the one you want.

**How:**

1. Press **⌘K** anywhere in the app.
2. The Quick Jump sheet opens with a search field at the top.
3. Type. Matching runbooks filter live.
4. Use ↑/↓ to navigate; Return to select.

**What happens:** the sidebar switches to Runbooks, the matching runbook is selected, and the detail view loads it.

**Notes:** Quick Jump matches against the runbook's `name:` field, case-insensitive substring. Doesn't search descriptions or step content.

---

### Keyboard shortcuts

The full table is in [Reference → Keyboard shortcuts](04-reference.md#keyboard-shortcuts). The most-used ones:

| Shortcut | Action |
|----------|--------|
| ⌘K | Quick Jump |
| ⌘1 | Go to Runbooks |
| ⌘2 | Go to History |
| ⌘3 | Go to Schedules |
| ⌘4 | Go to Repositories |
| ⌘? | Open Help window |
| ⌘F | Search within console output |
| ⌘. | Stop the current run |
| Esc | Dismiss popovers and sheets |

---

## Where to go next

- [Reference](04-reference.md) — keyboard shortcuts, file locations, settings.
- [Troubleshooting](05-troubleshooting.md) — when a recipe doesn't behave the way you'd expect.
- [Running as a Service](06-running-as-a-service.md) — Login Items, scheduling, and the auto-update flow.
- [Thinking in Runbook Mac](07-thinking-in-runbook-mac.md) — when to use the GUI vs. the terminal, design philosophy.
