import Foundation
import Darwin

/// Thread-safe wrapper guaranteeing that a CheckedContinuation is resumed exactly once.
final class OnceResumer<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var hasResumed = false
    private let continuation: CheckedContinuation<T, Never>

    init(continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    func resume(returning value: T) {
        lock.lock()
        defer { lock.unlock() }
        guard !hasResumed else { return }
        hasResumed = true
        continuation.resume(returning: value)
    }
}

/// Centralized executor for AppleScript commands with pipe deadlock prevention,
/// two-stage timeout lifecycle (SIGTERM + SIGKILL), and guaranteed single continuation resumption.
public enum AppleScriptRunner {
    /// Executes an AppleScript via `/usr/bin/osascript` in a safe, non-blocking subprocess.
    ///
    /// - Parameters:
    ///   - script: The AppleScript source text to execute.
    ///   - timeout: Timeout in seconds before terminating the process (default: 2.0s).
    /// - Returns: Trimmed output string on success, or `nil` on failure or timeout.
    public static func run(script: String, timeout: TimeInterval = 2.0) async -> String? {
        await withCheckedContinuation { continuation in
            let resumer = OnceResumer(continuation: continuation)

            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]

                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                // Route stderr and stdin to nullDevice to prevent kernel pipe buffer deadlock
                process.standardError = FileHandle.nullDevice
                process.standardInput = FileHandle.nullDevice

                let timeoutWorkItem = DispatchWorkItem { [weak process] in
                    // Immediately resume caller with nil so caller never hangs
                    resumer.resume(returning: nil)

                    guard let p = process, p.isRunning else { return }
                    p.terminate() // Stage 1: SIGTERM

                    // Stage 2: SIGKILL fallback if process does not terminate within 500ms
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) { [weak process] in
                        guard let p = process, p.isRunning else { return }
                        let pid = p.processIdentifier
                        if pid > 0 {
                            _ = Darwin.kill(pid, SIGKILL)
                        }
                    }
                }

                DispatchQueue.global(qos: .userInitiated).asyncAfter(
                    deadline: .now() + timeout,
                    execute: timeoutWorkItem
                )

                do {
                    try process.run()
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    timeoutWorkItem.cancel()

                    guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !output.isEmpty else {
                        resumer.resume(returning: nil)
                        return
                    }
                    resumer.resume(returning: output)
                } catch {
                    timeoutWorkItem.cancel()
                    resumer.resume(returning: nil)
                }
            }
        }
    }
}
