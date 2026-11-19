# 公開までにやること

2026-11-20 時点。akapen 0.1.0 を初めて公開するまでのやることリスト。手順の詳しいところは `RELEASE.md` にある。
終わったら、このファイルは消してよい（毎回の手順は `RELEASE.md` に残る）。

## 済んでいること

- [x] Developer ID Application の証明書がキーチェーンにある
- [x] 公証のプロファイル `akapen` を登録した（2026-11-19 に公証が `Accepted` で通った）
- [x] Sparkle の EdDSA の鍵を作り、公開鍵を `App/Info.plist` に入れた
- [x] `pnpm release:mac` / `pnpm publish:mac` を用意した（`--skip-notarize` で成果物が揃うことを確かめた）

## 公開の前に

- [ ] **Sparkle の秘密鍵をバックアップする**（`RELEASE.md`「Sparkle の鍵」）。なくすと、配ったアプリに更新を届けられなくなる
- [ ] **メニューバーの E2E を流し直す**。普段使いの akapen を終了してから `make e2e ONLY=MenuBarSettingsTests` と `make e2e ONLY=MenuBarQuitTests`（同じバンドル ID の akapen が動いていると落ちる）
- [ ] **公開してよい中身かを見直す**。リポジトリを公開すると履歴もすべて見える。秘密情報・個人の情報が履歴に無いか、`.github/FUNDING.yml` と `apps/site/src/lib/site.ts` の仮の値をどうするか
- [ ] （任意）`make run` の開発ビルドにも Sparkle が入っている。版が `0.0.0` なので、0.1.0 を公開すると開発ビルドにも「アップデートがあります」が出る。気になるなら、Debug では Sparkle を止める

## GitHub の準備

- [ ] `yuto343/akapen` を**公開**で作り、remote に足して `main` を push する
  ```sh
  gh repo create yuto343/akapen --public --source . --push
  ```
- [ ] tap のリポジトリ `yuto343/homebrew-tap` を公開で作る（中身は空でよい）
  ```sh
  gh repo create yuto343/homebrew-tap --public --description "Homebrew tap for akapen"
  ```
- [ ] `gh auth status` で、両方に書ける状態か確かめる

## 0.1.0 を出す

- [ ] 成果物を作る（`--skip-notarize` なし。公証と staple まで通す）
  ```sh
  pnpm release:mac 0.1.0
  ```
- [ ] zip を展開した `akapen.app` を `/Applications` に置いて起動し、初回のセットアップ・撮影・コピーまで一通り動くことを見る
- [ ] 公開する。表示された中身を見てから `y` を押す
  ```sh
  pnpm publish:mac 0.1.0
  ```
  `pnpm publish`（`:mac` なし）は npm に公開する別のコマンドなので打ち間違えない

## 公開したあと

- [ ] `brew install --cask yuto343/tap/akapen` で入ることを見る（別の Mac か、いったん消してから）
- [ ] `https://github.com/yuto343/akapen/releases/latest/download/appcast.xml` が落とせることを見る
- [ ] 次の版（0.1.1 など）を出したときに、0.1.0 のアプリの「アップデートを確認…」で更新が届くことを見る

## LP

- [x] Download の節と、`brew install --cask yuto343/tap/akapen` をコピーできるターミナル風の枠（`apps/site`、4023f88）
- [ ] **LP のダウンロードの URL を直す。** `apps/site/src/lib/site.ts` の `downloadUrl` は `releases/latest/download/akapen.zip` だが、`pnpm release:mac` が作る zip は `akapen-<版>.zip` なので、このままだと 404 になる。`https://github.com/yuto343/akapen/releases/latest`（Release のページ）にするか、`publish.sh` で版なしの `akapen.zip` も一緒に上げるか、どちらかに決める
- [ ] LP のデプロイ（今の決まりでは、デプロイはしない。出すときに決める）
