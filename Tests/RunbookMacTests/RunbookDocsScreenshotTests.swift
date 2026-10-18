import XCTest
import SwiftUI
import AppKit
@testable import RunbookMac

struct DocCallout: Identifiable {
    let number: Int
    let title: String
    let subtitle: String
    let targetRect: CGRect
    let badgeCenter: CGPoint
    let color: Color

    var id: Int { number }

    var estimatedBadgeRect: CGRect {
        let charCount = max(title.count, subtitle.count)
        let width = max(185.0, min(265.0, CGFloat(charCount) * 6.5 + 56.0))
        let height: CGFloat = 46.0
        return CGRect(
            x: badgeCenter.x - width / 2.0,
            y: badgeCenter.y - height / 2.0,
            width: width,
            height: height
        )
    }

    var targetAnchorPoint: CGPoint {
        let clampedX = min(max(badgeCenter.x, targetRect.minX), targetRect.maxX)
        let clampedY = min(max(badgeCenter.y, targetRect.minY), targetRect.maxY)
        return CGPoint(x: clampedX, y: clampedY)
    }
}

struct AnnotatedScreenshotCanvas<Content: View>: View {
    let content: Content
    let callouts: [DocCallout]
    let size: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            content
                .frame(width: size.width, height: size.height)
                .background(Color(NSColor.windowBackgroundColor))

            Canvas { context, _ in
                for callout in callouts {
                    let start = callout.badgeCenter
                    let end = callout.targetAnchorPoint

                    var glowPath = Path()
                    glowPath.move(to: start)
                    glowPath.addLine(to: end)
                    context.stroke(
                        glowPath,
                        with: .color(.black.opacity(0.55)),
                        style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                    )

                    var linePath = Path()
                    linePath.move(to: start)
                    linePath.addLine(to: end)
                    context.stroke(
                        linePath,
                        with: .color(callout.color),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [6, 4])
                    )

                    let dotRect = CGRect(x: end.x - 5, y: end.y - 5, width: 10, height: 10)
                    context.fill(Path(ellipseIn: dotRect), with: .color(callout.color))
                    context.stroke(Path(ellipseIn: dotRect), with: .color(.white), lineWidth: 1.8)
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)

            ForEach(callouts) { callout in
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.black.opacity(0.65), lineWidth: 4.0)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(callout.color, lineWidth: 2.2)
                    )
                    .frame(width: callout.targetRect.width, height: callout.targetRect.height)
                    .position(x: callout.targetRect.midX, y: callout.targetRect.midY)
            }

            ForEach(callouts) { callout in
                HStack(spacing: 8) {
                    Text("\(callout.number)")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(callout.color))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(callout.title)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(callout.subtitle)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.82))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .strokeBorder(callout.color, lineWidth: 1.6)
                        )
                )
                .shadow(color: .black.opacity(0.55), radius: 8, x: 0, y: 4)
                .position(x: callout.badgeCenter.x, y: callout.badgeCenter.y)
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Color(NSColor.windowBackgroundColor))
        .environment(\.colorScheme, .dark)
    }
}

final class RunbookDocsScreenshotTests: XCTestCase {

    private func assertNoCalloutOverlaps(callouts: [DocCallout], size: CGSize, path: String) {
        let canvasBounds = CGRect(origin: .zero, size: size)
        for i in 0..<callouts.count {
            let a = callouts[i]
            let badgeA = a.estimatedBadgeRect

            XCTAssertTrue(
                canvasBounds.contains(badgeA),
                "[\(path)] Callout #\(a.number) badge \(badgeA) is outside canvas bounds \(canvasBounds)"
            )

            for j in 0..<callouts.count {
                let b = callouts[j]
                if i < j {
                    let badgeB = b.estimatedBadgeRect
                    XCTAssertFalse(
                        badgeA.insetBy(dx: -4, dy: -4).intersects(badgeB),
                        "[\(path)] Callout #\(a.number) badge overlaps Callout #\(b.number) badge"
                    )
                    XCTAssertFalse(
                        a.targetRect.intersects(b.targetRect),
                        "[\(path)] Callout #\(a.number) targetRect overlaps Callout #\(b.number) targetRect"
                    )
                }
                XCTAssertFalse(
                    badgeA.intersects(b.targetRect),
                    "[\(path)] Callout #\(a.number) badge \(badgeA) overlaps Callout #\(b.number) targetRect \(b.targetRect)"
                )
            }
        }
    }

    @MainActor
    private func renderAnnotatedSnapshot<V: View>(
        _ view: V,
        callouts: [DocCallout],
        size: CGSize,
        to outputPath: String
    ) throws {
        assertNoCalloutOverlaps(callouts: callouts, size: size, path: outputPath)

        let annotated = AnnotatedScreenshotCanvas(content: view, callouts: callouts, size: size)
        let hostingView = NSHostingView(rootView: annotated)
        hostingView.appearance = NSAppearance(named: .darkAqua)
        hostingView.frame = CGRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1.0)
        window.contentView = hostingView
        window.layoutIfNeeded()
        hostingView.layoutSubtreeIfNeeded()

        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        hostingView.layoutSubtreeIfNeeded()

        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            XCTFail("Failed to allocate bitmap image rep for \(outputPath)")
            return
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)

        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to encode PNG data for \(outputPath)")
            return
        }

        let url = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try pngData.write(to: url)

        if !callouts.isEmpty && outputPath.hasSuffix(".png") {
            try renderAnnotatedSnapshot(view, callouts: [], size: size, to: String(outputPath.dropLast(4)) + "_clean.png")
        }
    }

    @MainActor
    private func makeSyntheticEnvironment() throws -> (baseDir: URL, store: RunbookStore, sessions: RunSessionStore, logURL: URL) {
        let baseDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("runbook-docs-\(UUID().uuidString)")
        let booksDir = baseDir.appendingPathComponent("books")
        let templatesDir = booksDir.appendingPathComponent("infra-playbooks/templates")
        let historyDir = baseDir.appendingPathComponent("history")
        let pinnedFile = baseDir.appendingPathComponent("pinned.json")
        let logsDir = baseDir.appendingPathComponent("logs")

        try FileManager.default.createDirectory(at: booksDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: templatesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: historyDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        let pinnedJSON = try JSONEncoder().encode(["prod-k3s-rollout", "postgres-wal-verify"])
        try pinnedJSON.write(to: pinnedFile)

        let k3sYAML = """
        name: prod-k3s-rollout
        summary: Zero-downtime K3s cluster upgrade with 1Password secrets and Slack alerts
        description: |
          Drains worker nodes sequentially, verifies containerd health over SSH,
          applies updated manifests, and posts rollout telemetry to Slack.
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
              port: 22
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
          - name: post-audit-webhook
            type: http
            parallel: true
            http:
              method: POST
              url: https://hooks.slack.com/services/T0000/B0000/SYNTHETIC
              body: |
                {
                  "cluster": "{{cluster_host}}",
                  "release": "{{release_tag}}",
                  "status": "upgraded"
                }
        notify:
          on: failure
          desktop: true
          slack:
            webhook: op://Homelab/Slack/ops-webhook
            channel: "#infra-alerts"
        log:
          enabled: true
          mode: append
        """
        try k3sYAML.write(to: booksDir.appendingPathComponent("prod-k3s-rollout.yaml"), atomically: true, encoding: .utf8)

        let pgYAML = """
        name: postgres-wal-verify
        summary: Nightly PostgreSQL basebackup & WAL archive integrity verification
        variables:
          - name: pg_host
            default: db-primary.lab.internal
            required: true
          - name: backup_bucket
            default: s3://homelab-backups/pg-wal
        steps:
          - name: check-replication-lag
            type: ssh
            timeout: 20s
            ssh:
              host: "{{pg_host}}"
              user: postgres
              command: psql -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"
          - name: verify-s3-manifest
            type: shell
            timeout: 2m
            capture: latest_backup_id
            shell:
              command: restic -r {{backup_bucket}} snapshots --latest 1 --json
          - name: notify-status
            type: http
            http:
              method: POST
              url: https://ntfy.lab.internal/backups
        """
        try pgYAML.write(to: booksDir.appendingPathComponent("postgres-wal-verify.yaml"), atomically: true, encoding: .utf8)

        let certYAML = """
        name: tls-cert-renew
        summary: Renew internal ACME wildcard certificates and reload reverse proxies
        steps:
          - name: issue-acme-cert
            type: shell
            shell:
              command: lego --dns cloudflare --domains "*.lab.internal" renew
          - name: reload-caddy
            type: ssh
            ssh:
              host: edge-proxy.lab.internal
              user: admin
              command: sudo systemctl reload caddy
        """
        try certYAML.write(to: booksDir.appendingPathComponent("tls-cert-renew.yaml"), atomically: true, encoding: .utf8)

        let dnsYAML = """
        name: coredns-zone-sync
        summary: Validate CoreDNS zone files and roll out split-horizon records
        steps:
          - name: lint-zonefile
            type: shell
            shell:
              command: named-checkzone lab.internal ./zones/db.lab.internal
          - name: sync-primary-ns
            type: ssh
            ssh:
              host: ns1.lab.internal
              user: dnsadmin
              command: sudo systemctl reload coredns
        """
        try dnsYAML.write(to: booksDir.appendingPathComponent("coredns-zone-sync.yaml"), atomically: true, encoding: .utf8)

        let tmplYAML = """
        name: ssh-rolling-restart
        summary: Template for rolling systemd service restarts across a host fleet
        steps:
          - name: restart-unit
            type: ssh
            ssh:
              host: "{{target_host}}"
              command: sudo systemctl restart {{service_name}}
        """
        try tmplYAML.write(to: templatesDir.appendingPathComponent("ssh-rolling-restart.yaml"), atomically: true, encoding: .utf8)

        // Write synthetic history records
        let fmt = ISO8601DateFormatter()
        let now = Date()
        let run1Start = fmt.string(from: now.addingTimeInterval(-900))
        let run2Start = fmt.string(from: now.addingTimeInterval(-7200))
        let run3Start = fmt.string(from: now.addingTimeInterval(-18000))
        let run4Start = fmt.string(from: now.addingTimeInterval(-43200))

        let records: [HistoryRecord] = [
            HistoryRecord(
                runbook_name: "prod-k3s-rollout",
                file_path: booksDir.appendingPathComponent("prod-k3s-rollout.yaml").path,
                started_at: run1Start,
                duration: "18.4s",
                success: true,
                step_count: 4,
                steps: [
                    StepRecord(name: "preflight-health", type: "http", status: "success", duration: "420ms", error: nil),
                    StepRecord(name: "drain-and-upgrade", type: "ssh", status: "success", duration: "14.2s", error: nil),
                    StepRecord(name: "verify-workloads", type: "shell", status: "success", duration: "3.5s", error: nil),
                    StepRecord(name: "post-audit-webhook", type: "http", status: "success", duration: "280ms", error: nil),
                ]
            ),
            HistoryRecord(
                runbook_name: "postgres-wal-verify",
                file_path: booksDir.appendingPathComponent("postgres-wal-verify.yaml").path,
                started_at: run2Start,
                duration: "6.8s",
                success: true,
                step_count: 3,
                steps: [
                    StepRecord(name: "check-replication-lag", type: "ssh", status: "success", duration: "810ms", error: nil),
                    StepRecord(name: "verify-s3-manifest", type: "shell", status: "success", duration: "5.7s", error: nil),
                    StepRecord(name: "notify-status", type: "http", status: "success", duration: "290ms", error: nil),
                ]
            ),
            HistoryRecord(
                runbook_name: "tls-cert-renew",
                file_path: booksDir.appendingPathComponent("tls-cert-renew.yaml").path,
                started_at: run3Start,
                duration: "4.1s",
                success: false,
                step_count: 2,
                steps: [
                    StepRecord(name: "issue-acme-cert", type: "shell", status: "success", duration: "3.2s", error: nil),
                    StepRecord(name: "reload-caddy", type: "ssh", status: "failed", duration: "900ms", error: "ssh: handshake failed: edge-proxy.lab.internal:22 connection refused"),
                ]
            ),
            HistoryRecord(
                runbook_name: "coredns-zone-sync",
                file_path: booksDir.appendingPathComponent("coredns-zone-sync.yaml").path,
                started_at: run4Start,
                duration: "2.3s",
                success: true,
                step_count: 2,
                steps: [
                    StepRecord(name: "lint-zonefile", type: "shell", status: "success", duration: "310ms", error: nil),
                    StepRecord(name: "sync-primary-ns", type: "ssh", status: "success", duration: "1.9s", error: nil),
                ]
            ),
        ]

        for (idx, rec) in records.enumerated() {
            let data = try JSONEncoder().encode(rec)
            try data.write(to: historyDir.appendingPathComponent("run-\(idx).json"))
        }

        let logURL = logsDir.appendingPathComponent("prod-k3s-rollout.log")
        let logContent = """
        Running: prod-k3s-rollout — Zero-downtime K3s cluster upgrade
        ▸ Step 1: preflight-health [http]
          │ GET https://k3s-ctrl-01.lab.internal:6443/livez → 200 OK (420ms)
          │ Captured variable: cluster_state = "ok"
          ✓ done (420ms)
        ▸ Step 2: drain-and-upgrade [ssh]
          │ node/k3s-ctrl-01.lab.internal cordoned
          │ evicting pod ingress-nginx/ingress-nginx-controller-69b8d9
          │ k3s.service restarted cleanly (v1.31.2+k3s1)
          │ node/k3s-ctrl-01.lab.internal uncordoned
          ✓ done (14.2s)
        ▸ Step 3: verify-workloads [shell]
          │ NAME                       STATUS   ROLES                  AGE    VERSION
          │ k3s-ctrl-01.lab.internal   Ready    control-plane,master   142d   v1.31.2+k3s1
          │ deployment "ingress-nginx-controller" successfully rolled out
          ✓ done (3.5s)
        ✓ Runbook succeeded in 18.4s
        """
        try logContent.write(to: logURL, atomically: true, encoding: .utf8)

        let store = RunbookStore(booksDir: booksDir, historyDir: historyDir, pinnedFile: pinnedFile)
        store.loadAll()

        let sessions = RunSessionStore()
        sessions.consoleHeight = 195
        let activeSession = RunSession(
            runbookName: "prod-k3s-rollout",
            dryRun: false,
            vars: [
                "cluster_host": "k3s-ctrl-01.lab.internal",
                "release_tag": "v1.31.2+k3s1"
            ],
            startedAt: now.addingTimeInterval(-19),
            endedAt: now,
            output: logContent.components(separatedBy: "\n"),
            state: .succeeded
        )
        _ = activeSession.elapsed(now: now)
        sessions.injectSession(activeSession)

        return (baseDir, store, sessions, logURL)
    }

    @MainActor
    func testGenerateDocumentationScreenshots() throws {
        let (baseDir, store, sessions, logURL) = try makeSyntheticEnvironment()
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let assetsDir = repoRoot.appendingPathComponent("docs/assets")
        let size = CGSize(width: 1280, height: 820)

        guard let k3sBook = store.runbooks.first(where: { $0.name == "prod-k3s-rollout" }) else {
            XCTFail("Expected prod-k3s-rollout in synthetic store")
            return
        }

        // 1. Runbook Workbench (Sidebar + List + Detail with expanded steps + Docked Console Tray)
        let workbenchView = HStack(spacing: 0) {
            SidebarView(selection: .constant(.runbooks))
                .frame(width: 190)
            Divider()
            RunbookListView(selectedRunbook: .constant(k3sBook))
                .frame(width: 270)
            Divider()
            RunbookDetailView(runbook: k3sBook, initialExpandedSteps: [0, 1])
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ConsoleTray()
        }
        .environment(store)
        .environment(sessions)

        let workbenchCallouts: [DocCallout] = [
            DocCallout(
                number: 1,
                title: "Pinned Runbooks & Templates",
                subtitle: "FSEvents-watched YAML library",
                targetRect: CGRect(x: 196, y: 45, width: 258, height: 265),
                badgeCenter: CGPoint(x: 325, y: 410),
                color: .cyan
            ),
            DocCallout(
                number: 2,
                title: "Variables & op:// Secrets",
                subtitle: "1Password references resolved at runtime",
                targetRect: CGRect(x: 476, y: 105, width: 470, height: 128),
                badgeCenter: CGPoint(x: 1125, y: 165),
                color: .orange
            ),
            DocCallout(
                number: 3,
                title: "Interactive Step Inspector",
                subtitle: "Double-click any value or code block to edit",
                targetRect: CGRect(x: 476, y: 252, width: 470, height: 295),
                badgeCenter: CGPoint(x: 1125, y: 395),
                color: .purple
            ),
            DocCallout(
                number: 4,
                title: "Docked Streaming Console Tray",
                subtitle: "Concurrent run tabs with live step output",
                targetRect: CGRect(x: 12, y: 582, width: 935, height: 228),
                badgeCenter: CGPoint(x: 1125, y: 695),
                color: .green
            ),
        ]

        try renderAnnotatedSnapshot(
            workbenchView,
            callouts: workbenchCallouts,
            size: size,
            to: assetsDir.appendingPathComponent("runbook_workbench.png").path
        )

        // 2. YAML Editor, Vim Engine & Side-by-Side Diff Review
        let originalYAML = store.readRawYAML(for: k3sBook) ?? ""
        let modifiedYAML = originalYAML
            .replacingOccurrences(of: "default: v1.31.2+k3s1", with: "default: v1.31.3+k3s1")
            .replacingOccurrences(of: "timeout: 15s", with: "timeout: 30s")

        let editorSplitView = HStack(spacing: 0) {
            EditorView(
                runbook: k3sBook,
                initialVimActive: true,
                initialShowDiff: false,
                initialModifiedContent: modifiedYAML
            )
            .frame(width: 680)
            Divider()
            DiffView(
                original: originalYAML,
                modified: modifiedYAML,
                onConfirm: {},
                onCancel: {}
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(store)
        .environment(sessions)

        let editorCallouts: [DocCallout] = [
            DocCallout(
                number: 1,
                title: "Live YAML & Token Highlighting",
                subtitle: "Highlights keys, {{vars}}, and op:// secrets",
                targetRect: CGRect(x: 14, y: 62, width: 650, height: 320),
                badgeCenter: CGPoint(x: 340, y: 455),
                color: .cyan
            ),
            DocCallout(
                number: 2,
                title: "Modal Vim Engine & Slash Bar",
                subtitle: "Click :_ or type /vim for Normal/Insert modes",
                targetRect: CGRect(x: 415, y: 765, width: 255, height: 42),
                badgeCenter: CGPoint(x: 245, y: 780),
                color: .purple
            ),
            DocCallout(
                number: 3,
                title: "Pre-Save LCS Diff Verification",
                subtitle: "Inspect exact line additions & removals",
                targetRect: CGRect(x: 694, y: 62, width: 572, height: 410),
                badgeCenter: CGPoint(x: 980, y: 560),
                color: .green
            ),
        ]

        try renderAnnotatedSnapshot(
            editorSplitView,
            callouts: editorCallouts,
            size: size,
            to: assetsDir.appendingPathComponent("yaml_vim_editor.png").path
        )

        // 3. Cron & Launchd Scheduler with Serpentine StepFlowCanvas
        let sampleSchedules: [CronView.ScheduleEntry] = [
            CronView.ScheduleEntry(
                name: "prod-k3s-rollout",
                schedule: "0 3 * * 0",
                command: "launchd env=production",
                description: CronDescription.describe("0 3 * * 0"),
                vars: ["cluster_host=k3s-ctrl-01.lab.internal", "release_tag=v1.31.2+k3s1"],
                backend: "launchd"
            ),
            CronView.ScheduleEntry(
                name: "postgres-wal-verify",
                schedule: "30 1 * * *",
                command: "launchd",
                description: CronDescription.describe("30 1 * * *"),
                vars: ["pg_host=db-primary.lab.internal"],
                backend: "launchd"
            ),
            CronView.ScheduleEntry(
                name: "postgres-wal-verify",
                schedule: "0 6 1 * *",
                command: "launchd",
                description: CronDescription.describe("0 6 1 * *"),
                vars: ["pg_host=db-replica.lab.internal", "full_verify=true"],
                backend: "launchd"
            ),
            CronView.ScheduleEntry(
                name: "tls-cert-renew",
                schedule: "15 4 * * 1",
                command: "cron",
                description: CronDescription.describe("15 4 * * 1"),
                vars: [],
                backend: "cron"
            ),
        ]

        let cronSnapshotView = HStack(spacing: 0) {
            SidebarView(selection: .constant(.cron))
                .frame(width: 190)
            Divider()
            CronView(
                initialSchedules: sampleSchedules,
                initialHoveredRowID: "prod-k3s-rollout|0 3 * * 0",
                autoLoad: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(store)
        .environment(sessions)

        let cronCallouts: [DocCallout] = [
            DocCallout(
                number: 1,
                title: "Multi-Schedule Runbook Groups",
                subtitle: "Daily & monthly cadences share one header",
                targetRect: CGRect(x: 204, y: 66, width: 640, height: 178),
                badgeCenter: CGPoint(x: 1085, y: 155),
                color: .purple
            ),
            DocCallout(
                number: 2,
                title: "Serpentine StepFlowCanvas",
                subtitle: "Click pills for config; right-click for logs",
                targetRect: CGRect(x: 204, y: 252, width: 520, height: 34),
                badgeCenter: CGPoint(x: 1085, y: 269),
                color: .cyan
            ),
            DocCallout(
                number: 3,
                title: "Human-Readable Cron & Vars",
                subtitle: "English schedule translation + --var overrides",
                targetRect: CGRect(x: 204, y: 425, width: 640, height: 132),
                badgeCenter: CGPoint(x: 1085, y: 490),
                color: .orange
            ),
        ]

        try renderAnnotatedSnapshot(
            cronSnapshotView,
            callouts: cronCallouts,
            size: size,
            to: assetsDir.appendingPathComponent("cron_scheduler.png").path
        )

        // 4. Execution History & Per-Step Log Slices
        let firstRecordID = store.historyRecords[0].id
        let thirdRecordID = store.historyRecords[2].id
        let stepSliceText = """
          │ node/k3s-ctrl-01.lab.internal cordoned
          │ evicting pod ingress-nginx/ingress-nginx-controller-69b8d9
          │ k3s.service restarted cleanly (v1.31.2+k3s1)
          │ node/k3s-ctrl-01.lab.internal uncordoned
          ✓ done (14.2s)
        """

        let historySnapshotView = HStack(spacing: 0) {
            SidebarView(selection: .constant(.history))
                .frame(width: 190)
            Divider()
            HistoryListView(
                initialExpandedRecordIDs: [firstRecordID, thirdRecordID],
                initialExpandedSteps: [firstRecordID: ["drain-and-upgrade"]],
                preloadedStepLogs: ["\(firstRecordID)|drain-and-upgrade": stepSliceText],
                customLogURLs: [firstRecordID: logURL]
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(store)
        .environment(sessions)

        let historyCallouts: [DocCallout] = [
            DocCallout(
                number: 1,
                title: "Instant Runbook History Filter",
                subtitle: "Filter historical executions by runbook name",
                targetRect: CGRect(x: 204, y: 12, width: 650, height: 38),
                badgeCenter: CGPoint(x: 1085, y: 31),
                color: .cyan
            ),
            DocCallout(
                number: 2,
                title: "Per-Step Timing & Status Breakdown",
                subtitle: "Inspect step durations and exit statuses",
                targetRect: CGRect(x: 204, y: 58, width: 650, height: 68),
                badgeCenter: CGPoint(x: 1085, y: 95),
                color: .green
            ),
            DocCallout(
                number: 3,
                title: "Run-Scoped Step Log Extraction",
                subtitle: "Lazy-loads exact step output from log archives",
                targetRect: CGRect(x: 232, y: 132, width: 620, height: 78),
                badgeCenter: CGPoint(x: 1085, y: 175),
                color: .purple
            ),
            DocCallout(
                number: 4,
                title: "Inline Failure Diagnostics",
                subtitle: "Surfaces SSH/HTTP error strings immediately",
                targetRect: CGRect(x: 204, y: 325, width: 650, height: 85),
                badgeCenter: CGPoint(x: 1085, y: 368),
                color: .orange
            ),
        ]

        try renderAnnotatedSnapshot(
            historySnapshotView,
            callouts: historyCallouts,
            size: size,
            to: assetsDir.appendingPathComponent("execution_history.png").path
        )
    }
}
