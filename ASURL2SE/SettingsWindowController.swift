import AppKit

// 設定画面。
// - applescript: URL の送信先(既定のアプリ)を変更する
// - 開く前の確認ダイアログを出すかどうかを切り替える
//
// 画面に出る文字列は、L10n.t(ja:en:) で日本語と英語を切り替える(macOSの言語設定に従う)。

// MARK: - 保存される設定

enum Preferences {
    static let confirmForURLTriggerKey = "confirmForURLTrigger"
    static let confirmForClipboardTriggerKey = "confirmForClipboardTrigger"

    /// 初期値。起動時に1回登録する。
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            confirmForURLTriggerKey: false,        // URLで届いたとき(トリガA): 確認しない
            confirmForClipboardTriggerKey: false,  // クリップボードから(トリガB): 確認しない
        ])
    }

    static var confirmForURLTrigger: Bool {
        get { UserDefaults.standard.bool(forKey: confirmForURLTriggerKey) }
        set { UserDefaults.standard.set(newValue, forKey: confirmForURLTriggerKey) }
    }

    static var confirmForClipboardTrigger: Bool {
        get { UserDefaults.standard.bool(forKey: confirmForClipboardTriggerKey) }
        set { UserDefaults.standard.set(newValue, forKey: confirmForClipboardTriggerKey) }
    }
}

// MARK: - 設定画面

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {

    /// 設定画面が閉じられたときに呼ばれる(自動終了のカウントを再開するために使う)。
    var onClose: (() -> Void)?

    private let window: NSWindow
    private var hasBeenShown = false

    private let popup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let applyButton = NSButton(
        title: L10n.t(ja: "この送信先に変更", en: "Set as Destination"),
        target: nil,
        action: nil
    )
    private let currentLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let confirmURLCheckbox = NSButton(
        checkboxWithTitle: L10n.t(
            ja: "URLで届いたスクリプトは、開く前に内容を確認する",
            en: "Review scripts received via URL before opening them"
        ),
        target: nil,
        action: nil
    )
    private let confirmClipboardCheckbox = NSButton(
        checkboxWithTitle: L10n.t(
            ja: "クリップボードから開くときも、開く前に内容を確認する",
            en: "Review clipboard text before opening it, too"
        ),
        target: nil,
        action: nil
    )

    /// 送信先の一覧を作るときに使う、applescript: のURL(中身はなんでもよい)。
    private let probeURL = URL(string: "applescript://com.apple.scripteditor/")!

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 330),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.title = L10n.t(ja: "設定", en: "Settings")
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = buildContentView()
        refresh()
    }

    /// 設定画面を表示する(すでに開いていれば、前面に出す)。
    func show() {
        refresh()   // 他のアプリで変更された場合に備えて、最新の状態にする
        NSApp.activate()
        if !hasBeenShown {
            window.center()
            hasBeenShown = true
        }
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    // MARK: - 画面の組み立て

    private func buildContentView() -> NSView {
        let container = NSView()

        let heading = NSTextField(labelWithString: L10n.t(
            ja: "applescript: URL の送信先",
            en: "Destination for applescript: URLs"
        ))
        heading.font = NSFont.boldSystemFont(ofSize: 13)

        currentLabel.lineBreakMode = .byTruncatingMiddle

        popup.widthAnchor.constraint(equalToConstant: 380).isActive = true
        applyButton.target = self
        applyButton.action = #selector(applyDestination(_:))
        let row = NSStackView(views: [popup, applyButton])
        row.orientation = .horizontal
        row.spacing = 8

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.preferredMaxLayoutWidth = 520

        let separator = NSBox()
        separator.boxType = .separator

        confirmURLCheckbox.target = self
        confirmURLCheckbox.action = #selector(toggleConfirmURL(_:))
        confirmClipboardCheckbox.target = self
        confirmClipboardCheckbox.action = #selector(toggleConfirmClipboard(_:))

        let note = NSTextField(wrappingLabelWithString: L10n.t(
            ja: "一覧には、applescript: のURLを受け取れるアプリが出ます。送信先の変更は、このアプリを終了したあとも有効です。"
                + "このアプリは、処理が終わってから60秒後に自動で終了します。この画面を開いている間は終了しません。",
            en: "The list shows apps that can receive applescript: URLs. The change stays in effect after you quit this app. "
                + "This app quits by itself 60 seconds after it finishes handling something, but not while this window is open."
        ))
        note.font = NSFont.systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.preferredMaxLayoutWidth = 520

        let stack = NSStackView(views: [
            heading, currentLabel, row, statusLabel, separator,
            confirmURLCheckbox, confirmClipboardCheckbox, note,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            currentLabel.widthAnchor.constraint(equalToConstant: 520),
            statusLabel.widthAnchor.constraint(equalToConstant: 520),
            separator.widthAnchor.constraint(equalToConstant: 520),
            note.widthAnchor.constraint(equalToConstant: 520),
        ])
        return container
    }

    // MARK: - 表示の更新

    private func refresh() {
        let workspace = NSWorkspace.shared
        let current = workspace.urlForApplication(toOpen: probeURL)
        let selfURL = Bundle.main.bundleURL

        // 候補: applescript: を受け取れるアプリ + このアプリ + 現在の送信先(重複は除く)
        var candidates = workspace.urlsForApplications(toOpen: probeURL)
        candidates.append(selfURL)
        if let current {
            candidates.append(current)
        }

        var seen = Set<String>()
        var apps: [URL] = []
        for url in candidates where seen.insert(url.standardizedFileURL.path).inserted {
            apps.append(url)
        }
        apps.sort { displayName(of: $0).localizedStandardCompare(displayName(of: $1)) == .orderedAscending }

        // ポップアップを作り直す。
        // (addItem(withTitle:) は同じ名前の項目を消してしまうので、NSMenuItem を直接追加する)
        popup.removeAllItems()
        var itemToSelect: NSMenuItem?
        for url in apps {
            var title = "\(displayName(of: url))  —  \(abbreviatedPath(of: url))"
            if url.standardizedFileURL.path == selfURL.standardizedFileURL.path {
                title += L10n.t(ja: "  [このアプリ]", en: "  [This app]")
            }
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.representedObject = url
            popup.menu?.addItem(item)

            if let current, url.standardizedFileURL.path == current.standardizedFileURL.path {
                itemToSelect = item
            }
        }
        if let itemToSelect {
            popup.select(itemToSelect)
        }

        if let current {
            let name = displayName(of: current)
            let path = abbreviatedPath(of: current)
            currentLabel.stringValue = L10n.t(
                ja: "現在の送信先: \(name)  (\(path))",
                en: "Current destination: \(name)  (\(path))"
            )
        } else {
            currentLabel.stringValue = L10n.t(
                ja: "現在の送信先: なし(受け取るアプリがありません)",
                en: "Current destination: none (no app can receive them)"
            )
        }

        confirmURLCheckbox.state = Preferences.confirmForURLTrigger ? .on : .off
        confirmClipboardCheckbox.state = Preferences.confirmForClipboardTrigger ? .on : .off
    }

    private func displayName(of url: URL) -> String {
        FileManager.default.displayName(atPath: url.path)
    }

    private func abbreviatedPath(of url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }

    // MARK: - 操作

    @objc private func applyDestination(_ sender: Any?) {
        guard let appURL = popup.selectedItem?.representedObject as? URL else { return }

        statusLabel.stringValue = L10n.t(ja: "変更しています…", en: "Changing…")
        applyButton.isEnabled = false

        Task {
            let error = await Self.setDefaultApplication(at: appURL)
            self.applyButton.isEnabled = true
            if let error {
                let message = error.localizedDescription
                self.statusLabel.stringValue = L10n.t(
                    ja: "変更できませんでした: \(message)",
                    en: "Couldn't change it: \(message)"
                )
            } else {
                self.statusLabel.stringValue = L10n.t(ja: "変更しました。", en: "Changed.")
            }
            self.refresh()
        }
    }

    /// applescript: スキームの既定のアプリを変更する。成功なら nil、失敗ならエラーを返す。
    /// 完了通知はメインスレッド以外で呼ばれる可能性があるので、@Sendable を明示して
    /// 「メインアクター上で呼ばれる前提」の実行時チェックが入らないようにしている。
    private static func setDefaultApplication(at appURL: URL) async -> Error? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Error?, Never>) in
            NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "applescript") { @Sendable error in
                continuation.resume(returning: error)
            }
        }
    }

    @objc private func toggleConfirmURL(_ sender: NSButton) {
        Preferences.confirmForURLTrigger = (sender.state == .on)
    }

    @objc private func toggleConfirmClipboard(_ sender: NSButton) {
        Preferences.confirmForClipboardTrigger = (sender.state == .on)
    }
}
