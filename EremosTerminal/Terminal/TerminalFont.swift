import AppKit
import CoreText

/// The terminal's font: JetBrains Mono, shipped inside the app (Resources/Fonts, SIL Open Font License —
/// see JetBrainsMono-OFL.txt next to the files). Registered for this process only: nothing is installed into
/// the system, other apps don't see it.
@MainActor
enum TerminalFont {
    static let size: CGFloat = 13
    private static var registered = false

    /// JetBrains Mono at the terminal size, or the system monospaced font if the files are missing.
    /// The bold and italic files are registered too: the terminal asks for them by family for `\e[1m` / `\e[3m`.
    static var font: NSFont {
        registerBundledFonts()
        return NSFont(name: "JetBrainsMono-Regular", size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    /// Like `@font-face` in CSS, but done once from code: every .ttf in the app's resources.
    static func registerBundledFonts() {
        guard !registered else { return }
        registered = true
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                NSLog("Eremos Terminal: can't load font %@: %@", url.lastPathComponent,
                      String(describing: error?.takeRetainedValue()))
            }
        }
    }
}
