import AppKit

// ステップ4: 設定画面と、60秒後の自動終了を追加。
// - A   : applescript: URL を受信 → script を取り出して Script Editor の新規書類に入れる
// - B-1 : 起動時、クリップボードが applescript: URL → Aと同じ処理
// - B-2 : 起動時、クリップボードが普通のテキスト → そのまま新規書類に入れる
// - 起動済みのときにDockアイコンをクリックした場合も、新規に起動したときと同じ(B-1 / B-2 / 設定画面)
//   ただし、設定画面が開いている間は、Dockのクリックで設定画面を前面に出すだけにする。
// - 設定画面が開く場合: Optionキーを押して起動 / クリップボードが空 / メニューの「設定…」
// - 処理が終わってから60秒後に自動終了する。設定画面が開いている間は数えない。
// スクリプトの実行・保存は一切行わない。

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// 処理が終わってから、自動終了するまでの時間。
    /// 動作確認のときは、短くしてもよい(例: .seconds(10))。
    private let autoQuitDelay: Duration = .seconds(60)

    /// URLイベントを受信済みか。起動直後に「URLで起動されたのか、ユーザーが起動したのか」を見分けるために使う。
    private var urlEventReceived = false

    // 自動終了の管理。処理中や設定画面の表示中は「活動中」とみなして、カウントしない。
    private var activityCount = 0
    private var autoQuitTask: Task<Void, Never>?

    // 設定画面
    private var settingsController: SettingsWindowController?
    private var settingsIsOpen = false

    // MARK: - ライフサイクル

    func applicationWillFinishLaunching(_ notification: Notification) {
        Preferences.registerDefaults()
        NSApp.mainMenu = makeMainMenu()

        // URL受信(Appleイベント)。起動直後に届くイベントを取りこぼさないよう、ここで登録する。
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Optionキーは、離される前に、起動直後の状態を記録しておく。
        let optionPressed = NSEvent.modifierFlags.contains(.option)

        // URLイベントが届くのを少し待つ。届いていれば、ユーザーによる起動ではない(トリガA)。
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !self.urlEventReceived else { return }
            await self.handleUserLaunch(optionPressed: optionPressed)
        }
    }

    /// Dockアイコンのクリックなどで、起動済みのアプリに届く再オープンイベント。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 設定画面が開いている間は、前面に出すだけにする。
        if settingsIsOpen {
            showSettings(nil)
            return false
        }

        // それ以外は、新規に起動したときと同じ処理にする。
        // (Optionキー → 設定画面 / クリップボードが空 → 設定画面 / URLやテキスト → 新規書類)
        let optionPressed = NSEvent.modifierFlags.contains(.option)
        Task {
            await self.handleUserLaunch(optionPressed: optionPressed)
        }
        return false
    }

    // MARK: - 自動終了

    private func beginActivity() {
        activityCount += 1
        autoQuitTask?.cancel()
        autoQuitTask = nil
    }

    private func endActivity() {
        activityCount = max(0, activityCount - 1)
        if activityCount == 0 {
            scheduleAutoQuit()
        }
    }

    private func scheduleAutoQuit() {
        autoQuitTask?.cancel()
        autoQuitTask = Task {
            try? await Task.sleep(for: self.autoQuitDelay)
            guard !Task.isCancelled, self.activityCount == 0 else { return }
            NSApp.terminate(nil)
        }
    }

    // MARK: - 設定画面

    @objc func showSettings(_ sender: Any?) {
        let controller: SettingsWindowController
        if let existing = settingsController {
            controller = existing
        } else {
            controller = SettingsWindowController()
            controller.onClose = { [weak self] in
                guard let self else { return }
                self.settingsIsOpen = false
                self.endActivity()
            }
            settingsController = controller
        }

        // 開いている間は、自動終了のカウントを止める。
        if !settingsIsOpen {
            settingsIsOpen = true
            beginActivity()
        }
        controller.show()
    }

    // MARK: - トリガA(URL受信)

    @objc func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        urlEventReceived = true

        let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue ?? ""

        // 送信元は記録だけする('spid' = keySenderPIDAttr)。判定には使わない。
        var sender = "不明"
        let keySenderPID: AEKeyword = 0x7370_6964
        if let pidDescriptor = event.attributeDescriptor(forKeyword: keySenderPID) {
            let pid = pidDescriptor.int32Value
            let name = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "?"
            sender = "\(name) (pid \(pid))"
        }
        NSLog("URL受信: 送信元=%@ 文字数=%d", sender, urlString.count)

        // 処理が終わるまでは、自動終了のカウントを止める。
        beginActivity()

        // Appleイベントのハンドラは速やかに戻し、以降は次のターンで行う。
        Task {
            await self.openFromURL(urlString, confirm: Preferences.confirmForURLTrigger)
            self.endActivity()
        }
    }

    // MARK: - トリガB(ユーザーによる起動)

    private func handleUserLaunch(optionPressed: Bool) async {
        beginActivity()
        defer { endActivity() }

        if optionPressed {
            showSettings(nil)
            return
        }

        guard let text = readClipboardText() else {
            showSettings(nil)
            return
        }

        // 前後の空白や改行を取り除いて判定する(「リンクをコピー」で末尾に改行が付くことがあるため)。
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            showSettings(nil)
            return
        }

        let confirm = Preferences.confirmForClipboardTrigger
        if trimmed.lowercased().hasPrefix("applescript:") {
            // B-1: クリップボードが applescript: URL
            await openFromURL(trimmed, confirm: confirm)
        } else {
            // B-2: 普通のテキスト。AppleScriptでなくても、そのまま新規書類に入れる。
            await openDocument(script: text, confirm: confirm)
        }
    }

    /// クリップボードの文字列を返す。テキストがなければ nil。
    /// 先に種類だけを調べ、中身の読み取りは、テキストがあるときだけ行う。
    private func readClipboardText() -> String? {
        let pasteboard = NSPasteboard.general
        guard pasteboard.availableType(from: [.string]) != nil else { return nil }
        return pasteboard.string(forType: .string)
    }

    // MARK: - 処理A(URLからscriptを取り出して開く)

    private func openFromURL(_ urlString: String, confirm: Bool) async {
        switch extractScript(from: urlString) {
        case .success(let script):
            await openDocument(script: script, confirm: confirm)
        case .failure(let problem):
            presentText(
                title: "URLを処理できませんでした",
                info: problem.message,
                body: truncated(urlString),
                buttons: ["閉じる"]
            )
        }
    }

    /// applescript: URL から script の値を取り出す。
    /// action(new / insert / append)は区別せず、常に新規書類として扱う。
    /// directory / appid / name は使わない(保存先やファイル名を受信値で決めないため)。
    ///
    /// URLComponents は使わず、自前で分解する。
    /// Safariの「リンクのアドレスをコピー」は、日本語の部分を読める形に戻して(%E6… → 日本語)コピーする。
    /// そのようなURLをFoundationに解析させると、%が再エンコードされて、デコード結果が %0D や %20 のまま残ることがあった。
    private func extractScript(from urlString: String) -> Result<String, URLProblem> {
        // スキーム(最初の ":" の前)を確認する。
        guard let colon = urlString.firstIndex(of: ":") else {
            return .failure(URLProblem(message: "URLとして解析できませんでした。(\":\" がありません)"))
        }
        let scheme = urlString[..<colon].lowercased()
        guard scheme == "applescript" else {
            return .failure(URLProblem(message: "applescript: 以外のURLは扱いません。(scheme: \(scheme))"))
        }

        // クエリ("?" から "#" の手前まで)を取り出す。
        var rest = urlString[urlString.index(after: colon)...]
        if let hash = rest.firstIndex(of: "#") {
            rest = rest[..<hash]
        }
        guard let question = rest.firstIndex(of: "?") else {
            return .success("")
        }
        let query = rest[rest.index(after: question)...]

        // "&" で区切って、最初の script=… を探す。
        for pair in query.split(separator: "&", omittingEmptySubsequences: true) {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2, parts[0] == "script" {
                return .success(percentDecode(String(parts[1])))
            }
        }
        return .success("")
    }

    /// %XX だけをバイト値に戻す。それ以外の文字(日本語など)はそのまま残す。
    /// "+" は空白に変換しない(AppleScriptの足し算などを壊さないため)。
    private func percentDecode(_ text: String) -> String {
        let input = Array(text.utf8)
        var output: [UInt8] = []
        output.reserveCapacity(input.count)

        var index = 0
        while index < input.count {
            let byte = input[index]
            if byte == 0x25, index + 2 < input.count,
               let high = hexValue(input[index + 1]),
               let low = hexValue(input[index + 2]) {
                output.append(high * 16 + low)
                index += 3
            } else {
                output.append(byte)
                index += 1
            }
        }
        return String(decoding: output, as: UTF8.self)
    }

    private func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 0x30...0x39: return byte - 0x30         // 0-9
        case 0x41...0x46: return byte - 0x41 + 10    // A-F
        case 0x61...0x66: return byte - 0x61 + 10    // a-f
        default: return nil
        }
    }

    // MARK: - 処理(Script Editorで新規書類を開く)

    private func openDocument(script: String, confirm: Bool) async {
        if confirm {
            let info = script.isEmpty
                ? "スクリプトの指定がありません。空の新規書類を開きます。"
                : "下のテキストを、Script Editor の新規書類として開きます。実行はしません。内容を確認してください。"
            let pressed = presentText(
                title: "Script Editor で開きますか?",
                info: info,
                body: script,
                buttons: ["開く", "キャンセル"]
            )
            guard pressed == 0 else { return }
        }

        do {
            try await ScriptEditorBridge.openNewDocument(text: script)
        } catch {
            presentText(
                title: "Script Editor で新規書類を作れませんでした",
                info: "",
                body: truncated("\(error)"),
                buttons: ["閉じる"]
            )
        }
    }

    // MARK: - 表示

    /// 長すぎる文字列を切り詰める(エラー表示専用。確認ダイアログでは切り詰めない)。
    private func truncated(_ s: String, limit: Int = 4000) -> String {
        s.count <= limit ? s : String(s.prefix(limit)) + "\n…(以降省略)"
    }

    /// 本文をスクロール付きで表示するアラート。押されたボタンの番号(0始まり)を返す。
    @discardableResult
    private func presentText(title: String, info: String, body: String, buttons: [String]) -> Int {
        NSApp.activate()

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 520, height: 280))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        let text = NSTextView(frame: NSRect(origin: .zero, size: scroll.contentSize))
        text.isEditable = false
        text.isSelectable = true
        text.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        text.string = body
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.minSize = NSSize(width: 0, height: scroll.contentSize.height)
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        text.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        text.textContainer?.widthTracksTextView = true
        scroll.documentView = text

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        alert.accessoryView = scroll
        for button in buttons {
            alert.addButton(withTitle: button)
        }

        let response = alert.runModal()
        return response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
    }

    // MARK: - メニュー

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        // アプリメニュー(アバウトと設定)
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        let appName = ProcessInfo.processInfo.processName
        appMenu.addItem(
            withTitle: "\(appName)について",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "設定…", action: #selector(showSettings(_:)), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)

        // ファイルメニュー(終了)
        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "ファイル")
        fileItem.submenu = fileMenu
        fileMenu.addItem(
            withTitle: "終了",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        return mainMenu
    }
}

/// URLを処理できなかった理由(画面に表示する)。
nonisolated struct URLProblem: Error, Sendable {
    let message: String
}
