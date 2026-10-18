# Runbook Practical Cookbook

Step-by-step operational recipes for **Runbook** on macOS. Each recipe pairs UI workflows with production-ready YAML patterns so you can author, test, schedule, and audit infrastructure automation with confidence.

---

## Table of Contents

1. [Recipe 1: Zero-Downtime Cluster Rollout with 1Password Secrets & Pre-Flight Gate](#recipe-1-zero-downtime-cluster-rollout-with-1password-secrets--pre-flight-gate)
2. [Recipe 2: Fast Iteration with Dry-Run Previews & In-Place Tray Retries](#recipe-2-fast-iteration-with-dry-run-previews--in-place-tray-retries)
3. [Recipe 3: Modal Vim Editing, Inline Code Popouts & Pre-Save LCS Diffs](#recipe-3-modal-vim-editing-inline-code-popouts--pre-save-lcs-diffs)
4. [Recipe 4: Multi-Cadence Cron Scheduling with `--var` Overrides & Pipeline Inspection](#recipe-4-multi-cadence-cron-scheduling-with---var-overrides--pipeline-inspection)
5. [Recipe 5: Post-Incident Triage with Run-Scoped Step Log Extraction](#recipe-5-post-incident-triage-with-run-scoped-step-log-extraction)
6. [Recipe 6: Standardizing Team Playbooks via Pulled Git Collections & Templates](#recipe-6-standardizing-team-playbooks-via-pulled-git-collections--templates)
7. [Recipe 7: Customizing Console Output Highlighting (`~/.runbook/highlights.yaml`)](#recipe-7-customizing-console-output-highlighting-runbookhighlightsyaml)

---

## Recipe 1: Zero-Downtime Cluster Rollout with 1Password Secrets & Pre-Flight Gate

**Goal:** Build a multi-step rollout playbook that probes an HTTP health endpoint using a 1Password bearer token, captures the cluster state, drains and restarts nodes over SSH, and posts an audit payload on completion.

![Runbook Workbench & Streaming Console Tray](assets/runbook_workbench.png)

### Step-by-Step

1. Click `+` in the Runbook list filter bar (`⌘N`) and select **Blank**.
2. Name the runbook `prod-k3s-rollout` and paste the following YAML:

```yaml
name: prod-k3s-rollout
summary: Zero-downtime K3s cluster upgrade with 1Password secrets and Slack alerts
variables:
  - name: cluster_host
    default: k3s-ctrl-01.lab.internal
    required: true
  - name: release_tag
    default: v1.31.2+k3s1
    required: true
  - name: kube_token
    default: op://Homelab/K3s-Cluster/api-token
    required: true
    secret: true
steps:
  - name: preflight-health
    type: http
    timeout: 15s
    retries: 2
    capture: cluster_state
    http:
      method: GET
      url: https://{{cluster_host}}:6443/livez
      headers:
        Authorization: Bearer {{kube_token}}
  - name: drain-and-upgrade
    type: ssh
    timeout: 5m
    on_error: abort
    ssh:
      host: "{{cluster_host}}"
      user: ops
      agent_auth: true
      command: |
        kubectl drain {{cluster_host}} --ignore-daemonsets --delete-emptydir-data
        sudo systemctl restart k3s
        kubectl uncordon {{cluster_host}}
  - name: verify-workloads
    type: shell
    timeout: 45s
    condition: "{{cluster_state}} != ''"
    shell:
      dir: ~/workspace/infra/k3s
      command: |
        kubectl get nodes -o wide
        kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx
notify:
  on: failure
  desktop: true
  slack:
    webhook: op://Homelab/Slack/ops-webhook
    channel: "#infra-alerts"
```

3. Click **Validate** to verify schema integrity, then click **Create**.
4. Right-click `prod-k3s-rollout` in the list and select **Pin** so it stays anchored at the top of your library (**Callout 1**).
5. Click **Run** in the top-right toolbar. Notice in the **Variables** card (**Callout 2**) and **Run Confirm Sheet** that `op://Homelab/K3s-Cluster/api-token` is never exposed in plaintext—the CLI resolves it at runtime and caches it in the macOS Keychain.

---

## Recipe 2: Fast Iteration with Dry-Run Previews & In-Place Tray Retries

**Goal:** Verify variable interpolation and step execution order without mutating remote hosts, then flip immediately to a live run from the console tray.

### Step-by-Step

1. Select a runbook and click **Run** (or right-click the row and choose **Dry Run**).
2. In the **Run Confirm Sheet**, check **Dry Run** and click **Dry Run**.
3. The **Console Tray** (**Callout 4** in the workbench screenshot) slides open at the bottom of the window, displaying the resolved variable map and planned step execution sequence with a `dry` badge in the session tab.
4. Once the dry run finishes (`✓ Succeeded`), look at the right side of the console tray's bottom toolbar:
   - Uncheck the inline **Dry** checkbox next to **Retry**.
   - Click **Retry**.
5. Runbook clears the tab's buffer, resets the elapsed timer, and executes the real run **in place** within the same tab.

> [!NOTE]
> **Concurrent Execution**: You never have to wait for a slow rollout to finish before starting another task. Navigate to any other runbook and click **Run**—a new session tab appears in `SessionTabBar` so you can monitor multiple playbooks in parallel.

---

## Recipe 3: Modal Vim Editing, Inline Code Popouts & Pre-Save LCS Diffs

**Goal:** Edit complex YAML configurations or embedded multi-line Bash/JSON payloads using modal Vim keybindings and verify exact line changes before writing to disk.

![YAML Editor, Modal Vim Engine & Pre-Save Diff Review](assets/yaml_vim_editor.png)

### Step-by-Step

1. **Inline Field Tweaks**: In `RunbookDetailView`, expand any step and **double-click** a single-line field (such as `timeout` or `host`) to edit it in place, or **double-click** a multiline `command` / `body` block to open the 900×520 syntax-highlighted popout editor.
2. **Full YAML Editing**: Click the **Edit** (pencil) button in the detail toolbar to open `EditorView` (**Callout 1**).
3. **Activate Modal Vim Mode**:
   - Click the `:_` watermark button in the bottom bar (**Callout 2**) or type `/vim` at the start of a line and press `Return`.
   - The `VIM:N` capsule badge appears alongside the `?` cheatsheet button. Use standard Vim motions (`w`, `b`, `f`, `ci"`, `dd`, `/search`, `.`) to make your edits.
4. **Review Pre-Save Diff**:
   - Type `:w<Return>` in Vim Normal mode or click **Save**.
   - The **Review Changes** diff sheet (**Callout 3**) highlights removed lines in red (`-`) and added lines in green (`+`).
   - Click **Save** to commit the change (automatically archiving the prior version in `~/.runbook/backups/`).

---

## Recipe 4: Multi-Cadence Cron Scheduling with `--var` Overrides & Pipeline Inspection

**Goal:** Schedule a database verification runbook to run both nightly (against a primary host) and on the 1st of every month (against a replica with full verification enabled), and inspect its step pipeline visually.

![Cron & Launchd Scheduler with Serpentine StepFlowCanvas](assets/cron_scheduler.png)

### Step-by-Step

1. Open **Schedules** (`⌘3`) in the sidebar and click **Add Schedule**.
2. Select `postgres-wal-verify`, enter `30 1 * * *`, and add a variable override `pg_host=db-primary.lab.internal`.
3. Click **Add Schedule** a second time for `postgres-wal-verify`, enter `0 6 1 * *`, and add `pg_host=db-replica.lab.internal` and `full_verify=true`.
4. Runbook automatically merges both schedules into a **Multi-Schedule Runbook Group** (**Callout 1**), displaying each schedule's plain-English translation, next-run countdown, and `--var` overrides above a single shared **`StepFlowCanvas`** (**Callout 2**).
5. Interact directly with the serpentine pipeline:
   - **Left-click** any step pill (`check-replication-lag`) to inspect its SSH/Shell configuration.
   - **Right-click** any step pill to view the stdout/stderr slice from the most recent run of that step.
   - **Double-click** any step pill to jump straight to `RunbookDetailView` with that step expanded.

> [!IMPORTANT]
> **Pre-Warming 1Password Secrets for Unattended Runs**: Cron jobs run without an interactive TTY (`--no-tui --yes`). Before scheduling a runbook that references `op://` secrets, run `runbook auth <runbook-name>` in your terminal (or click **Pre-warm** in **Settings → Credentials**) so the secret is cached in your login Keychain.

---

## Recipe 5: Post-Incident Triage with Run-Scoped Step Log Extraction

**Goal:** Diagnose a failed overnight run in seconds without grepping through multi-megabyte append logs.

![Execution History & Per-Step Log Extraction](assets/execution_history.png)

### Step-by-Step

1. Switch to **History** (`⌘2`) and type a runbook name into the **Filter by runbook name** bar (**Callout 1**).
2. Locate any failed run (`✗` red badge) and click anywhere on the row to expand its per-step breakdown (**Callout 2**).
3. Failed steps immediately display their captured error message in red beneath the step name (**Callout 4**, e.g., `ssh: handshake failed: edge-proxy.lab.internal:22 connection refused`).
4. Click the chevron next to any step to lazy-load its **Run-Scoped Step Log Slice** (**Callout 3**). Runbook scopes the log file to that exact execution timestamp and extracts only the lines emitted by that step.
5. Click the copy icon (`doc.on.doc`) in the top-right corner of the step log slice to copy the diagnostic output to your clipboard, or click **View Full Log** at the bottom of the run to browse the entire log file across historical run sections.

---

## Recipe 6: Standardizing Team Playbooks via Pulled Git Collections & Templates

**Goal:** Share a central repository of operational runbooks and starter templates across machines or team members.

### Step-by-Step

1. Switch to **Repositories** (`⌘4`) in the sidebar and click **Pull Repository**.
2. Enter your team's Git repository URL (e.g., `https://github.com/your-org/infra-runbooks.git`) and click **Pull**.
3. All runbooks in the repository immediately appear in your **Runbooks** list with a subtle repository badge, while any YAML files under `templates/` populate the collapsible **Templates** section.
4. To create a new runbook from a team template:
   - Right-click the template under **Templates** and select **New from Template**.
   - Enter a new runbook name, customize the hosts or variables in the YAML editor, and click **Create**.

---

## Recipe 7: Customizing Console Output Highlighting (`~/.runbook/highlights.yaml`)

**Goal:** Highlight custom domain markers (such as Terraform plan changes, Kubernetes statuses, or custom test runners) in the live Console Tray and History log slices.

### Step-by-Step

1. Create or edit `~/.runbook/highlights.yaml`:

```yaml
rules:
  - pattern: '(?i)\b(ready|active|rolled out|0 to destroy)\b'
    color: green
    bold: true
  - pattern: '(?i)\b(cordoned|evicting|draining|retrying)\b'
    color: orange
  - pattern: '(?i)\b(crashloopbackoff|oomkilled|connection refused|fatal)\b'
    color: red
    bold: true
```

2. Restart Runbook (`⌘Q` and reopen).
3. Both the live **Console Tray** and **History** step log slices apply your rules (first-match wins) while automatically turning any `https://...` URLs in the output into clickable browser links.
