import Darwin
import Foundation

/// Ends a session's shell together with everything started from it (claude, its node workers, dev servers…).
///
/// SwiftTerm's `terminate()` sends SIGTERM to the shell only, and an interactive zsh ignores SIGTERM, so
/// `claude` used to outlive its closed session. This does what Terminal.app does when a tab is closed:
/// SIGHUP to every process, then SIGKILL for whatever is still alive a moment later.
enum ProcessTree {
    static func hangUp(root pid: pid_t, graceSeconds: Double = 2) {
        guard pid > 0 else { return }
        // Children first, so the shell doesn't get to respawn or re-parent anything in between.
        let pids = descendants(of: pid).reversed() + [pid]
        for p in pids { kill(p, SIGHUP) }
        DispatchQueue.global().asyncAfter(deadline: .now() + graceSeconds) {
            for p in pids where kill(p, 0) == 0 { kill(p, SIGKILL) }
        }
    }

    /// All processes below `pid`, breadth-first.
    static func descendants(of pid: pid_t) -> [pid_t] {
        var result: [pid_t] = []
        var queue = [pid]
        while !queue.isEmpty {
            let children = childPIDs(of: queue.removeFirst())
            result += children
            queue += children
        }
        return result
    }

    private static func childPIDs(of pid: pid_t) -> [pid_t] {
        var buffer = [pid_t](repeating: 0, count: 256)
        let bytes = proc_listchildpids(pid, &buffer, Int32(buffer.count * MemoryLayout<pid_t>.size))
        guard bytes > 0 else { return [] }
        // Depending on the macOS version the result is a count or a byte size; both are capped by the buffer.
        let count = min(Int(bytes), buffer.count)
        return buffer.prefix(count).filter { $0 > 0 }
    }
}
