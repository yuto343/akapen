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
- [x] **メニューバーの E2E を流し直す**。普段使いの akapen を終了してから `make e2e ONLY=MenuBarSettingsTests` と `make e2e ONLY=MenuBarQuitTests`（同じバンドル ID の akapen が動いていると落ちる）
- [x] **公開してよい中身かを見直した**（2026-11-20）。秘密情報は履歴にもない。MIT の `LICENSE` を置き、手元のパスの例を `/Users/you/` にし、`site.ts` の仮の値を確定した
- [ ] **コミットのメールアドレスを noreply にする（公開の直前）。** 今までのコミットは個人のメールアドレスで作られている。ほかのワークツリーの作業を `main` に入れて閉じてから、次の手順で全ブランチの履歴を書き換える。書き換えるとハッシュがすべて変わるので、公開した後にはやらない
  ```sh
  # main を取り出している、リポジトリの本体の作業ツリーで流す
  git worktree list                       # main のほかに残っていないことを確かめる
  git for-each-ref --format='%(refname)' refs/t3 | xargs -n1 git update-ref -d   # T3 のチェックポイントの ref を消す（古い履歴を持っている）
  git log --all --format='%an <%ae> %cn <%ce>' | sort -u   # 書き換える前に、作者が自分だけであることを確かめる
  git filter-repo --force \
    --name-callback 'return b"yuto343"' \
    --email-callback 'return b"43196286+yuto343@users.noreply.github.com"'
  git log --all --format='%ae %ce' | sort -u   # noreply だけになったことを確かめる
  ```
  これからのコミットは、リポジトリの `user.email` を noreply にしてある（2026-11-20）。GitHub の Settings → Emails の「Block command line pushes that expose my email」も入れておく
- [ ] （任意）`make run` の開発ビルドにも Sparkle が入っている。版が `0.0.0` なので、0.1.0 を公開すると開発ビルドにも「アップデートがあります」が出る。気になるなら、Debug では Sparkle を止める

## GitHub の準備

- [ ] 上の履歴の書き換えが済んでから、このファイル（`LAUNCH-TODO.md`）を消すかどうか決める（公開すると誰でも読める）
- [ ] `yuto343/akapen` を**公開**で作り、remote に足して `main` を push する
  ```sh
  gh repo create yuto343/akapen --public --source . --push
  ```
  `main` にいる状態で流す（`--push` は今のブランチだけを上げる）。`git push --all` や `--mirror` は使わない
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

- [ ] LP の Download ボタン（`releases/latest/download/akapen.zip`）で zip が落ちることを見る
- [ ] `brew install --cask yuto343/tap/akapen` で入ることを見る（別の Mac か、いったん消してから）
- [ ] `https://github.com/yuto343/akapen/releases/latest/download/appcast.xml` が落とせることを見る
- [ ] 次の版（0.1.1 など）を出したときに、0.1.0 のアプリの「アップデートを確認…」で更新が届くことを見る

## LP

- [x] Download の節と、`brew install --cask yuto343/tap/akapen` をコピーできるターミナル風の枠（`apps/site`、4023f88）
- [x] **LP のダウンロードの URL を直した。** `publish.sh` が、版の付いた zip と同じ中身を `akapen.zip` という名前でも Release に上げるようにした。`site.ts` の `downloadUrl`（`releases/latest/download/akapen.zip`）はそのまま使える
- [x] **トップのデモ動画の padding のずれを直す。** コメントでは「左右の余白がずれている」と指摘しているのに、囲んだボタンの余白はずれていなかった。Submit の文字を左に寄せ、動画を撮り直した
- [x] **meta の title を直す。** 日本語版の `<title>` が古いままだった。英語版と同じ「akapen — Mark it up. Hand it right back.」にした
- [x] **favicon を手と鉛筆だけの絵にする。** 枠のある古い絵だった。`brand/logo/akapen-hand.png` を正方形に余白を足して 128×128 にし、`apps/site/static/favicon.png` を差し替えた
- [ ] LP のデプロイ（今の決まりでは、デプロイはしない。出すときに決める）
