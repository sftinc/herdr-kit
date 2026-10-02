import AppKit
import SwiftTerm

// SwiftTerm's view is invisible to accessibility. Report it as a text area so
// dictation tools (e.g. VoiceBar) see a text input and paste into it.
final class HerdrTerminalView: LocalProcessTerminalView {
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .textArea }

    // Cmd+Delete erases the line, as in Terminal.app: send Ctrl-U (kill line).
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command && event.keyCode == 51 {
            send([0x15])
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, LocalProcessTerminalViewDelegate {
    var window: NSWindow!
    var terminal: HerdrTerminalView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        terminal = HerdrTerminalView(frame: NSRect(x: 0, y: 0, width: 1000, height: 650))
        terminal.processDelegate = self
        terminal.optionAsMetaKey = true
        // Match Terminal.app's Basic profile: JetBrains Mono Nerd Font 14 pt and system text colors.
        terminal.font = NSFont(name: "JetBrainsMonoNF-Regular", size: 14)
            ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        terminal.configureNativeColors()

        window = NSWindow(
            contentRect: terminal.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Herdr"
        window.contentView = terminal
        window.center()
        window.setFrameAutosaveName("HerdrMainWindow")
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(terminal)

        watchLeftOptionChords()

        terminal.startProcess(
            executable: loginShell(),
            args: ["-l", "-i", "-c", "exec herdr"],
            environment: environment(),
            currentDirectory: NSHomeDirectory()
        )
        NSApp.activate(ignoringOtherApps: true)
    }

    // Left Option + key sends herdr's prefix (Ctrl-B) and then the key, so left Option+h
    // is prefix+h. Right Option still works as Meta.
    func watchLeftOptionChords() {
        let leftOptionMask: UInt = 0x20 // NX_DEVICELALTKEYMASK
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags
            guard flags.rawValue & leftOptionMask != 0,
                  flags.isDisjoint(with: [.command, .control]),
                  let key = event.charactersIgnoringModifiers,
                  key.allSatisfy(\.isASCII),
                  let terminal = self?.terminal
            else { return event }
            terminal.send([0x02] + Array(key.utf8))
            return nil
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // The shell from the user's account record; Finder-launched apps may not have $SHELL.
    func loginShell() -> String {
        if let pw = getpwuid(getuid()), let shell = pw.pointee.pw_shell {
            return String(cString: shell)
        }
        return "/bin/zsh"
    }

    func environment() -> [String] {
        // Launched via `open` from inside herdr, the app inherits herdr's pane variables,
        // and herdr then refuses to start ("nested herdr is disabled").
        var env = ProcessInfo.processInfo.environment.filter {
            !$0.key.hasPrefix("HERDR_") && !$0.key.hasPrefix("TERM_PROGRAM")
        }
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        if env["LANG"] == nil { env["LANG"] = "en_US.UTF-8" }
        return env.map { "\($0.key)=\($0.value)" }
    }

    func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Hide Herdr", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Herdr", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(withTitle: "Herdr", action: nil, keyEquivalent: "").submenu = appMenu

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(TerminalView.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(TerminalView.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSResponder.selectAll(_:)), keyEquivalent: "a")
        main.addItem(withTitle: "Edit", action: nil, keyEquivalent: "").submenu = editMenu

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        main.addItem(withTitle: "Window", action: nil, keyEquivalent: "").submenu = windowMenu

        return main
    }

    // MARK: LocalProcessTerminalViewDelegate

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        // On failure (e.g. "command not found: herdr"), keep the window up so the error stays readable.
        guard exitCode == 0 else {
            window.title = "Herdr — exited with an error"
            return
        }
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
