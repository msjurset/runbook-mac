import SwiftUI
import WebKit

/// Renders a Mermaid flowchart in a lightweight WKWebView.
/// Loads mermaid.js from CDN on first use.
struct MermaidFlowView: NSViewRepresentable {
    let steps: [Step]
    let colorScheme: ColorScheme

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = buildHTML()
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func buildHTML() -> String {
        let isDark = colorScheme == .dark
        let bg = isDark ? "#1e1e1e" : "#ffffff"
        let fg = isDark ? "#e0e0e0" : "#333333"
        let mermaidTheme = isDark ? "dark" : "default"

        let diagram = buildDiagram()

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <style>
            body {
                margin: 0;
                padding: 4px;
                background: \(bg);
                overflow: hidden;
            }
            #diagram {
                width: 100%;
                overflow: hidden;
            }
            #diagram svg {
                width: 100% !important;
                height: auto !important;
            }
            .node rect, .node .label {
                cursor: default !important;
            }
        </style>
        </head>
        <body>
        <div id="diagram">
            <pre class="mermaid">
        \(diagram)
            </pre>
        </div>
        <script type="module">
            import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
            mermaid.initialize({
                startOnLoad: false,
                theme: '\(mermaidTheme)',
                flowchart: {
                    curve: 'basis',
                    padding: 14,
                    nodeSpacing: 25,
                    rankSpacing: 35,
                    htmlLabels: true,
                    wrappingWidth: 180,
                    useMaxWidth: false,
                },
                themeVariables: {
                    fontSize: '14px',
                    primaryColor: '\(isDark ? "#2a4a5a" : "#d4e8f0")',
                    primaryTextColor: '\(fg)',
                    primaryBorderColor: '\(isDark ? "#4a8a9a" : "#88bcd0")',
                    lineColor: '\(isDark ? "#555" : "#999")',
                    secondaryColor: '\(isDark ? "#3a3a2a" : "#fef3d0")',
                    tertiaryColor: '\(isDark ? "#2a3a2a" : "#d4f0d4")',
                }
            });

            // Render and then scale SVG to fill container
            await mermaid.run();
            setTimeout(() => {
                const svg = document.querySelector('#diagram svg');
                if (svg) {
                    const bbox = svg.getBBox();
                    // Set viewBox from bounding box
                    svg.setAttribute('viewBox',
                        (bbox.x - 5) + ' ' + (bbox.y - 5) + ' ' + (bbox.width + 10) + ' ' + (bbox.height + 10));
                    svg.style.width = '100%';
                    svg.style.height = 'auto';
                    svg.style.maxHeight = '180px';
                    // Notify WKWebView of content height
                    document.body.style.height = svg.getBoundingClientRect().height + 'px';
                }
            }, 100);
        </script>
        </body>
        </html>
        """
    }

    private func buildDiagram() -> String {
        // Use LR (left-to-right) — Mermaid handles wrapping via SVG viewBox scaling
        var lines = ["graph LR"]

        for (i, step) in steps.enumerated() {
            let id = "s\(i)"
            let name = step.name.replacingOccurrences(of: "\"", with: "'")

            // Node shape based on type
            let nodeShape: String
            if step.confirm != nil {
                nodeShape = "\(id){{\"\(name)\"}}" // hexagon for confirm
            } else {
                nodeShape = "\(id)([\"\(name)\"])" // stadium/pill
            }

            lines.append("    \(nodeShape)")

            // Style based on type
            let styleClass: String
            if step.confirm != nil {
                styleClass = "confirm"
            } else {
                switch step.type {
                case "ssh": styleClass = "ssh"
                case "http": styleClass = "http"
                default: styleClass = "shell"
                }
            }
            lines.append("    class \(id) \(styleClass)")

            // Edge to next step
            if i < steps.count - 1 {
                let nextId = "s\(i + 1)"
                if steps[i + 1].parallel == true {
                    lines.append("    \(id) -.-> \(nextId)")
                } else {
                    lines.append("    \(id) --> \(nextId)")
                }
            }
        }

        // Class definitions
        let isDark = colorScheme == .dark
        lines.append("    classDef ssh fill:\(isDark ? "#1a3a4a" : "#e0f4f4"),stroke:\(isDark ? "#4a9aaa" : "#5ab5b5"),color:\(isDark ? "#8adaea" : "#2a7a7a")")
        lines.append("    classDef shell fill:\(isDark ? "#1a2a4a" : "#dde8f8"),stroke:\(isDark ? "#4a6aaa" : "#6a9ad0"),color:\(isDark ? "#8ab0ea" : "#2a5a8a")")
        lines.append("    classDef http fill:\(isDark ? "#1a3a2a" : "#ddf8dd"),stroke:\(isDark ? "#4aaa6a" : "#5ab55a"),color:\(isDark ? "#8aea8a" : "#2a7a2a")")
        lines.append("    classDef confirm fill:\(isDark ? "#3a2a1a" : "#fef0dd"),stroke:\(isDark ? "#aa8a4a" : "#d0a050"),color:\(isDark ? "#eac080" : "#8a6020")")

        return lines.joined(separator: "\n")
    }
}
