# ASURL2SE

[English](README.md) | 日本語

`applescript:` のURLを受け取って、Script Editor の新規書類にしてくれるだけの、小さな macOS アプリ。

- バージョン: 0.1de
- バンドルID: `com.cocolog-nifty.quicktimer.ASURL2SE`
- ビルドすると `ASURL2SE.app` ができる
- ライセンス: CC0 1.0(パブリックドメイン)

---

## ⚠️ このアプリは Claude が作りました

**ソースコードも、この README も、AI の Claude(Anthropic)が書いたものです。**
作者(人間)は、仕様を決めて、実機で動作確認をして、バグ報告をしました。コードを書いたのは Claude です(作者が出したのは、仕様の案と、AppleScript の下書きくらいです)。

- 作成時のセッション設定のモデルID: `claude-sonnet-5-5`(実際に応答したモデルは、違う可能性があります)
- Claude は、このアプリをビルドも実行もできない環境でコードを書きました。動作確認は、すべて作者の Mac での手作業です。
- なので、バグがあるかもしれません。使うときは、自己責任でお願いします。

---

## なんのためのアプリ?

作者の環境では、macOS 27 の Script Editor が `applescript:` スキームのURLを受け取らなくなりました(作者が確認した範囲の話です)。
Chromium 系のブラウザも、このURLを外に渡さなくなっています(こちらも作者が確認済み)。

Web ページに「Script Editor で開く」リンクがあっても、そのままでは開けないので、
**代わりにURLを受け取って、中身のスクリプトを Script Editor の新規書類に入れる**のが、このアプリの仕事です。

この仕様の変更自体は、ClickFix 詐欺のような手口を防ぐためのものだと、作者は理解していて、反対ではありません。
このアプリは、「内容を見て、自分で判断して、自分で実行する」ための、自分用の道具です。

## できること

| きっかけ | 動き |
|---|---|
| ブラウザで `applescript:` のリンクをクリック | URLをデコードして、Script Editor に新規書類を作る |
| `.inetloc` ファイルをダブルクリック(Finder 経由) | 同上 |
| `.inetloc` をアプリのアイコンにドロップ | 同上 |
| クリップボードに `applescript:` のURLがある状態でアプリを起動 | 同上 |
| クリップボードに普通のテキストがある状態でアプリを起動 | そのテキストを、Script Editor の新規書類に入れる(AppleScript でなくても OK) |
| クリップボードが空の状態でアプリを起動 | 設定画面が開く |
| Option キーを押しながらアプリを起動 | 設定画面が開く |
| すでに起動中に Dock のアイコンをクリック | 上の「起動」と同じ動き |
| メニューの「設定…」(⌘,) | 設定画面が開く |

- 処理が終わってから **60秒後に自動で終了**します。設定画面を開いている間は、終了しません。閉じると、60秒を数え直します。
- 動作確認をしたのは、Safari でのクリックと、`.inetloc` のダブルクリックとドロップです。Firefox や Arc などは、まだ試していません。

### 設定画面でできること

- `applescript:` URL の送信先(既定のアプリ)の変更。一覧には、このアプリのほかに、`applescript:` を受け取れるアプリが出ます。
- 「開く前に内容を確認する」かどうかの切り替え(URLで届いたとき / クリップボードから開くとき)。初期値は、どちらも「確認しない」です。
- 設定は `UserDefaults` に保存されます。初期値に戻すときは、`defaults delete com.cocolog-nifty.quicktimer.ASURL2SE` を実行してください。

## 安全面のこと

- **スクリプトは、実行しません。保存もしません。** Script Editor の新規書類に、テキストとして入れるだけです。実行するかどうかは、中身を見て、自分で決めます。
- URLの `action` / `name` / `directory` / `appid` は、無視します。`insert` / `append` も、常に「新規書類」として扱います。保存先やファイル名を、受信した値で決めないためです。
- 受信したテキストは、AppleScript のソースに文字列として埋め込まず、`osascript` の引数(データ)として渡しています。
- **確認ダイアログは、初期値で「出さない」にしています。** 自分専用だからです。ほかの人が使う場合や、Web のリンクを、よく見ないでクリックしてしまう人は、設定画面で「確認する」をオンにしておいてください。

## 表示言語

画面に出る文字(メニュー、ダイアログ、設定画面)は、macOS の優先言語(システム設定 → 一般 → 言語と地域 のいちばん上)が日本語なら日本語、それ以外は英語になります。

このアプリだけ言語を変えて試すときは、Terminal で次を実行して、アプリを起動し直してください。

```
defaults write com.cocolog-nifty.quicktimer.ASURL2SE AppleLanguages '("en")'
```

元に戻すときは、`defaults delete com.cocolog-nifty.quicktimer.ASURL2SE AppleLanguages` を実行します。

## 動作環境

- macOS 27 以降(Apple Silicon のみ。Intel は考えていません)
- ビルドには Xcode が必要です。

## ビルド方法

1. このリポジトリの Xcode プロジェクトを開く
2. Signing は **Sign to Run Locally**(ad-hoc 署名)のまま、`⌘R` で実行する
3. できた `ASURL2SE.app` を `/Applications` に置いて、設定画面で、送信先をそのアプリに向ける

Apple Developer Program への登録は、いりません。自分の Mac でビルドして使う前提です。

### Xcode プロジェクトの設定メモ(一から作り直す場合)

- テンプレートは macOS → App(Swift / Storyboard)。作成後、`Main.storyboard`、`ViewController.swift`、テンプレートの `AppDelegate.swift` を削除し、Build Settings の「Main storyboard file base name」を空にする。
- **App Sandbox は、無効にする。** 有効のままだと、`osascript` から Script Editor への Apple Event が通りません(`-600` のエラーになりました)。
- Info タブ → URL Types に、URL Schemes `applescript`、Role `Viewer` を追加する。
- Info タブに `Privacy - AppleEvents Sending Usage Description`(`NSAppleEventsUsageDescription`)を追加する。値は、日英を併記しておくと、どちらの言語でも読めます。(例: `Script Editor に新規書類を作成するために使用します。 / Used to create a new document in Script Editor.`)
- Architectures は `arm64`。
- テンプレートに iOS 関連の SDK のリンクが入っていたら、外しておく。(作者の環境では、Sandbox を切るのと同時に外したので、どちらが効いたのかは、はっきりしません。)

### 初回に出る許可ダイアログ

- 初めて Script Editor を操作するときに、Automation(Apple Event)の許可ダイアログが出ます。
- クリップボードを読むときにも、許可の確認が出ることがあります(作者の環境では、初回だけ出ました)。

## ソースの構成

| ファイル | 役割 |
|---|---|
| `main.swift` | アプリの起動 |
| `AppDelegate.swift` | URLの受信、クリップボードの判定、URLの分解とデコード、メニュー、60秒の自動終了 |
| `ScriptEditorBridge.swift` | `osascript` で Script Editor に新規書類を作る(タイムアウト付き) |
| `SettingsWindowController.swift` | 設定画面と、設定の保存 |
| `L10n.swift` | 画面に出る文字列の、日本語と英語の切り替え |

URLのデコードは、`URLComponents` を使わずに、自前で書いています。Safari の「リンクのアドレスをコピー」は、日本語の部分を読める形に戻してコピーするので、`%XX` と生の日本語が混ざったURLができます。このURLを `URLComponents` に解析させると、`%` が再エンコードされて、デコードされない `%0D` や `%20` が残ることがありました。

## 既知の注意点

- 動作確認は、作者の Mac(macOS 27)でしかしていません。ほかの環境では、動く保証がありません。
- Script Editor が未起動のとき、起動時にファイルを開くダイアログが出ることがあります(ターミナルから起動したときに、出るのを確認しました)。
- Chromium 系のブラウザは、`applescript:` のURLを外に渡さないので、リンクを「リンクのアドレスをコピー」してから、このアプリを起動してください。

## ライセンス

[CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/deed.ja)。
著作権などの権利を、可能な範囲で放棄しています。コピーでも、改変でも、再配布でも、商用利用でも、断りなく、自由にどうぞ。無保証です。

(コードは AI が生成したものなので、法的な扱いは、国によって違うかもしれません。作者は、法律の専門家ではありません。)
