import Foundation

// 画面に出る文字列を、日本語と英語で切り替える。
// macOS の優先言語(システム設定 → 一般 → 言語と地域 のいちばん上)が日本語なら日本語、それ以外は英語。
//
// このアプリだけ言語を変えて試すときは、Terminal で次を実行して、アプリを起動し直す。
//   defaults write com.cocolog-nifty.quicktimer.ASURL2SE AppleLanguages '("en")'
// 元に戻すときは、次を実行する。
//   defaults delete com.cocolog-nifty.quicktimer.ASURL2SE AppleLanguages

nonisolated enum L10n {

    /// 優先言語が日本語か。
    static let isJapanese: Bool = {
        guard let first = Locale.preferredLanguages.first else { return false }
        return first.hasPrefix("ja")
    }()

    /// 日本語の環境なら ja を、それ以外なら en を返す。
    static func t(ja: String, en: String) -> String {
        isJapanese ? ja : en
    }

    /// 何度も使う語。
    static var close: String {
        t(ja: "閉じる", en: "Close")
    }
}
