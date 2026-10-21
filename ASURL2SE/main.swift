import AppKit

// ストーリーボードを使わず、コードでアプリを起動する。
// main.swift のトップレベルはメインスレッドで実行されるので、
// MainActor.assumeIsolated で「メインアクター上」であることをコンパイラに伝える。
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate               // NSApplication.delegate は weak
    app.setActivationPolicy(.regular)     // Dockに表示する(固まったときに強制終了できるように)

    // app.run() が終わるまで delegate を解放させない(ARCによる早期解放の防止)。
    withExtendedLifetime(delegate) {
        app.run()
    }
}
