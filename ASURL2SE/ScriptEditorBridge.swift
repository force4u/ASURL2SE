import Foundation

// Script Editor に新規書類を作り、テキストを入れる。
//
// 安全上の方針:
// - 受信したテキストを AppleScript のソースに文字列連結で埋め込まない。
//   呼び出し側のスクリプトは固定文で、受信テキストは osascript の引数(データ)として渡す。
// - 書類を開くだけで、実行(run)も保存もしない。
// - osascript は別プロセスで起動し、タイムアウトで打ち切る(UIが固まらない)。

nonisolated enum ScriptEditorBridge {

    struct BridgeError: Error, CustomStringConvertible, Sendable {
        let description: String
    }

    /// 固定のAppleScript。受信テキストは argv の2番目で受け取る。
    /// (1番目はダミー。引数がハイフンで始まっても osascript のオプションと誤解されないようにするため)
    private static let runnerScript = """
    on run argv
        set scriptText to item 2 of argv
        tell application id "com.apple.ScriptEditor2"
            activate
            make new document with properties {text:scriptText}
        end tell
    end run
    """

    /// 初回はAutomationの許可ダイアログで待たされるので、タイムアウトは長めにしてある。
    static func openNewDocument(text: String, timeout: TimeInterval = 90) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try runSynchronously(text: text, timeout: timeout)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func runSynchronously(text: String, timeout: TimeInterval) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", runnerScript, "document", text]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice

        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }

        try process.run()

        if finished.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            throw BridgeError(description: "osascript が \(Int(timeout)) 秒以内に終わりませんでした。許可ダイアログが出ていないか確認してください。")
        }

        if process.terminationStatus != 0 {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw BridgeError(description: "osascript が失敗しました(終了コード \(process.terminationStatus))\n\(message)")
        }
    }
}
