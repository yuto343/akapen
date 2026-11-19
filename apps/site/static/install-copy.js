// LP のターミナル風の枠（InstallTerminal.svelte）のコピーのボタンを動かす。
// LP は csr = false でハイドレーションしないため、このボタンのためだけに素の JS を 1 本置いている。
// クリップボードの API が使えないときは何もしない（ボタンは hidden のまま、コマンドは選択してコピーできる）。
(() => {
  if (!window.isSecureContext || !navigator.clipboard || !navigator.clipboard.writeText) {
    return;
  }

  // 「コピーしました」の状態を見せておく時間（ミリ秒）。
  const copiedDuration = 2000;

  for (const button of document.querySelectorAll('[data-copy-command]')) {
    const status = button.parentElement.querySelector('[data-copy-status]');
    let resetTimer = 0;

    button.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(button.dataset.copyCommand);
      } catch {
        return;
      }
      button.dataset.copied = '';
      window.clearTimeout(resetTimer);
      if (status) {
        // 続けて押したときも読み上げ直すよう、いったん空にしてから入れる。
        status.textContent = '';
        window.setTimeout(() => {
          status.textContent = status.dataset.message;
        }, 50);
      }
      resetTimer = window.setTimeout(() => {
        delete button.dataset.copied;
        if (status) {
          status.textContent = '';
        }
      }, copiedDuration);
    });

    button.hidden = false;
  }
})();
