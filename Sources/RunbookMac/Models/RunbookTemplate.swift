import Foundation

struct RunbookTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let content: String
}

extension RunbookTemplate {
    static let templates: [RunbookTemplate] = [
        RunbookTemplate(
            id: "blank",
            name: "Blank",
            description: "Empty runbook with a single shell step",
            content: """
            name: my-runbook
            description: ""

            steps:
              - name: Step 1
                type: shell
                shell:
                  command: "echo hello"
            """
        ),
        RunbookTemplate(
            id: "ssh-deploy",
            name: "SSH Deploy",
            description: "Deploy to a remote server via SSH",
            content: """
            name: deploy
            description: Deploy application to production

            variables:
              - name: host
                required: true
                prompt: "Enter deploy host"
              - name: user
                default: "deploy"

            steps:
              - name: Run tests
                type: shell
                shell:
                  command: "echo 'Running tests...'"
                timeout: 5m
                on_error: abort

              - name: Confirm deployment
                confirm: "Deploy to {{.host}}?"

              - name: Deploy
                type: ssh
                ssh:
                  host: "{{.host}}"
                  user: "{{.user}}"
                  agent_auth: true
                  command: "sudo systemctl restart app"
                timeout: 30s
            """
        ),
        RunbookTemplate(
            id: "healthcheck",
            name: "Health Check",
            description: "Check health of multiple HTTP endpoints",
            content: """
            name: healthcheck
            description: Check service health

            variables:
              - name: base_url
                default: "http://localhost"

            steps:
              - name: Check API
                type: http
                http:
                  method: GET
                  url: "{{.base_url}}/healthz"
                capture: api_status
                on_error: continue

              - name: Report
                type: shell
                shell:
                  command: "echo 'API: {{.api_status}}'"
            """
        ),
        RunbookTemplate(
            id: "maintenance",
            name: "Server Maintenance",
            description: "Update packages and check for reboot on a remote server",
            content: """
            name: server-maintenance
            description: Update OS packages on a remote server

            variables:
              - name: host
                required: true
                prompt: "Enter server hostname"
              - name: user
                default: "admin"

            notify:
              on: always
              desktop: true

            steps:
              - name: Update package lists
                type: ssh
                ssh:
                  host: "{{.host}}"
                  user: "{{.user}}"
                  agent_auth: true
                  command: "sudo apt-get update"
                timeout: 5m
                on_error: abort

              - name: Upgrade packages
                type: ssh
                ssh:
                  host: "{{.host}}"
                  user: "{{.user}}"
                  agent_auth: true
                  command: "sudo apt-get upgrade -y"
                timeout: 15m
                on_error: abort

              - name: Check for reboot
                type: ssh
                ssh:
                  host: "{{.host}}"
                  user: "{{.user}}"
                  agent_auth: true
                  command: "test -f /var/run/reboot-required && echo reboot-needed || echo no-reboot"
                capture: reboot_status
                on_error: continue
            """
        ),
    ]
}
