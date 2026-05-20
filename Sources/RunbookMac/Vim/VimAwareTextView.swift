import AppKit
import VimEngine

/// Base class for any NSTextView that wants to participate in vim mode
/// and the `/`-prefix slash dropdown. Centralizes all the AppKit plumbing
/// (block cursor rendering, replace-mode overwrite, scroll-on-cursor-move
/// fix, keyDown forwarding, slash-key routing) so each editor subclass
/// only adds what's unique about it.
///
/// Hosts wire three closures: `vimEngineProvider` (non-nil engine =
/// active), `isShowingSlash` (host renders the pill iff this is true),
/// `slashKeyHandler` (host's nav/commit logic).
///
/// Subclasses that need to intercept keyDown for their own shortcuts
/// (Cmd+Return, Escape-to-cancel, etc.) override `handleSubclassKey`
/// instead of `keyDown` directly. The base class's `keyDown` ordering
/// is: vim → slash → subclass → super. Putting vim and slash first
/// matches the user-facing contract that vim's Esc beats every other
/// Esc handler while vim is active.
class VimAwareTextView: NSTextView {
    var vimEngineProvider: (() -> VimEngine?)?
    var isShowingSlash: (() -> Bool)?
    var slashKeyHandler: ((CodeEditorView.SuggestionKeyEvent) -> Bool)?

    /// Minimum width to use for the synthesized block cursor cell when
    /// the layout manager reports a zero-width rect (end-of-line,
    /// newline). Tuned per editor in subclasses with smaller fonts.
    open class var minBlockCursorWidth: CGFloat { 8 }

    // MARK: - Block cursor

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        guard let vim = vimEngineProvider?(), vim.submode != .insert else {
            super.drawInsertionPoint(in: rect, color: color, turnedOn: flag)
            return
        }
        guard flag, let block = blockCursorRect() else { return }
        NSColor.selectedTextBackgroundColor.withAlphaComponent(0.75).setFill()
        block.fill()
    }

    func refreshCursorArea() { invalidateBlockCursorArea() }

    private func invalidateBlockCursorArea() {
        guard let block = blockCursorRect() else { return }
        setNeedsDisplay(block.insetBy(dx: -1, dy: -1))
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        let oldRect = blockCursorRect()
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)

        guard let vim = vimEngineProvider?() else { return }

        // Vim mutates the cursor by assigning `selectedRange` directly,
        // which bypasses AppKit's scroll-to-reveal pipeline (wired
        // through insertText:). Reveal a zero-length range at the new
        // primary so vim selections don't pull the viewport across the
        // whole highlight span.
        if !stillSelecting, let primary = ranges.first?.rangeValue {
            scrollRangeToVisible(NSRange(location: primary.location, length: 0))
        }

        guard vim.submode != .insert else { return }
        if let oldRect {
            setNeedsDisplay(oldRect.insetBy(dx: -1, dy: -1))
        }
        if let newRect = blockCursorRect() {
            setNeedsDisplay(newRect.insetBy(dx: -1, dy: -1))
        }
    }

    private func blockCursorRect() -> NSRect? {
        guard let layoutManager, let textContainer else { return nil }
        let ns = string as NSString
        let cursor = selectedRange.location
        let fallback = Self.minBlockCursorWidth

        if cursor >= ns.length {
            let lineHeight = font?.boundingRectForFont.height ?? 16
            if ns.length == 0 {
                let origin = textContainerOrigin
                return NSRect(x: origin.x, y: origin.y, width: fallback, height: lineHeight)
            }
            let lastRange = NSRange(location: ns.length - 1, length: 1)
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lastRange, actualCharacterRange: nil)
            let lastRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            return NSRect(
                x: lastRect.maxX + textContainerOrigin.x,
                y: lastRect.minY + textContainerOrigin.y,
                width: max(lastRect.width, fallback),
                height: lastRect.height
            )
        }

        let range = NSRange(location: cursor, length: 1)
        let chAtCursor = ns.character(at: cursor)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var r = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        r.origin.x += textContainerOrigin.x
        r.origin.y += textContainerOrigin.y

        if chAtCursor == 0x0A {
            r.size.width = approximateCharWidth()
        } else if r.width <= 1 {
            r.size.width = approximateCharWidth()
        }
        return r
    }

    private func approximateCharWidth() -> CGFloat {
        let fallback = Self.minBlockCursorWidth
        guard let font else { return fallback }
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = ("M" as NSString).size(withAttributes: attributes)
        return size.width > 0 ? size.width : fallback
    }

    // MARK: - Replace-mode overwrite

    override func insertText(_ string: Any, replacementRange: NSRange) {
        if let vim = vimEngineProvider?(), vim.submode == .replace,
           let s = string as? String {
            overwriteText(s)
            return
        }
        super.insertText(string, replacementRange: replacementRange)
    }

    private func overwriteText(_ s: String) {
        let ns = self.string as NSString
        let cursor = selectedRange.location
        let canOverwrite = cursor < ns.length && ns.character(at: cursor) != 0x0A
        let range = canOverwrite
            ? NSRange(location: cursor, length: 1)
            : NSRange(location: cursor, length: 0)
        if shouldChangeText(in: range, replacementString: s) {
            replaceCharacters(in: range, with: s)
            didChangeText()
            let newLoc = cursor + (s as NSString).length
            setSelectedRange(NSRange(location: newLoc, length: 0))
        }
    }

    // MARK: - keyDown ordering

    override func keyDown(with event: NSEvent) {
        // 1. Vim owns the keyboard while active. Cmd-shortcuts bypass
        //    this via performKeyEquivalent earlier in the responder chain.
        if let vim = vimEngineProvider?() {
            let prevSubmode = vim.submode
            let handled = vim.handleKey(
                chars: event.charactersIgnoringModifiers,
                keyCode: event.keyCode,
                modifiers: KeyModifiers(event.modifierFlags),
                editor: self
            )
            if handled {
                if prevSubmode != vim.submode {
                    invalidateBlockCursorArea()
                }
                return
            }
        }

        // 2. Slash-suggestion navigation (only when the host says the
        //    dropdown is visible).
        if isShowingSlash?() == true {
            switch event.keyCode {
            case 125: if slashKeyHandler?(.arrowDown) == true { return }
            case 126: if slashKeyHandler?(.arrowUp) == true { return }
            case 36:  if slashKeyHandler?(.enter) == true { return }
            case 48:  if slashKeyHandler?(.tab) == true { return }
            case 53:  if slashKeyHandler?(.escape) == true { return }
            case 49:  if slashKeyHandler?(.space) == true { return }
            default: break
            }
        }

        // 3. Subclass-specific keys (Cmd+Return for save, Escape for
        //    cancel-edit, etc.). Putting these AFTER vim is the load-
        //    bearing ordering: Escape belongs to vim while active.
        if handleSubclassKey(event) { return }

        super.keyDown(with: event)
    }

    /// Subclass hook for post-vim/slash, pre-super key handling. Return
    /// true if consumed. Default = pass through.
    func handleSubclassKey(_ event: NSEvent) -> Bool { false }
}
