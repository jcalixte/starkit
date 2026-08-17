import Foundation
import StarkitCore

/// One of a child process's pipes, read to EOF somewhere other than here.
///
/// Reading a pipe on the thread that waits for the child hands it the deadline: a **Script** that
/// hangs never closes its stdout, and neither does a compiler that never finishes. Draining every
/// pipe concurrently also stops one deadlocking the other by filling its 64 KB buffer while the
/// wrong one is being read.
final class Drain {
    /// Written by the queue `drain` starts and read after `DispatchGroup.wait` has returned, which is
    /// the whole of the synchronisation: one writer, and no reader until it has finished.
    private(set) var data = Data()

    /// The bytes as a sentence, or `nil` when there is nothing to say — "nothing" and "an empty
    /// string" read differently at the other end.
    ///
    /// Colour comes off here because neither tool can be talked out of writing it: `gleam` puts
    /// escapes in a compile error even when its output is a pipe, and ADR 0003 records bun ignoring
    /// `NO_COLOR` the same way. A stack trace reaching the menu bar must not be wearing them.
    var text: String? {
        let text = String(decoding: data, as: UTF8.self)
            .withoutTerminalColour
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// Start reading, and join `group` so the caller can wait for the read rather than for the child.
    func drain(_ pipe: Pipe, in group: DispatchGroup) {
        DispatchQueue.global().async(group: group) {
            self.data = pipe.fileHandleForReading.readDataToEndOfFile()
        }
    }
}
