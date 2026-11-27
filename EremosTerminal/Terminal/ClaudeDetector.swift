import Darwin
import Foundation

/// Tells whether Claude Code is running somewhere inside a session's shell.
///
/// Checked by the command line, not the executable name: the native installer runs a versioned binary through the
/// `claude` symlink (the process is named like `2.1.332`), and the npm version runs as `node …/claude-code/cli.js`.
enum ClaudeDetector {
    static func isClaudeRunning(under shellPid: pid_t) -> Bool {
        ProcessTree.descendants(of: shellPid).contains { isClaude(arguments(of: $0)) }
    }

    static func isClaude(_ argv: [String]) -> Bool {
        guard let first = argv.first else { return false }
        if (first as NSString).lastPathComponent == "claude" { return true }
        return argv.prefix(3).contains { $0.contains("claude-code") || $0.hasSuffix("/bin/claude") }
    }

    /// The process's argv via sysctl(KERN_PROCARGS2): [argc: Int32][exec path\0…][argv[0]\0 argv[1]\0 …][env…].
    static func arguments(of pid: pid_t) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return [] }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return [] }

        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        var index = MemoryLayout<Int32>.size
        // Skip the executable path and the NUL padding after it.
        while index < size, buffer[index] != 0 { index += 1 }
        while index < size, buffer[index] == 0 { index += 1 }

        var args: [String] = []
        while args.count < argc, index < size {
            let start = index
            while index < size, buffer[index] != 0 { index += 1 }
            args.append(String(decoding: buffer[start..<index], as: UTF8.self))
            index += 1
        }
        return args
    }
}
