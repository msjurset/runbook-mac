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
                .heading("Quick Start"),
                .numbered([
                    "Create a runbook — Click the + button in the sidebar and choose a template",
                    "Edit the YAML — Customize the steps, variables, and settings",
                    "Run it — Select the runbook and click the Run button",
                    "View results — Check the History section for past runs",
                ]),
                .heading("File Locations"),
                .table(headers: ["Path", "Contents"], rows: [
                    ["~/.runbook/books/", "Runbook YAML files"],
                    ["~/.runbook/history/", "Run history (JSON files)"],
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
                .paragraph("Runs a command on a remote host. Reads ~/.ssh/config for host aliases, user, port, and identity settings. Supports 1Password SSH agent."),
                .code("- name: Restart service\n  type: ssh\n  ssh:\n    host: \"prod-01\"\n    user: \"deploy\"\n    agent_auth: true\n    command: \"sudo systemctl restart app\""),
                .table(headers: ["Field", "Description"], rows: [
                    ["host", "Hostname or SSH config alias"],
                    ["user", "Username (from SSH config or $USER if omitted)"],
                    ["port", "Port number (default: 22)"],
                    ["agent_auth", "Use SSH agent for authentication"],
                    ["key_file", "Path to private key file"],
                    ["command", "Command to execute remotely"],
                ]),
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
                .paragraph("Variables with op:// references are resolved through the 1Password CLI and cached in the system keychain."),
                .code("variables:\n  - name: api_token\n    default: \"op://Vault/Service/token\"\n    secret: true"),
                .heading("How It Works"),
                .numbered([
                    "On first run, runbook calls op read op://Vault/Service/token",
                    "The resolved value is cached in the macOS Keychain",
                    "Future runs load from keychain — no 1Password prompt needed",
                ]),
                .heading("Commands"),
                .code("runbook auth my-runbook          # Pre-cache secrets\nrunbook auth --clear my-runbook  # Clear cached secrets"),
                .heading("Supported Keychains"),
                .table(headers: ["Platform", "Backend"], rows: [
                    ["macOS", "Keychain (security command)"],
                    ["Linux", "GNOME Secret Service (secret-tool)"],
                    ["Windows", "Credential Manager (cmdkey)"],
                ]),
            ]

        case .scheduling:
            return [
                .paragraph("Schedule runbooks to run automatically via the system crontab."),
                .heading("From the App"),
                .paragraph("Go to Schedules in the sidebar to add, view, or remove cron entries."),
                .heading("CLI Commands"),
                .code("runbook cron add my-runbook \"0 3 * * 0\"\nrunbook cron list\nrunbook cron remove my-runbook"),
                .heading("Cron Syntax"),
                .code("┌───────── minute (0-59)\n│ ┌─────── hour (0-23)\n│ │ ┌───── day of month (1-31)\n│ │ │ ┌─── month (1-12)\n│ │ │ │ ┌─ day of week (0-7)\n│ │ │ │ │\n* * * * *"),
                .heading("Common Schedules"),
                .table(headers: ["Schedule", "Meaning"], rows: [
                    ["0 3 * * 0", "Sundays at 3:00 AM"],
                    ["*/15 * * * *", "Every 15 minutes"],
                    ["0 9 1 * *", "1st of each month at 9:00 AM"],
                    ["30 2 * * 1-5", "Weekdays at 2:30 AM"],
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
                .paragraph("All runbooks in pulled repos are automatically discovered."),
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
                    "Select a runbook in the sidebar",
                    "Click the Run (▶) button in the toolbar",
                    "Fill in any variable values",
                    "Click Run to start execution",
                    "Watch live output streaming in the runner window",
                ]),
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
                .paragraph("Click History in the sidebar to browse all runs. Click a row to expand and see per-step results, timing, and any errors. Use the filter bar to search by runbook name."),
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
                    ["Escape", "Close runner"],
                ]),
            ]
        }
    }
}
