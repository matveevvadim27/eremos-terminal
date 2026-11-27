import SwiftTerm
import XCTest
@testable import Eremos_Terminal

/// The terminal sits inside the padding, follows the host's size and shows whole rows only.
@MainActor
final class TerminalHostViewTests: XCTestCase {
    func testTerminalFollowsHostSizeWithWholeRowsPinnedToTop() {
        let host = TerminalHostView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let terminal = LocalProcessTerminalView(frame: .zero) // no process needed for layout
        host.show(terminal)

        assertFits(terminal, in: host)
        let rowsBefore = terminal.getTerminal().rows

        host.setFrameSize(NSSize(width: 500, height: 333))
        assertFits(terminal, in: host)
        XCTAssertLessThan(terminal.getTerminal().rows, rowsBefore, "rows follow the smaller host")
    }

    private func assertFits(_ terminal: LocalProcessTerminalView, in host: TerminalHostView,
                            file: StaticString = #filePath, line: UInt = #line) {
        let frame = terminal.frame
        XCTAssertTrue(host.bounds.contains(frame), "inside the host", file: file, line: line)
        // Pinned to the top: only the padding above it.
        XCTAssertEqual(host.bounds.maxY - frame.maxY, TerminalHostView.inset.top, accuracy: 0.5, file: file, line: line)
        // A whole number of rows: the height is exactly what those rows need.
        XCTAssertEqual(frame.height, terminal.getOptimalFrameSize().height, accuracy: 0.5, file: file, line: line)
    }
}
