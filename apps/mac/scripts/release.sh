#!/bin/bash
# 配布の成果物を build/release/<版>/ に揃える（公開はしない。公開は scripts/publish.sh）。
#
#   pnpm release:mac <x.y.z>                   # 署名 → 公証 → staple → zip → appcast.xml → cask
#   pnpm release:mac <x.y.z> --skip-notarize   # 公証を飛ばす（手元の確認用。配布には使えない）
#
# 公証のプロファイル（notarytool のキーチェーンの名前）は環境変数 AKAPEN_NOTARY_PROFILE（既定 akapen）。
#
# 作るもの（build/release/<版>/）:
#   akapen-<版>.zip  ditto -c -k --keepParent で固めた akapen.app（Developer ID で署名・公証・staple 済み）
#   appcast.xml      Sparkle の generate_appcast で作り、EdDSA の署名を付けたもの
#   akapen.rb        Homebrew の cask（packaging/homebrew/akapen.rb.template に版と sha256 を埋めたもの）
#   work/            途中の生成物（アーカイブ、書き出したアプリ、公証の結果）
#
# 作り方: xcodebuild archive（Release。Developer ID・hardened runtime・--timestamp）→ -exportArchive（method: developer-id）。
# 書き出しが、同梱の Sparkle.framework の中（Autoupdate・Updater.app・XPC サービス）まで同じ証明書で署名し直す。
set -euo pipefail
cd "$(dirname "$0")/.."

# 署名の証明書は、キーチェーンの中から「Developer ID Application: <名前> (<チーム ID>)」をチーム ID で探して決める（名前は書かない）。
readonly TEAM_ID="G5564YSC93"
readonly REPOSITORY="yuto343/akapen"
readonly FEED_URL="https://github.com/${REPOSITORY}/releases/latest/download/appcast.xml"
readonly SPARKLE_BIN="build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin"

NOTARY_PROFILE="${AKAPEN_NOTARY_PROFILE:-akapen}"
readonly USAGE="使い方: pnpm release:mac <x.y.z> [--skip-notarize]"

fail() {
  printf '\nエラー: %s\n' "$*" >&2
  exit 1
}

step() {
  printf '\n==> %s\n' "$*"
}

# xcodebuild をログに落として走らせる。失敗したらエラーの行を出して止まる。警告があれば出す。
run_xcodebuild() {
  local log="$1"
  shift
  if ! xcodebuild "$@" >"$log" 2>&1; then
    grep -n -A 4 'error:' "$log" | tail -n 60 >&2 || tail -n 40 "$log" >&2
    fail "xcodebuild が失敗した。ログ: $log"
  fi
  if grep -q 'warning:' "$log"; then
    printf '警告があった（ログ: %s）:\n' "$log"
    grep 'warning:' "$log" | sort -u
  fi
}

# 署名が Developer ID・自分のチーム・hardened runtime・タイムスタンプ付きであることを確かめる。
check_signature() {
  local path="$1"
  local info
  info="$(codesign -dvvv "$path" 2>&1)" || fail "署名を読めない: $path"
  grep -qxF "Authority=${IDENTITY}" <<<"$info" || fail "Developer ID（${IDENTITY}）で署名されていない: $path"
  grep -qx "TeamIdentifier=${TEAM_ID}" <<<"$info" || fail "チームが ${TEAM_ID} でない: $path"
  grep -Eq '^CodeDirectory .*flags=0x[0-9a-f]+\([^)]*runtime[^)]*\)' <<<"$info" || fail "hardened runtime が付いていない: $path"
  grep -q '^Timestamp=' <<<"$info" || fail "タイムスタンプが付いていない: $path"
  if [[ "$path" == "$APP" ]]; then
    printf '  ok  akapen.app\n'
  else
    printf '  ok  %s\n' "${path#"$APP"/}"
  fi
}

# --- 引数と前提 ---------------------------------------------------------------

VERSION=""
SKIP_NOTARIZE=0
for arg in "$@"; do
  case "$arg" in
    --skip-notarize)
      SKIP_NOTARIZE=1
      ;;
    -*)
      fail "知らないオプション: ${arg}
${USAGE}"
      ;;
    *)
      [[ -z "$VERSION" ]] || fail "版が 2 つ指定されている（${VERSION} と ${arg}）
${USAGE}"
      VERSION="$arg"
      ;;
  esac
done
if [[ -z "$VERSION" ]]; then
  fail "版を指定する
${USAGE}"
fi
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "版は x.y.z の形にする（数字 3 つ。受け取った値: ${VERSION}）
${USAGE}"
fi
readonly VERSION SKIP_NOTARIZE NOTARY_PROFILE

readonly OUT="build/release/${VERSION}"
readonly WORK="${OUT}/work"
readonly ARCHIVE="${WORK}/akapen.xcarchive"
readonly EXPORT="${WORK}/export"
readonly APP="${EXPORT}/akapen.app"
readonly ZIP="${OUT}/akapen-${VERSION}.zip"
readonly APPCAST="${OUT}/appcast.xml"
readonly CASK="${OUT}/akapen.rb"
readonly DOWNLOAD_PREFIX="https://github.com/${REPOSITORY}/releases/download/v${VERSION}/"

step "akapen ${VERSION} のリリースの成果物を作る（${OUT}）"

identities="$(security find-identity -v -p codesigning)"
IDENTITY="$(grep -oE "\"Developer ID Application: [^\"]* \(${TEAM_ID}\)\"" <<<"$identities" | head -n 1 | tr -d '"')" || true
[[ -n "$IDENTITY" ]] || fail "キーチェーンに署名の証明書がない: Developer ID Application（チーム ${TEAM_ID}）"
readonly IDENTITY

if [[ "$SKIP_NOTARIZE" == 1 ]]; then
  printf '注意: --skip-notarize なので公証を飛ばす。手元の確認用で、この成果物は配布に使えない（pnpm publish:mac も断る）。\n'
else
  step "公証のプロファイル「${NOTARY_PROFILE}」を確かめる"
  if ! notary_check="$(xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" 2>&1)"; then
    printf '%s\n' "$notary_check" >&2
    cat >&2 <<EOF

公証のプロファイル「${NOTARY_PROFILE}」を使えない（キーチェーンにない、または資格情報が通らない）。
一度だけ、次のどちらかで登録してから流し直す（詳しくは docs/RELEASE.md）。

  # Apple ID と app 用パスワード（appleid.apple.com で作る。パスワードは対話で聞かれる）
  xcrun notarytool store-credentials ${NOTARY_PROFILE} --apple-id <Apple ID> --team-id ${TEAM_ID}

  # App Store Connect の API キー
  xcrun notarytool store-credentials ${NOTARY_PROFILE} --key <AuthKey_XXXXXXXXXX.p8> --key-id <キー ID> --issuer <Issuer ID>

公証を飛ばして手元で確かめるだけなら --skip-notarize を付ける（配布には使えない）。
EOF
    exit 1
  fi
  printf '  ok\n'
fi

rm -rf "$OUT"
mkdir -p "$WORK" build/logs

# --- ビルドと署名 -------------------------------------------------------------

step "プロジェクトを作り直す（XcodeGen）"
xcodegen generate --quiet

step "アーカイブする（Release、${VERSION}）"
run_xcodebuild build/logs/release-archive.log \
  archive \
  -project akapen.xcodeproj \
  -scheme akapen \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData \
  -archivePath "$ARCHIVE" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$VERSION"

step "Developer ID で書き出す"
# -exportArchive はビルドをしないので、xcodebuild が -derivedDataPath を受け付けない。生成物は -exportPath（build の下）に出る。
run_xcodebuild build/logs/release-export.log \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT" \
  -exportOptionsPlist packaging/ExportOptions.plist
[[ -d "$APP" ]] || fail "書き出したアプリがない: $APP"

step "版と Sparkle の設定を確かめる"
plist="${APP}/Contents/Info.plist"
short_version="$(plutil -extract CFBundleShortVersionString raw -o - "$plist")"
bundle_version="$(plutil -extract CFBundleVersion raw -o - "$plist")"
feed_url="$(plutil -extract SUFeedURL raw -o - "$plist")"
public_key="$(plutil -extract SUPublicEDKey raw -o - "$plist")"
[[ "$short_version" == "$VERSION" ]] || fail "CFBundleShortVersionString が ${short_version}（${VERSION} であるべき）"
[[ "$bundle_version" == "$VERSION" ]] || fail "CFBundleVersion が ${bundle_version}（${VERSION} であるべき）"
[[ "$feed_url" == "$FEED_URL" ]] || fail "SUFeedURL が ${feed_url}（${FEED_URL} であるべき）"
[[ -x "${SPARKLE_BIN}/generate_appcast" ]] || fail "Sparkle のツールがない: ${SPARKLE_BIN}"
keychain_key="$("${SPARKLE_BIN}/generate_keys" -p 2>/dev/null)" \
  || fail "Sparkle の EdDSA の鍵がキーチェーンにない（docs/RELEASE.md の「Sparkle の鍵」を見る）"
[[ "$keychain_key" == "$public_key" ]] \
  || fail "Info.plist の SUPublicEDKey（${public_key}）が、キーチェーンの鍵の公開鍵（${keychain_key}）と違う"
printf '  ok  版 %s（CFBundleVersion %s）、SUFeedURL、SUPublicEDKey\n' "$short_version" "$bundle_version"

step "署名を確かめる（中に入っているコードすべて）"
codesign --verify --deep --strict --verbose=2 "$APP"
while IFS= read -r -d '' file; do
  kind="$(file -b "$file")"
  if [[ "$kind" == *Mach-O* ]]; then
    check_signature "$file"
  fi
done < <(find "$APP" -type f -perm -u+x -print0 | sort -z)
check_signature "${APP}/Contents/Frameworks/Sparkle.framework"
check_signature "$APP"

# --- 公証 ---------------------------------------------------------------------

if [[ "$SKIP_NOTARIZE" == 1 ]]; then
  step "公証を飛ばす（--skip-notarize）"
else
  step "公証する（数分かかる）"
  ditto -c -k --keepParent "$APP" "${WORK}/notarize.zip"
  xcrun notarytool submit "${WORK}/notarize.zip" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait \
    --output-format json >"${WORK}/notarize.json" || true
  status="$(plutil -extract status raw -o - "${WORK}/notarize.json" 2>/dev/null || echo unknown)"
  submission="$(plutil -extract id raw -o - "${WORK}/notarize.json" 2>/dev/null || true)"
  if [[ "$status" != Accepted ]]; then
    if [[ -n "$submission" ]]; then
      xcrun notarytool log "$submission" --keychain-profile "$NOTARY_PROFILE" "${WORK}/notarize-log.json" || true
    fi
    fail "公証が通らなかった（status: ${status}）。${WORK}/notarize.json と notarize-log.json を見る"
  fi
  printf '  ok  Accepted（%s）\n' "$submission"
  step "公証の結果をアプリに綴じる（staple）"
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
fi

step "Gatekeeper の判定"
assessment="$(spctl -a -vvv -t exec "$APP" 2>&1 || true)"
printf '%s\n' "$assessment"
if [[ "$SKIP_NOTARIZE" == 1 ]]; then
  printf '（公証していないので、Unnotarized で断られるのが正しい）\n'
else
  grep -q 'source=Notarized Developer ID' <<<"$assessment" \
    || fail "Gatekeeper が公証済みと判定しない"
fi

# --- 配る形にする -------------------------------------------------------------

step "zip にする"
ditto -c -k --keepParent "$APP" "$ZIP"
sha256="$(shasum -a 256 "$ZIP" | cut -d ' ' -f 1)"
printf '  %s\n  sha256 %s\n' "$ZIP" "$sha256"

step "appcast.xml を作る（Sparkle の generate_appcast。EdDSA の署名はキーチェーンの鍵で付ける）"
appcast_work="${WORK}/appcast"
mkdir -p "$appcast_work"
cp "$ZIP" "$appcast_work/"
"${SPARKLE_BIN}/generate_appcast" \
  --download-url-prefix "$DOWNLOAD_PREFIX" \
  --link "https://github.com/${REPOSITORY}" \
  "$appcast_work"
cp "${appcast_work}/appcast.xml" "$APPCAST"
enclosure_url="${DOWNLOAD_PREFIX}akapen-${VERSION}.zip"
grep -qF "url=\"${enclosure_url}\"" "$APPCAST" || fail "appcast.xml の enclosure の URL が ${enclosure_url} でない"
grep -qF "<sparkle:version>${VERSION}</sparkle:version>" "$APPCAST" || fail "appcast.xml の sparkle:version が ${VERSION} でない"
signatures="$(sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' "$APPCAST")"
signature="${signatures%%$'\n'*}"
[[ -n "$signature" ]] || fail "appcast.xml に EdDSA の署名（sparkle:edSignature）がない"
"${SPARKLE_BIN}/sign_update" --verify "$ZIP" "$signature" \
  || fail "appcast.xml の EdDSA の署名が zip と合わない"
printf '  ok  %s（enclosure: %s）\n' "$APPCAST" "$enclosure_url"

step "Homebrew の cask を作る"
sed -e "s/{{VERSION}}/${VERSION}/g" -e "s/{{SHA256}}/${sha256}/g" packaging/homebrew/akapen.rb.template >"$CASK"
if grep -q '{{' "$CASK"; then
  fail "cask に埋めていない箇所が残っている: $CASK"
fi
if command -v ruby >/dev/null 2>&1; then
  ruby -c "$CASK" >/dev/null || fail "cask が Ruby として読めない: $CASK"
fi
printf '  ok  %s\n' "$CASK"

step "できあがり"
if [[ "$SKIP_NOTARIZE" == 1 ]]; then
  printf '公証していない（--skip-notarize）。配布するときは --skip-notarize なしで作り直す。\n'
fi
printf '%s\n' "$ZIP" "$APPCAST" "$CASK"
printf '\n公開は pnpm publish:mac %s（docs/RELEASE.md）。\n' "$VERSION"
