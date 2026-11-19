#!/bin/bash
# pnpm release:mac で揃えた成果物を公開する。ユーザーだけが走らせる（エージェントは走らせない）。
#
#   pnpm publish:mac <x.y.z>
#
# 1. 公開する前に確かめる: 成果物が揃っているか、zip の中のアプリが公証済みか、gh にログインしているか、同じ版の Release がないか。
# 2. tap（yuto343/homebrew-tap）を build/release/<版>/work/homebrew-tap に clone し、Casks/akapen.rb を差し替える。
# 3. 何を公開するかを表示して、y の確認を取る。
# 4. gh release create v<版> で zip と appcast.xml を yuto343/akapen に上げる。
# 5. tap の Casks/akapen.rb を commit して push する。
set -euo pipefail
cd "$(dirname "$0")/.."

readonly REPOSITORY="yuto343/akapen"
readonly TAP_REPOSITORY="yuto343/homebrew-tap"

readonly USAGE="使い方: pnpm publish:mac <x.y.z>"

fail() {
  printf '\nエラー: %s\n' "$*" >&2
  exit 1
}

step() {
  printf '\n==> %s\n' "$*"
}

if [[ $# -ne 1 || "$1" == -* ]]; then
  fail "版を 1 つだけ指定する（オプションはない）
${USAGE}"
fi
readonly VERSION="$1"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "版は x.y.z の形にする（数字 3 つ。受け取った値: ${VERSION}）
${USAGE}"
fi

readonly OUT="build/release/${VERSION}"
readonly WORK="${OUT}/work"
readonly ZIP="${OUT}/akapen-${VERSION}.zip"
readonly APPCAST="${OUT}/appcast.xml"
readonly CASK="${OUT}/akapen.rb"
readonly TAG="v${VERSION}"
readonly TAP_DIR="${WORK}/homebrew-tap"

step "成果物を確かめる（${OUT}）"
for file in "$ZIP" "$APPCAST" "$CASK"; do
  [[ -f "$file" ]] || fail "成果物がない: ${file}（先に pnpm release:mac ${VERSION}）"
done
grep -qF "/releases/download/${TAG}/akapen-${VERSION}.zip" "$APPCAST" \
  || fail "appcast.xml の enclosure が ${TAG} の zip を指していない"
sha256="$(shasum -a 256 "$ZIP" | cut -d ' ' -f 1)"
grep -qF "sha256 \"${sha256}\"" "$CASK" || fail "cask の sha256 が zip と合わない（pnpm release:mac を流し直す）"

# 公証していない成果物（--skip-notarize で作ったもの）を公開しない。
check_dir="$(mktemp -d)"
trap 'rm -rf "$check_dir"' EXIT
ditto -x -k "$ZIP" "$check_dir"
[[ -d "${check_dir}/akapen.app" ]] || fail "zip の中に akapen.app がない"
xcrun stapler validate "${check_dir}/akapen.app" >/dev/null 2>&1 \
  || fail "zip の中のアプリに公証の結果が綴じられていない（--skip-notarize で作った？ 付けずに pnpm release:mac を流し直す）"
assessment="$(spctl -a -vvv -t exec "${check_dir}/akapen.app" 2>&1 || true)"
grep -q 'source=Notarized Developer ID' <<<"$assessment" \
  || fail "Gatekeeper が公証済みと判定しない: ${assessment}"
printf '  ok  公証済み（%s）\n' "$ZIP"

step "GitHub を確かめる"
gh auth status >/dev/null || fail "gh にログインしていない（gh auth login）"
gh repo view "$REPOSITORY" >/dev/null || fail "${REPOSITORY} が見えない（リポジトリを作って公開する。docs/RELEASE.md）"
if gh release view "$TAG" --repo "$REPOSITORY" >/dev/null 2>&1; then
  fail "${REPOSITORY} に ${TAG} の Release がすでにある"
fi
printf '  ok\n'

step "tap（${TAP_REPOSITORY}）を取ってきて cask を差し替える"
rm -rf "$TAP_DIR"
gh repo clone "$TAP_REPOSITORY" "$TAP_DIR" -- --depth 1 --quiet
mkdir -p "${TAP_DIR}/Casks"
cp "$CASK" "${TAP_DIR}/Casks/akapen.rb"
git -C "$TAP_DIR" add Casks/akapen.rb
tap_changed=1
if git -C "$TAP_DIR" diff --cached --quiet; then
  tap_changed=0
fi

step "次を公開する"
printf '  GitHub Release: https://github.com/%s/releases/tag/%s\n' "$REPOSITORY" "$TAG"
printf '    タグ %s（まだなければ、%s の既定のブランチの先頭に作る）\n' "$TAG" "$REPOSITORY"
printf '    添付: %s（sha256 %s）\n' "$(basename "$ZIP")" "$sha256"
printf '    添付: appcast.xml（Sparkle の feed。releases/latest/download/appcast.xml で配られる）\n'
if [[ "$tap_changed" == 1 ]]; then
  printf '  Homebrew tap: %s の Casks/akapen.rb を commit して push する\n\n' "$TAP_REPOSITORY"
  git -C "$TAP_DIR" --no-pager diff --cached
else
  printf '  Homebrew tap: Casks/akapen.rb は変わらない（commit しない）\n'
fi
printf '\n'
read -r -p "公開してよいですか？ [y/N] " answer </dev/tty
if [[ "$answer" != y && "$answer" != Y ]]; then
  fail "取りやめた（何も公開していない）"
fi

step "GitHub Release を作る"
gh release create "$TAG" \
  --repo "$REPOSITORY" \
  --title "akapen ${VERSION}" \
  --generate-notes \
  "$ZIP" \
  "$APPCAST"

if [[ "$tap_changed" == 1 ]]; then
  step "tap に push する"
  git -C "$TAP_DIR" commit --quiet -m "akapen ${VERSION}"
  git -C "$TAP_DIR" push --quiet
fi

step "公開した"
printf '  https://github.com/%s/releases/tag/%s\n' "$REPOSITORY" "$TAG"
printf '  brew install --cask yuto343/tap/akapen\n'
