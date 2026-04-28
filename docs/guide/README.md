# Runbook Mac User Guide

A comprehensive, recipe-driven guide for power users of the Runbook macOS app. For a feature overview or install instructions, start with the [project README](../../README.md). For the underlying CLI's docs (YAML schema, step types, variable resolution, scheduling), see the [runbook CLI guide](https://github.com/msjurset/runbook/tree/main/docs/guide).

## Who this guide is for

You're comfortable on macOS and have used `runbook` from the terminal at least a little — enough to know what a runbook YAML looks like and what a step does. The guide assumes that foundation and focuses on how the app surfaces those concepts, what each panel does, and how to move quickly between authoring, running, observing, and scheduling.

If you've never run `runbook` from the terminal, read the [runbook CLI Getting Started](https://github.com/msjurset/runbook/blob/main/docs/guide/01-getting-started.md) first (10 minutes). The Mac app builds on those concepts, it doesn't replace them.

## Contents

1. [Getting Started](01-getting-started.md) — install, first launch, CLI auto-install, the three-panel layout, run your first runbook from the GUI. ~10 minutes.
2. [Concepts](02-concepts.md) — how the app composes with the CLI, the three-panel layout, the console tray, the sidebar sections, where state lives on disk.
3. [Cookbook](03-cookbook.md) — task-oriented recipes: run with a Run sheet, retry with the dry checkbox, edit a step inline, schedule via the cron UI, pull a shared collection, customize output highlights.
4. [Reference](04-reference.md) — keyboard shortcuts, sidebar sections, console tray buttons, editor commands, file locations, `highlights.yaml` schema, version compatibility.
5. [Troubleshooting](05-troubleshooting.md) — symptom-driven fixes: CLI not found, runs missing from history, stale log content, schedules screen empty, pull failures, autofill / cursor issues in the editor.
6. [Running as a Service](06-running-as-a-service.md) — Login Items, the auto-update flow, scheduling via the in-app cron UI vs. `runbook cron` from the terminal, how the app and cron-launched runs share log files.
7. [Thinking in Runbook Mac](07-thinking-in-runbook-mac.md) — when to use the app vs. the CLI directly, the app's "frontend, not engine" philosophy, workflow patterns, anti-patterns.

## Relationship to the CLI guide

The Mac app is a **frontend** for the [runbook CLI](https://github.com/msjurset/runbook). It does not reimplement the runbook engine. Every run, every cron entry, every pull is delegated to the CLI binary on disk. The shared contract — YAML in `~/.runbook/books/`, history JSON in `~/.runbook/history/`, log files in `~/.runbook/logs/` — is exactly the same as if you ran `runbook` from the terminal.

That means:

- **YAML schema, step types, variable resolution, error policies, parallel groups, log/notify config** — all documented in the [CLI guide](https://github.com/msjurset/runbook/blob/main/docs/guide/02-concepts.md). This Mac-app guide does not duplicate that material; it points at it.
- **Cron syntax, history record format, log markers, op:// resolution, keychain caching** — same. Documented in the CLI guide.
- **What the app adds:** discovery and visualization of all of the above (browse the runbook list, expand steps, see the cron schedule's flow chart), an inline YAML editor with completion and diff preview, a non-modal console tray for concurrent runs, a History view that shows per-step log slices, and one-click access to operations that are otherwise multi-step (`runbook pull`, `runbook cron add`, `runbook auth`).

You can switch between the app and the CLI freely. A runbook authored in the editor runs the same way whether you click Run or type `runbook run <name>`. A schedule added in the cron UI is the same crontab line `runbook cron add` would have written. The app and the terminal observe the same state.

## Platform support

Runbook Mac runs on **macOS 15.0 (Sequoia) or later**. Apple Silicon and Intel are both supported via the universal binary. The `runbook` CLI (auto-installed on first launch if missing) supports macOS, Linux, and Windows — but the Mac app itself is macOS-only. For Linux and Windows users, run `runbook` from the terminal and read the [CLI guide](https://github.com/msjurset/runbook/tree/main/docs/guide).
