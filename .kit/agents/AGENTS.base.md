## kit（このブロックは kit が置く。手で編集しない）

- `.kit/`、`kit.lock`、このブロック、kit が置いた symlink と `.github/workflows/kit-ci.yml` は手で編集しない。`node .kit/cli/kit.mjs check` が落ちる。
- 直したいときは kit のリポジトリを直し、新しい版を `node .kit/cli/kit.mjs sync` で取り込む。
