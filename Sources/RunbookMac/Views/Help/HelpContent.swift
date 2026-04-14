import Foundation

enum HelpSection {
    case heading(String)
    case subheading(String)
    case paragraph(String)
    case code(String)
    case table(headers: [String], rows: [[String]])
    case bullet([String])
    case numbered([String])
}

enum HelpTopic: String, CaseIterable, Identifiable {
    case gettingStarted = "Getting Started"
    case runbookFormat = "Runbook YAML Format"
    case variables = "Variables"
    case stepTypes = "Step Types"
    case errorPolicies = "Error Policies"
    case notifications = "Notifications"
    case secrets = "1Password Secrets"
    case logging = "Logging"
    case scheduling = "Cron Scheduling"
    case sharing = "Sharing & Importing"
    case editor = "Using the Editor"
    case running = "Running Runbooks"
    case history = "Run History"
    case keyboard = "Keyboard Shortcuts"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .gettingStarted: return "star"
        case .runbookFormat: return "doc.text"
        case .variables: return "textformat.abc"
        case .stepTypes: return "list.bullet.rectangle"
        case .errorPolicies: return "exclamationmark.triangle"
        case .notifications: return "bell"
        case .secrets: return "key"
        case .logging: return "doc.text.magnifyingglass"
        case .scheduling: return "calendar.badge.clock"
        case .sharing: return "arrow.down.circle"
        case .editor: return "pencil"
        case .running: return "play.fill"
        case .history: return "clock"
        case .keyboard: return "keyboard"
        }
    }

    var sections: [HelpSection] {
        switch self {
        case .gettingStarted:
            return [
                .paragraph("Runbook is a personal command center for defining and executing multi-step operational tasks. Runbooks are YAML files stored in ~/.runbook/books/."),
                .heading("Navigation"),
                .paragraph("The app uses a three-panel layout: sidebar for sections, a searchable runbook list in the middle, and the detail view on the right. Use the sidebar to switch between Runbooks, History, Schedules, and Repositories. The search bar at the top of the runbook list filters by name."),
                .heading("Quick Start"),
                .numbered([
                    "Create a runbook — Click the + button in the toolbar and choose a template, or right-click a template in the list and select New from Template",
                    "Edit the YAML — Customize the steps, variables, and settings",
                    "Run it — Select the runbook and click the Run button",
                    "View results — Check the History section for past runs",
                ]),
                .heading("File Locations"),
                .table(headers: ["Path", "Contents"], rows: [
                    ["~/.runbook/books/", "Runbook YAML files"],
                    ["~/.runbook/books/*/templates/", "Shared templates (shown separately)"],
                    ["~/.runbook/history/", "Run history (JSON files)"],
                    ["~/.runbook/logs/", "Saved run output logs"],
                    ["~/.runbook/backups/", "Auto-backups before save or delete"],
                ]),
            ]

        case .runbookFormat:
            return [
                .paragraph("Every runbook is a YAML file with these top-level fields:"),
                .code("name: my-runbook\ndescription: What it does\n\nvariables:\n  - name: host\n    default: \"localhost\"\n\nnotify:\n  on: failure\n  desktop: true\n\nsteps:\n  - name: Step 1\n    type: shell\n    shell:\n      command: \"echo hello\""),
                .heading("Top-Level Fields"),
                .table(headers: ["Field", "Required", "Description"], rows: [
                    ["name", "Yes", "Unique runbook name"],
                    ["description", "No", "Human-readable description"],
                    ["variables", "No", "Input parameters with defaults"],
                    ["steps", "Yes", "Ordered list of steps to execute"],
                    ["notify", "No", "Notification configuration"],
                    ["log", "No", "Automatic output logging (see Logging topic)"],
                ]),
            ]

        case .variables:
            return [
                .paragraph("Variables let you parameterize runbooks. They're resolved in priority order (highest wins):"),
                .numbered([
                    "CLI --var flag",
                    "Environment variable RUNBOOK_VAR_<NAME>",
                    "YAML default value",
                    "Interactive prompt (if prompt is set)",
                ]),
                .heading("Definition"),
                .code("variables:\n  - name: host\n    default: \"prod-01\"\n    required: true\n    prompt: \"Enter host\"\n    secret: true"),
                .heading("Template Syntax"),
                .paragraph("Reference variables in steps with Go template syntax:"),
                .code("command: \"ssh {{.host}} uptime\""),
                .heading("Output Capture"),
                .paragraph("Steps can capture their output into variables for later steps:"),
                .code("- name: Get version\n  type: shell\n  shell:\n    command: \"cat VERSION\"\n  capture: version\n\n- name: Tag release\n  type: shell\n  shell:\n    command: \"git tag {{.version}}\""),
            ]

        case .stepTypes:
            return [
                .heading("Shell"),
                .paragraph("Runs a local command via sh -c:"),
                .code("- name: Run tests\n  type: shell\n  shell:\n    command: \"go test ./...\"\n    dir: \"/path/to/project\""),
                .heading("SSH"),
                .paragraph("Runs a command on a remote host. Reads ~/.ssh/config for host aliases, user, port, and identity settings."),
                .code("- name: Restart service\n  type: ssh\n  ssh:\n    host: \"prod-01\"\n    user: \"deploy\"\n    key_file: \"op://Vault/SSH Key/private key\"\n    command: \"sudo systemctl restart app\""),
                .table(headers: ["Field", "Description"], rows: [
                    ["host", "Hostname or SSH config alias"],
                    ["user", "Username (from SSH config or $USER if omitted)"],
                    ["port", "Port number (default: 22)"],
                    ["agent_auth", "Use SSH agent for authentication (triggers 1Password prompt)"],
                    ["key_file", "Path to private key, or op:// reference (cached via runbook auth)"],
                    ["command", "Command to execute remotely"],
                ]),
                .heading("SSH Key Caching"),
                .paragraph("SSH keys referenced with op:// in key_file are resolved via 1Password and cached in the system keychain. Run `runbook auth <name>` once to cache, then all future runs use the cached key without Touch ID prompts. Use `runbook auth --clear <name>` to remove cached keys."),
                .heading("HTTP"),
                .paragraph("Makes an HTTP request. Responses with status 400+ are treated as errors."),
                .code("- name: Health check\n  type: http\n  http:\n    method: GET\n    url: \"https://api.example.com/health\"\n    headers:\n      Authorization: \"Bearer {{.token}}\""),
                .heading("Confirm"),
                .paragraph("A step with only a confirm field pauses for user confirmation:"),
                .code("- name: Confirm deploy\n  confirm: \"Deploy {{.version}} to production?\""),
            ]

        case .errorPolicies:
            return [
                .paragraph("Each step can define what happens when it fails:"),
                .table(headers: ["Policy", "Behavior"], rows: [
                    ["abort", "Stop the runbook (default)"],
                    ["continue", "Log the error, continue to next step"],
                    ["retry", "Retry the step up to retries times"],
                ]),
                .heading("Additional Step Options"),
                .table(headers: ["Field", "Description"], rows: [
                    ["timeout", "Per-step timeout (e.g., 30s, 5m)"],
                    ["condition", "Go template; runs only if it renders to \"true\""],
                    ["parallel", "Run concurrently with adjacent parallel steps"],
                    ["capture", "Store output in a variable for later steps"],
                ]),
                .heading("Example"),
                .code("- name: Flaky API call\n  type: http\n  http:\n    url: \"https://api.example.com/webhook\"\n  on_error: retry\n  retries: 3\n  timeout: 30s"),
            ]

        case .notifications:
            return [
                .paragraph("Runbooks can send notifications after completion:"),
                .code("notify:\n  on: failure\n  desktop: true\n  slack:\n    webhook: \"https://hooks.slack.com/...\"\n    channel: \"#ops\"\n  email:\n    to: \"me@example.com\"\n    from: \"runbook@example.com\"\n    host: \"smtp.gmail.com:587\""),
                .heading("Channels"),
                .table(headers: ["Channel", "Description"], rows: [
                    ["desktop", "Native OS notification (macOS, Linux, Windows)"],
                    ["slack", "Posts to Slack incoming webhook"],
                    ["email", "Sends email via SMTP"],
                ]),
                .heading("Testing"),
                .paragraph("Use the CLI to send a test notification:"),
                .code("runbook notify my-runbook\nrunbook notify --fail my-runbook"),
            ]

        case .secrets:
            return [
                .paragraph("Variables and SSH keys with op:// references are resolved through the 1Password CLI and cached in the system keychain."),
                .code("variables:\n  - name: api_token\n    default: \"op://Vault/Service/token\"\n    secret: true\n\nsteps:\n  - name: Deploy\n    type: ssh\n    ssh:\n      key_file: \"op://Vault/SSH Key/private key\"\n      host: \"prod-01\"\n      command: \"deploy.sh\""),
                .heading("How It Works"),
                .numbered([
                    "Run runbook auth <name> to resolve and cache all op:// references",
                    "Variables and SSH private keys are cached in the macOS Keychain",
                    "Future runs load from keychain — no 1Password or Touch ID prompt",
                    "SSH keys support both OpenSSH and PKCS#8 formats (1Password export)",
                ]),
                .heading("Commands"),
                .code("runbook auth my-runbook          # Pre-cache all secrets + SSH keys\nrunbook auth --clear my-runbook  # Clear cached secrets + SSH keys"),
                .heading("Pre-warming from the App"),
                .paragraph("Scheduled (cron) runs execute in a non-interactive session where the keychain is locked for writes. If a secret hasn't been cached yet, the run will fail. Open Settings (gear icon in the sidebar) and click Pre-warm in the Credentials section to resolve and cache all goback secrets interactively. This also runs goback auth for goback-managed secrets like API tokens."),
                .heading("Supported Keychains"),
                .table(headers: ["Platform", "Backend"], rows: [
                    ["macOS", "Keychain (security command)"],
                    ["Linux", "GNOME Secret Service (secret-tool)"],
                    ["Windows", "Credential Manager (cmdkey)"],
                ]),
            ]

        case .logging:
            return [
                .paragraph("Runbooks can automatically save output to log files after each run."),
                .heading("Configuration"),
                .code("log:\n  enabled: true\n  mode: append    # or \"new\" (default)\n  dir: \"~/.runbook/logs/\"\n  filename: \"{name}-{timestamp}\""),
                .heading("Log Modes"),
                .table(headers: ["Mode", "Behavior"], rows: [
                    ["new", "Creates a new file per run: {name}-{timestamp}.log (default)"],
                    ["append", "Appends to a single file: {name}.log with --- run: timestamp --- separators"],
                ]),
                .heading("Fields"),
                .table(headers: ["Field", "Description"], rows: [
                    ["enabled", "true to auto-save output (default: false)"],
                    ["mode", "\"new\" for per-run files, \"append\" for single cumulative file"],
                    ["dir", "Log directory (default: ~/.runbook/logs/)"],
                    ["filename", "Template with {name} and {timestamp} placeholders"],
                ]),
                .heading("Viewing Logs"),
                .paragraph("In the History view, runs with saved logs show a document icon and a \"View Saved Log\" link. For append-mode logs, a picker lets you select which run to view."),
                .heading("Log Rotation"),
                .paragraph("Logs can be rotated using the rotate-runbook-logs runbook, triggered by sortie when a file exceeds a size threshold. Rotated files are compressed and moved to ~/.runbook/logs/archive/. The log index is updated to maintain history linkage."),
                .heading("Log Index"),
                .paragraph("Log-to-history associations are stored in ~/.runbook/logs/index.json. After manual log rotation, run:"),
                .code("runbook log reindex       # Rebuild index from files\nrunbook log reset-index   # Clear the index\nrunbook log update <old> <new>  # Update a path"),
                .heading("Manual Save"),
                .paragraph("The Save button in the runner output toolbar is always available, regardless of log configuration. It lets you save output to any location via a file dialog."),
            ]

        case .scheduling:
            return [
                .paragraph("Schedule runbooks to run automatically via the system crontab."),
                .heading("From the App"),
                .paragraph("Go to Schedules in the sidebar to add, view, or remove cron entries. Start typing a runbook name to see autocomplete suggestions. After entering a cron expression, a plain English description appears below the field."),
                .heading("CLI Commands"),
                .code("runbook cron add my-runbook \"0 3 * * 0\"\nrunbook cron list\nrunbook cron remove my-runbook"),
                .heading("Cron Syntax"),
                .code("┌───────── minute (0-59)\n│ ┌─────── hour (0-23)\n│ │ ┌───── day of month (1-31)\n│ │ │ ┌─── month (1-12)\n│ │ │ │ ┌─ day of week (0-6, Sun=0)\n* * * * *"),
                .heading("Symbols"),
                .table(headers: ["Symbol", "Meaning", "Example"], rows: [
                    ["*", "Every value", "* in hour = every hour"],
                    [",", "List of values", "1,3,5 in day-of-week = Mon, Wed, Fri"],
                    ["-", "Range", "1-5 in day-of-week = Mon through Fri"],
                    ["/", "Step interval", "*/15 in minute = every 15 min"],
                ]),
                .paragraph("When both day-of-month and day-of-week are specified, cron fires when either matches (OR, not AND). For example, \"0 9 1 * 1\" runs at 9 AM on the 1st of each month and on every Monday."),
                .heading("Common Schedules"),
                .table(headers: ["Schedule", "Meaning"], rows: [
                    ["0 9 * * *", "Every day at 9:00 AM"],
                    ["0 3 * * 0", "Every Sunday at 3:00 AM"],
                    ["*/15 * * * *", "Every 15 minutes"],
                    ["0 8 * * 1-5", "Weekdays at 8:00 AM"],
                    ["0 0 1 * *", "1st of every month at midnight"],
                    ["0 9 1/15 * 6", "Every 15 days from the 1st, and Saturdays, at 9 AM"],
                ]),
                .paragraph("Logs are captured to ~/.runbook/history/<name>.log."),
            ]

        case .sharing:
            return [
                .heading("Pull from Git"),
                .paragraph("Clone a repository of runbooks:"),
                .code("runbook pull github.com/user/runbooks"),
                .paragraph("Re-running the same URL updates to the latest version."),
                .heading("Download a Single File"),
                .code("runbook pull https://example.com/deploy.yaml"),
                .heading("From the App"),
                .paragraph("Go to Repositories in the sidebar to pull, list, or remove repos."),
                .heading("Managing Repos"),
                .code("runbook pull list\nrunbook pull remove name"),
                .paragraph("All runbooks in pulled repos are automatically discovered. YAML files inside directories named templates/ are shown in a separate Templates section in the runbook list."),
                .heading("Templates"),
                .paragraph("Templates are starting points for new runbooks. They appear in a collapsible section with an orange badge. All discovered templates also appear in the New Runbook dialog (click + in the sidebar). To create a runbook from a template:"),
                .bullet([
                    "Click + in the sidebar and pick a template from the list",
                    "Right-click a template in the list and choose New from Template",
                    "Or select the template and click New from Template in the toolbar",
                ]),
                .paragraph("You can also duplicate any existing runbook by right-clicking it and choosing Duplicate."),
                .heading("Pinning Runbooks"),
                .paragraph("Right-click a runbook and choose Pin to keep it at the top of the list. Click the pin icon to unpin. Pinned runbooks are persisted across sessions in ~/.runbook/pinned.json."),
            ]

        case .editor:
            return [
                .paragraph("The built-in editor provides syntax-highlighted YAML editing with auto-completion."),
                .heading("Syntax Highlighting"),
                .table(headers: ["Color", "Element"], rows: [
                    ["Blue", "YAML keys"],
                    ["Green", "Quoted strings"],
                    ["Purple", "Booleans (true, false)"],
                    ["Orange", "Numbers"],
                    ["Gray", "Comments"],
                    ["Pink", "Template expressions ({{.var}})"],
                    ["Teal", "op:// references"],
                    ["Yellow", "List dashes (-)"],
                ]),
                .heading("Auto-Complete"),
                .paragraph("Press Tab to trigger context-aware completions. The editor suggests top-level keys, step fields, type values, and error policies based on cursor position."),
                .heading("Auto-Indent"),
                .paragraph("Pressing Return after a line ending with : auto-indents by 2 spaces."),
                .heading("Validation"),
                .paragraph("Click Validate to check the YAML structure without saving."),
            ]

        case .running:
            return [
                .heading("From the App"),
                .numbered([
                    "Select a runbook from the list",
                    "Click the Run (▶) button in the toolbar",
                    "Fill in any variable values",
                    "Click Run to start execution",
                    "Watch live output streaming in the runner window",
                ]),
                .heading("Stopping a Run"),
                .paragraph("Click the Stop button or press ⌘. to terminate a running process."),
                .heading("Dry Run"),
                .paragraph("Check the Dry Run checkbox before clicking Run to preview what a runbook will do without executing. The header shows a blue 'preview' badge. After a dry run completes, you can uncheck the box and click Run to execute for real — no need to close and reopen."),
                .heading("Output Controls"),
                .paragraph("After output starts streaming, a toolbar appears above the output area:"),
                .bullet([
                    "Find (⌘F) — Search within output with match highlighting and up/down navigation",
                    "Copy All — Copy all output lines to the clipboard",
                    "Save — Save output to a .log file (defaults to ~/.runbook/logs/ with a timestamped filename)",
                ]),
                .heading("Output Highlighting"),
                .paragraph("Output lines are syntax-highlighted using pattern-matching rules. Rules are loaded from ~/.runbook/highlights.yaml at startup. Edit the file to add new patterns, change colors, or reorder rules (first match wins). If the file is missing, built-in defaults are used."),
                .code("# ~/.runbook/highlights.yaml\nrules:\n  - pattern: '^\\[OK\\]'\n    color: green\n  - pattern: '^\\[WARNING\\]'\n    color: orange\n    bold: true\n  - pattern: '^Status: Downloaded'\n    color: \"#4CAF50\""),
                .paragraph("Supported colors: red, green, blue, orange, yellow, purple, cyan, gray, white, pink, teal, or hex #RRGGBB. Highlighting applies to both the runner output and the log viewer."),
                .heading("Auto-Logging"),
                .paragraph("If the runbook has log.enabled: true, output is automatically saved after each run. See the Logging topic for details."),
                .heading("CLI Commands"),
                .code("runbook run my-runbook\nrunbook run --var host=prod deploy\nrunbook run --dry-run deploy.yaml\nrunbook run --no-tui --yes my-runbook"),
                .heading("TUI Keyboard Controls"),
                .table(headers: ["Key", "Action"], rows: [
                    ["j / k", "Navigate steps"],
                    ["Enter", "View step output"],
                    ["s", "Skip a pending step"],
                    ["r", "Retry a failed step"],
                    ["y / n", "Respond to confirmation prompts"],
                    ["PgUp / PgDn", "Scroll output"],
                    ["q", "Quit"],
                ]),
            ]

        case .history:
            return [
                .paragraph("Every runbook execution is recorded as a JSON file in ~/.runbook/history/."),
                .heading("From the App"),
                .paragraph("Click History in the sidebar to browse all runs. Click a row to expand and see per-step results, timing, and any errors. Use the filter bar to search by runbook name. Runs with saved logs show a document icon and a \"View Saved Log\" link. For append-mode logs, a picker lets you switch between runs in the same file."),
                .heading("CLI Commands"),
                .code("runbook history\nrunbook history -n 10\nrunbook history --runbook deploy"),
                .heading("Record Contents"),
                .bullet([
                    "Runbook name and file path",
                    "Start time and total duration",
                    "Success/failure status",
                    "Per-step name, status, duration, and error (if any)",
                ]),
            ]

        case .keyboard:
            return [
                .heading("App Shortcuts"),
                .table(headers: ["Shortcut", "Action"], rows: [
                    ["⌘1", "Go to Runbooks"],
                    ["⌘2", "Go to History"],
                    ["⌘3", "Go to Schedules"],
                    ["⌘4", "Go to Repositories"],
                    ["⌘K", "Quick jump to runbook by name"],
                    ["⌘N", "New runbook"],
                    ["⌘R", "Refresh runbook list"],
                    ["⌘?", "Open help"],
                ]),
                .heading("Editor Shortcuts"),
                .table(headers: ["Shortcut", "Action"], rows: [
                    ["Tab", "Trigger auto-complete"],
                    ["⌘S", "Save"],
                    ["Escape", "Cancel / close sheet"],
                ]),
                .heading("Runner Shortcuts"),
                .table(headers: ["Shortcut", "Action"], rows: [
                    ["⌘Return", "Start run"],
                    ["⌘.", "Stop running process"],
                    ["⌘F", "Search output"],
                    ["Escape", "Close runner"],
                ]),
            ]
        }
    }
}
