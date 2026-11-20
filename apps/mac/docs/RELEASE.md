# リリースの手順

以下のパスとコマンドは `apps/mac/` を基準にする。リリースのコマンドはルートから pnpm で実行する（`pnpm release:mac 0.1.0` など）。

akapen は Developer ID で署名・公証した zip を GitHub Releases（`yuto343/akapen`）で配り、Homebrew の自前の tap（`yuto343/homebrew-tap`）からも入れられるようにする。入れたあとの更新はアプリ内の Sparkle が受け持つ（メニューバーの「アップデートを確認…」と、裏での自動の確認）。

| 配るもの | 置き場 | 使う人 |
| --- | --- | --- |
| `akapen-<版>.zip`（`akapen.app` を `ditto -c -k --keepParent` で固めたもの） | GitHub Release `v<版>` の添付 | zip を落とす人、Homebrew、Sparkle |
| `akapen.zip`（上と同じ zip の、版の付かない名前の写し） | GitHub Release `v<版>` の添付。`https://github.com/yuto343/akapen/releases/latest/download/akapen.zip` で最新が取れる | LP の Download ボタン |
| `appcast.xml`（Sparkle の feed。EdDSA の署名つき） | GitHub Release `v<版>` の添付。`https://github.com/yuto343/akapen/releases/latest/download/appcast.xml` で最新が取れる | アプリ内の Sparkle（`SUFeedURL`）、Homebrew の `livecheck` |
| `Casks/akapen.rb`（Homebrew の cask） | `yuto343/homebrew-tap` | `brew install --cask yuto343/tap/akapen` |

## 一度だけやる準備

### 署名の証明書

ログインのキーチェーンに `Developer ID Application`（チーム G5564YSC93）の証明書がある（`security find-identity -v -p codesigning` で見える）。Debug のビルド（`make build`・`make run`・`make e2e`）は今まで通り `Apple Development` で署名し、Developer ID は Release のビルドだけが使う。

### 公証の資格情報

`pnpm release:mac` は、キーチェーンに保存した notarytool のプロファイル `akapen` を使う（環境変数 `AKAPEN_NOTARY_PROFILE=<名前>` で変えられる）。次のどちらかで一度だけ登録する。

```sh
# Apple ID と app 用パスワード（https://appleid.apple.com の「App 用パスワード」で作る。パスワードは対話で聞かれる）
xcrun notarytool store-credentials akapen --apple-id <Apple ID> --team-id G5564YSC93

# App Store Connect の API キー（「ユーザとアクセス」→「統合」で作る）
xcrun notarytool store-credentials akapen --key <AuthKey_XXXXXXXXXX.p8> --key-id <キー ID> --issuer <Issuer ID>
```

プロファイルがない・使えないと、`pnpm release:mac` はビルドを始める前に、この手順を出して止まる（黙って公証を飛ばさない）。

### Sparkle の鍵

更新の zip には EdDSA（ed25519）の署名を付け、アプリは `Info.plist` の `SUPublicEDKey` でそれを確かめる。鍵は 2026-11-20 に Sparkle 付属の `generate_keys` で作った。

- 秘密鍵: ログインのキーチェーンの「Private key for signing Sparkle updates」（サービス `https://sparkle-project.org`、アカウント `ed25519`）。ファイルには書き出していない。リポジトリにも入れない。
- 公開鍵: `5XC7cTfxEIa8bvb7ILslNRngx4a8juiJERtk1XxzlHo=`（`App/Info.plist` の `SUPublicEDKey`）。
- ツールの場所: `make build` のあとは `build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/`（`generate_keys`・`generate_appcast`・`sign_update`）。`make test` のあとは `Packages/AkapenKit/.build/artifacts/sparkle/Sparkle/bin/` にもある。
- 公開鍵の確かめ方: `generate_keys -p`。`pnpm release:mac` は、キーチェーンの鍵の公開鍵と `Info.plist` の `SUPublicEDKey` が違えば止まる。

**秘密鍵をなくすと、配ったアプリに更新を届けられなくなる**（配ったアプリは今の公開鍵でしか署名を確かめないため）。一度、安全な場所にバックアップを取る。

```sh
B=build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin
"$B/generate_keys" -x ~/Desktop/akapen-sparkle-private-key   # 書き出す
# パスワードマネージャーなどに中身を保管したら、書き出したファイルは消す
rm ~/Desktop/akapen-sparkle-private-key
```

別の Mac でリリースするときは、保管した鍵を `generate_keys -f <ファイル>` でその Mac のキーチェーンに取り込む。秘密鍵が漏れたときの鍵の入れ替えは、Sparkle の文書（EdDSA の鍵の rotation）に従う。

### GitHub のリポジトリ

1. このリポジトリを `yuto343/akapen` として GitHub に作り、**公開**する（Sparkle と Homebrew はログインなしで Release の添付を落とすため）。`main` を push する。
2. tap のリポジトリ `yuto343/homebrew-tap` を公開で作る（中身は空でよい。`Casks/akapen.rb` は `pnpm publish:mac` が置く）。
   ```sh
   gh repo create yuto343/homebrew-tap --public --description "Homebrew tap for akapen"
   ```
3. `gh auth login` で、両方のリポジトリに書ける状態にしておく。

## リリースのたび

### 1. 版を決める

版は `x.y.z`（数字 3 つ）。前の版より大きくする。Sparkle は `CFBundleVersion` で新旧を比べるので、`pnpm release:mac` は `MARKETING_VERSION`（`CFBundleShortVersionString`）と `CURRENT_PROJECT_VERSION`（`CFBundleVersion`）の両方を同じ値で上書きする。`project.yml` の `0.0.0` は手元のビルド用で、書き換えない。

### 2. 成果物を作る

`main` を push してから流す（`gh release create` は、タグがまだなければ GitHub 上の既定のブランチの先頭にタグを作る）。

```sh
pnpm release:mac 0.1.0
```

`build/release/0.1.0/` に揃うもの:

| ファイル | 中身 |
| --- | --- |
| `akapen-0.1.0.zip` | 署名・公証・staple 済みの `akapen.app` |
| `appcast.xml` | 1 項目だけの feed。enclosure は `https://github.com/yuto343/akapen/releases/download/v0.1.0/akapen-0.1.0.zip`、`sparkle:edSignature` つき |
| `akapen.rb` | `packaging/homebrew/akapen.rb.template` に版と zip の sha256 を埋めた cask |
| `work/` | 途中の生成物（`akapen.xcarchive`、`export/akapen.app`、公証の結果 `notarize.json`、appcast を作った作業場所） |

`scripts/release.sh` がすること（どこかで食い違えば、そこで止まる）:

1. `VERSION` の形、署名の証明書、公証のプロファイルを確かめる。
2. `xcodegen generate` → `xcodebuild archive`（Release。`Developer ID Application`・hardened runtime・`--timestamp`。arm64 と x86_64）→ `xcodebuild -exportArchive`（`packaging/ExportOptions.plist`。`method: developer-id`）。書き出しが、同梱の Sparkle.framework の中（`Autoupdate`・`Updater.app`・`Installer.xpc`・`Downloader.xpc`）まで同じ証明書で署名し直す。
3. 版・`SUFeedURL`・`SUPublicEDKey`（キーチェーンの鍵と一致するか）を確かめる。
4. `codesign --verify --deep --strict --verbose=2` と、中の Mach-O をすべて、Developer ID・チーム `G5564YSC93`・hardened runtime・タイムスタンプの 4 点で確かめる。
5. `xcrun notarytool submit --wait --keychain-profile akapen` で公証し、`xcrun stapler staple` で綴じる。`spctl -a -vvv -t exec` が `source=Notarized Developer ID` を返すことを確かめる。
6. zip にする → `generate_appcast` で appcast.xml を作る（キーチェーンの鍵で署名）→ `sign_update --verify` で zip と署名が合うことを確かめる → cask を作る。

ログは `build/logs/release-archive.log` と `build/logs/release-export.log`。

公証を飛ばして手元で確かめるだけなら `--skip-notarize` を付ける。Gatekeeper の判定は `source=Unnotarized Developer ID` で断られる（正しい）。この成果物は配布に使えず、`pnpm publish:mac` も断る。

```sh
pnpm release:mac 0.1.0 --skip-notarize
```

### 3. 確かめる

`pnpm release:mac` が確かめたことに加えて、必要なら手でも見る。

```sh
spctl -a -vvv -t exec build/release/0.1.0/work/export/akapen.app   # source=Notarized Developer ID
codesign --verify --deep --strict --verbose=2 build/release/0.1.0/work/export/akapen.app
cat build/release/0.1.0/appcast.xml build/release/0.1.0/akapen.rb
```

zip を展開した `akapen.app` を `/Applications` に置いて起動し、メニューバーの「アップデートを確認…」で Sparkle の画面が出ることを見る（公開前は feed がまだないので、確認に失敗した旨が出る）。

### 4. 公開する（ユーザーだけが走らせる）

```sh
pnpm publish:mac 0.1.0
```

`scripts/publish.sh` がすること:

1. 成果物が揃っているか、zip の中のアプリが公証済み（staple と Gatekeeper の判定）か、cask の sha256 が zip と合うか、`gh` にログインしているか、同じ版の Release がないかを確かめる。
2. `yuto343/homebrew-tap` を `build/release/0.1.0/work/homebrew-tap` に clone し、`Casks/akapen.rb` を差し替える。
3. 公開するもの（Release のタグと添付、tap の差分）を出して、`y` の確認を取る。`y` 以外なら何も公開せずに止まる。
4. `gh release create v0.1.0 --repo yuto343/akapen --generate-notes` で zip（`akapen-0.1.0.zip` と、同じ中身の `akapen.zip`）と appcast.xml を上げる。
5. tap の `Casks/akapen.rb` を commit して push する。

### 5. 公開したあと

- `brew install --cask yuto343/tap/akapen` で入ることを見る。
- 前の版のアプリで「アップデートを確認…」を選び、新しい版が出ることを見る。

## 使う人向けのインストール

### Homebrew

```sh
brew install --cask yuto343/tap/akapen
```

アプリが Sparkle で自分を更新する（cask の `auto_updates true`）。`brew upgrade` は、`--greedy` を付けたときだけ akapen を入れ直す。消すときは `brew uninstall --cask akapen`。設定・画像・Sparkle の記録まで消すなら `brew uninstall --zap --cask akapen`。

### zip

1. https://github.com/yuto343/akapen/releases/latest から `akapen-<版>.zip` を落とす。
2. 展開した `akapen.app` を `/Applications` に移して開く。
3. 初回のセットアップで、ホットキーを決め、画面収録を許可する。

更新は、メニューバーの akapen のアイコン →「アップデートを確認…」。裏でも 1 日に 1 回確かめる。

## 決めたこと・仕組みのメモ

- 配布物は zip だけ（dmg は作らない）。Mac App Store と本家の homebrew-cask には出さない。
- Release のビルドは `AKAPEN_*` の環境変数を読まない（`LaunchConfiguration.readsTestVariables` が false）。`AKAPEN_E2E=1` を付けて起動しても本番として動く。Debug（`make run`・`make e2e`・`swift test`）は今まで通り読む。
- Sparkle は 2.10.1（Swift Package。`Packages/AkapenKit/Package.swift` で版を固定）。`SUEnableAutomaticChecks = YES` なので「自動で確認しますか？」の初回のダイアログは出さない。更新の画面は Sparkle の標準のまま。
- appcast は最新の 1 項目だけを持つ（毎回作り直す）。差分の更新（delta）は作らない。
- `xcodebuild -exportArchive` はビルドをしないので、`-derivedDataPath` を付けると xcodebuild が拒む（付けずに呼ぶ。生成物は `-exportPath` の `build/release/<版>/work/export/` に出る）。
- 公証・公開の資格情報（Apple ID・app 用パスワード・API キー・GitHub のトークン）はリポジトリに置かない。GitHub Actions での自動のリリースは置いていない（秘密情報が要るため）。
