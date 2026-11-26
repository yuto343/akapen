<script lang="ts">
  import { messages, type Language } from '$lib/i18n';
  import KeyChip from './KeyChip.svelte';
  let { language }: { language: Language } = $props();
  const text = $derived(messages[language]);
  // 見出しの 3 つの句。ja では句ごとに小さな日本語の注記を上に置く（Hero の見出しと同じ仕組み）。
  const phrases = $derived([
    { phrase: text.howTitleStart, note: text.howNoteStart },
    { phrase: text.howTitleMiddle, note: text.howNoteMiddle },
    { phrase: text.howTitleEnd, note: text.howNoteEnd }
  ]);
  // 手順の 3 つ。visual で、カードに描く場面を選ぶ。
  const steps: { visual: 'press' | 'annotate' | 'paste'; number: string; title: string; body: string }[] = $derived([
    { visual: 'press', number: '01', title: text.howPressTitle, body: text.howPressBody },
    { visual: 'annotate', number: '02', title: text.howAnnotateTitle, body: text.howAnnotateBody },
    { visual: 'paste', number: '03', title: text.howPasteTitle, body: text.howPasteBody }
  ]);
  // コピーされるプロンプトの画像の置き場（Demo.svelte と同じ）。
  const promptPath = '/Users/you/Library/Caches/akapen/20261117-1432/';
</script>

<!--
  場面に共通の部品。見た目はアプリ（apps/mac の AkapenUI）と、LP の動画の絵（Demo.svelte）に合わせる。
-->
{#snippet sampleWindow()}
  <div class="window">
    <div class="titlebar">
      <span class="traffic close"></span>
      <span class="traffic minimize"></span>
      <span class="traffic zoom"></span>
      <span class="window-title">{text.demoApp}</span>
    </div>
    <div class="window-body">
      <div class="sidebar">
        <span class="side-item selected"><span class="side-label strong"></span></span>
        <span class="side-item"><span class="side-label wide"></span></span>
        <span class="side-item"><span class="side-label short"></span></span>
        <span class="side-item"><span class="side-label"></span></span>
      </div>
      <div class="form">
        <span class="form-heading"></span>
        <span class="form-subtitle"></span>
        <span class="field"><span class="field-label"></span><span class="field-input"></span></span>
        <span class="field"><span class="field-label short"></span><span class="field-input short"></span></span>
        <span class="form-divider"></span>
        <span class="form-actions">
          <span class="cancel-button">{messages.en.demoCancel}</span>
          <!-- コメントの「左右の余白がずれている」が絵で分かるように、文字をわざと左に寄せている（Demo.svelte と同じ）。 -->
          <span class="submit-button">{text.demoSubmit}</span>
        </span>
      </div>
    </div>
  </div>
{/snippet}

{#snippet menubar()}
  <div class="menubar">
    <svg class="apple" viewBox="0 0 13 15"><path d="M10.6 8c0-1.9 1.6-2.8 1.6-2.9-.9-1.3-2.2-1.5-2.7-1.5-1.1-.1-2.2.7-2.8.7-.6 0-1.5-.7-2.4-.6C3 3.7 1.9 4.4 1.3 5.5 0 7.7 1 11 2.2 12.8c.6.9 1.3 1.8 2.2 1.8.9 0 1.2-.6 2.3-.6 1.1 0 1.4.6 2.3.6 1 0 1.6-.9 2.2-1.8.7-1 1-2 1-2.1 0 0-1.6-.6-1.6-2.7zM8.8 2.4c.5-.6.8-1.4.7-2.2-.7 0-1.6.5-2.1 1.1-.5.5-.9 1.4-.8 2.2.8.1 1.6-.4 2.2-1.1z" /></svg>
    <span class="menu-app">{text.demoApp}</span>
    <span>{text.demoFile}</span>
    <span>{text.demoEdit}</span>
    <span>{text.demoView}</span>
  </div>
{/snippet}

<!-- 枠を描く状態の、画面上端の案内（アプリの DrawHintView）。 -->
{#snippet drawHint()}
  <div class="hint"><span class="hint-dot"></span><span>{text.demoGuide}</span><KeyChip dark escape>esc</KeyChip><span class="hint-cancel">{text.demoCancel}</span></div>
{/snippet}

<!-- 画面下の操作ボタン（アプリの ToolbarView）。注釈が 0 件のあいだ、すべて消す・コピーは押せない。 -->
{#snippet toolbar(count: number)}
  <div class="toolbar" class:empty={count === 0}>
    <span class="tool clear">
      <svg class="tool-icon" viewBox="0 0 14 14"><path d="M3 4h8M5 4V2.5h4V4M4 4l.5 8h5l.5-8" /></svg>
      <span class="chips"><KeyChip>⌘</KeyChip><KeyChip>⌫</KeyChip></span>
    </span>
    <span class="tool list">
      <svg class="tool-icon" viewBox="0 0 14 14"><path d="M5 3.5h7M5 7h7M5 10.5h7" /><circle cx="2" cy="3.5" r="1" /><circle cx="2" cy="7" r="1" /><circle cx="2" cy="10.5" r="1" /></svg>
      <span>{text.demoList}</span>
      <span class="chips"><KeyChip>⌘</KeyChip><KeyChip>L</KeyChip></span>
      {#if count > 0}<span class="badge">{count}</span>{/if}
    </span>
    <span class="tool copy">
      <span class="copy-circle">
        <svg viewBox="0 0 14 14"><rect x="4.75" y="4.75" width="7.5" height="7.5" rx="1.6" /><path d="M9.25 4.75V3.4c0-.9-.7-1.6-1.6-1.6H3.4c-.9 0-1.6.7-1.6 1.6v4.25c0 .9.7 1.6 1.6 1.6h1.35" /></svg>
      </span>
      <span>{text.demoCopy}</span>
      <span class="chips"><KeyChip dark>⌘</KeyChip><KeyChip dark>C</KeyChip></span>
    </span>
  </div>
{/snippet}

<!-- 押したキーを見せる表示（LP の動画の ⌘V と同じ形）。 -->
{#snippet keyHud(keys: string[], label: string)}
  <div class="key-hud"><span class="hud-keys">{#each keys as key}<KeyChip dark>{key}</KeyChip>{/each}</span>{#if label}<span>{label}</span>{/if}</div>
{/snippet}

{#snippet crosshair()}
  <svg class="cursor-crosshair" viewBox="0 0 24 24"><path class="cursor-halo" d="M12 1v22M1 12h22" /><path class="cursor-line" d="M12 1v22M1 12h22" /></svg>
{/snippet}

{#snippet arrow()}
  <svg class="cursor-arrow" viewBox="0 0 24 24"><path d="M4 2v18l4.8-4.8 3.8 7 3.4-1.9-3.8-6.8H19Z" /></svg>
{/snippet}

<!--
  使い方を 3 つの手順で見せる節。各カードの絵は CSS の keyframes だけで 8 秒ごとに繰り返す。
  要素の素のスタイルは場面の見せどころの状態にしてあり、動きを減らす設定ではそこで止まって見える。
-->
<section id="how-it-works" class="how" aria-labelledby="how-heading">
  <div class="heading">
    <p class="eyebrow">
      <span class="eyebrow-line" aria-hidden="true"></span>
      {text.howEyebrow}
      <span class="eyebrow-line" aria-hidden="true"></span>
    </p>
    <h2 id="how-heading" aria-label={text.howTitle}>
      {#each phrases as { phrase, note }, index}{#if index > 0}{' '}{/if}<span class="phrase">{#if note}<span class="note" aria-hidden="true">{note}</span>{/if}{phrase}</span>{/each}
    </h2>
    <p class="lead">{text.howLead}</p>
  </div>
  <ol class="steps">
    {#each steps as step (step.visual)}
      <li class="step">
        <div class="visual" class:press={step.visual === 'press'} aria-hidden="true">
          <div class="scene {step.visual}">
            {#if step.visual === 'press'}
              <!-- 01: ⌘⇧6 を押すと、上に案内、下に操作ボタンが出て、カーソルが十字になる。 -->
              {@render menubar()}
              {@render sampleWindow()}
              {@render drawHint()}
              {@render toolbar(0)}
              {@render keyHud(['⌘', '⇧', '6'], '')}
              <span class="cursor">{@render crosshair()}{@render arrow()}</span>
            {:else if step.visual === 'annotate'}
              <!-- 02: ドラッグで赤枠を描き、横に出るコメント入力に書いて、↵ で確定する。 -->
              {@render sampleWindow()}
              {@render drawHint()}
              <span class="frame"></span>
              <span class="size-label">94 × 38</span>
              <div class="comment">
                <p class="comment-text">
                  <span class="comment-placeholder">{text.howCommentPlaceholder}</span>
                  <span class="comment-label"><span class="typed">{text.demoComment}</span><span class="text-caret"></span></span>
                </p>
                <div class="comment-footer">
                  <span class="comment-hints">
                    <span class="comment-hint"><span class="done-key"><KeyChip>↵</KeyChip></span>{text.demoDone}</span>
                    <span class="comment-hint"><span class="chips"><KeyChip>⇧</KeyChip><KeyChip>↵</KeyChip></span>{text.demoNewLine}</span>
                  </span>
                  <span class="comment-hint"><KeyChip escape>esc</KeyChip>{text.demoCancel}</span>
                </div>
              </div>
              <span class="cursor">{@render crosshair()}</span>
            {:else}
              <!-- 03: コピーを押すと「コピーしました！」が出る。AI のチャットに ⌘V で貼ると、定型文と画像のパスとコメントが入る。 -->
              {@render menubar()}
              {@render sampleWindow()}
              {@render toolbar(2)}
              <div class="toast">
                <span class="toast-pill">
                  <span class="toast-check"><svg viewBox="0 0 14 14"><path d="M3 7l2.5 2.5L11 4" pathLength="1" /></svg></span>
                  <span class="toast-label">{text.demoCopied}</span>
                </span>
              </div>
              <div class="chat">
                <div class="titlebar">
                  <span class="traffic close"></span>
                  <span class="traffic minimize"></span>
                  <span class="traffic zoom"></span>
                  <span class="window-title">{text.demoChatApp}</span>
                </div>
                <div class="chat-body">
                  <div class="chat-message">
                    <span class="chat-avatar"></span>
                    <span class="chat-lines"><span></span><span></span></span>
                  </div>
                  <div class="composer">
                    <span class="composer-placeholder">{text.demoChatPlaceholder}</span>
                    <div class="composer-text">
                      <p>{text.demoPromptIntro}<br />{text.demoPromptInstruction}</p>
                      <p><span class="prompt-path">{promptPath}01.png</span><br />{text.demoEarlierComment}</p>
                      <p><span class="prompt-path">{promptPath}02.png</span><br />{text.demoComment}</p>
                    </div>
                    <span class="send-button"><svg viewBox="0 0 14 14"><path d="M7 11.5v-9M3 6.5l4-4 4 4" /></svg></span>
                  </div>
                </div>
              </div>
              {@render keyHud(['⌘', 'V'], text.demoPaste)}
              <span class="cursor">{@render arrow()}</span>
            {/if}
          </div>
          <span class="progress"><span class="progress-fill"></span></span>
        </div>
        <div class="step-text">
          <span class="number" aria-hidden="true">{step.number}</span>
          <h3>{step.title}</h3>
          <p class="body">{step.body}</p>
        </div>
      </li>
    {/each}
  </ol>
</section>

<style>
.how { display: flex; flex-direction: column; align-items: center; gap: var(--how-gap); padding: 0 var(--page-gutter) var(--how-bottom-space); }
.heading { display: flex; flex-direction: column; align-items: center; gap: var(--spacing-4); }
/* Download の節の「or」と同じ見た目。 */
.eyebrow { display: flex; align-items: center; gap: var(--or-gap); color: var(--color-steel); font: var(--text-label)/16px var(--font-mono); letter-spacing: var(--or-tracking); text-transform: uppercase; }
.eyebrow-line { width: var(--or-line-width); height: 1px; background: var(--color-line); }
h2 { padding-top: var(--how-title-space); color: var(--color-heading); font-size: var(--how-title-size); font-weight: 600; letter-spacing: var(--how-title-tracking); line-height: var(--how-title-line); text-align: center; }
.phrase { display: inline-block; position: relative; }
.note { position: absolute; bottom: 100%; left: 50%; translate: -50% 0; padding-bottom: var(--how-note-gap); color: var(--color-ink-2); font-size: var(--how-note-size); font-weight: 600; letter-spacing: var(--how-note-tracking); line-height: 1; white-space: nowrap; }
.lead { max-width: var(--how-lead-width); color: var(--color-ink-2); font-size: var(--how-lead-size); line-height: var(--how-lead-line); text-align: center; }
.steps { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); align-items: start; gap: var(--how-steps-gap); width: 100%; max-width: var(--how-steps-width); margin: 0; padding: 0; list-style: none; }
.step { display: flex; flex-direction: column; gap: var(--how-step-gap); }
.visual { position: relative; aspect-ratio: 4 / 3; container-type: inline-size; overflow: clip; border-radius: var(--how-visual-radius); background: var(--surface-desktop); box-shadow: var(--shadow-glass); }
.step-text { display: flex; flex-direction: column; gap: var(--how-inner-gap); padding-inline: var(--how-copy-padding); }
.number { color: var(--color-accent); font: 500 var(--text-label)/16px var(--font-mono); letter-spacing: var(--how-number-tracking); }
h3 { margin: 0; color: var(--color-heading); font-size: var(--how-step-title-size); font-weight: 600; letter-spacing: var(--how-step-title-tracking); line-height: var(--how-step-title-line); }
.body { color: var(--color-ink-2); font-size: var(--how-step-body-size); line-height: var(--how-step-body-line); white-space: pre-line; }
.progress { position: absolute; right: 0; bottom: 0; left: 0; z-index: 1; height: var(--how-progress-height); overflow: clip; background: var(--how-track); }
.progress-fill { display: block; height: 100%; background: var(--color-accent); transform-origin: left; animation: how-progress var(--how-cycle) linear infinite; }

/*
  場面は 480×360 の座標で置き、カードの幅に合わせて丸ごと縮める。
  --u が場面の 1 単位。アプリの値（pt）はそのまま単位の数にする。KeyChip は --demo-unit で大きさを決める。
*/
/* 01 は ⌘⇧6 で UI が出るところだけなので、ほかの 2 枚より短く繰り返す（進み具合の線も同じ長さ）。 */
.visual.press { --how-cycle: var(--how-press-cycle); }
.scene { --u: calc(100cqw / var(--how-scene-width)); --demo-unit: var(--u); position: absolute; inset: 0; color: var(--color-ink); font-family: var(--font-sans); }
.chips, .hud-keys { display: flex; align-items: center; gap: calc(2 * var(--u)); }

/* デスクトップのメニューバー。 */
.menubar { position: absolute; top: 0; right: 0; left: 0; display: flex; align-items: center; gap: calc(16 * var(--u)); height: calc(24 * var(--u)); padding-inline: calc(14 * var(--u)); background: var(--how-mock-menubar); font-size: calc(12 * var(--u)); line-height: calc(16 * var(--u)); }
.apple { width: calc(11 * var(--u)); height: calc(13 * var(--u)); fill: var(--color-ink); }
.menu-app { font-weight: 600; }

/* 注釈を付ける先のアプリの窓。 */
.window { position: absolute; top: calc(48 * var(--u)); left: calc(32 * var(--u)); display: flex; flex-direction: column; width: calc(416 * var(--u)); height: calc(340 * var(--u)); overflow: clip; border-radius: var(--radius-media); background: var(--color-clean-bg); box-shadow: var(--how-mock-window-shadow); }
.titlebar { position: relative; display: flex; flex-shrink: 0; align-items: center; gap: calc(7 * var(--u)); height: calc(36 * var(--u)); padding-inline: calc(14 * var(--u)); border-bottom: calc(1 * var(--u)) solid var(--how-mock-divider); background: var(--how-mock-titlebar); }
.traffic { width: calc(11 * var(--u)); height: calc(11 * var(--u)); border-radius: var(--radius-full); }
.traffic.close { background: var(--terminal-dot-red); }
.traffic.minimize { background: var(--terminal-dot-yellow); }
.traffic.zoom { background: var(--terminal-dot-green); }
.window-title { position: absolute; inset: 0; font-size: calc(12 * var(--u)); font-weight: 600; line-height: calc(36 * var(--u)); text-align: center; }
.window-body { display: flex; flex-grow: 1; }
.sidebar { display: flex; flex-direction: column; flex-shrink: 0; gap: calc(2 * var(--u)); width: calc(110 * var(--u)); padding: calc(14 * var(--u)) calc(7 * var(--u)); border-right: calc(1 * var(--u)) solid var(--how-mock-divider); background: var(--how-mock-sidebar); }
.side-item { display: flex; align-items: center; height: calc(24 * var(--u)); padding-inline: calc(10 * var(--u)); border-radius: calc(6 * var(--u)); }
.side-item.selected { background: var(--how-mock-selected); }
.side-label { width: calc(56 * var(--u)); height: calc(7 * var(--u)); border-radius: calc(4 * var(--u)); background: var(--how-mock-skeleton); }
.side-label.strong { background: var(--how-mock-skeleton-strong); }
.side-label.wide { width: calc(72 * var(--u)); }
.side-label.short { width: calc(44 * var(--u)); }
.form { display: flex; flex-direction: column; flex-grow: 1; gap: calc(12 * var(--u)); padding: calc(22 * var(--u)) calc(24 * var(--u)); }
.form-heading { width: calc(130 * var(--u)); height: calc(12 * var(--u)); border-radius: calc(6 * var(--u)); background: var(--how-mock-heading); }
.form-subtitle { width: calc(210 * var(--u)); height: calc(7 * var(--u)); margin-top: calc(-4 * var(--u)); border-radius: calc(4 * var(--u)); background: var(--how-mock-skeleton-soft); }
.field { display: flex; flex-direction: column; gap: calc(6 * var(--u)); }
.field-label { width: calc(80 * var(--u)); height: calc(7 * var(--u)); border-radius: calc(4 * var(--u)); background: var(--how-mock-skeleton); }
.field-label.short { width: calc(60 * var(--u)); }
.field-input { width: calc(240 * var(--u)); height: calc(26 * var(--u)); border-radius: calc(6 * var(--u)); box-shadow: inset 0 0 0 calc(1 * var(--u)) var(--how-mock-outline); }
.field-input.short { width: calc(200 * var(--u)); }
.form-divider { height: calc(1 * var(--u)); background: var(--how-mock-divider); }
.form-actions { display: flex; justify-content: end; gap: calc(8 * var(--u)); }
.cancel-button, .submit-button { display: flex; align-items: center; height: calc(28 * var(--u)); border-radius: calc(6 * var(--u)); font-size: calc(12 * var(--u)); line-height: calc(16 * var(--u)); }
.cancel-button { justify-content: center; width: calc(70 * var(--u)); box-shadow: inset 0 0 0 calc(1 * var(--u)) var(--how-mock-outline); }
.submit-button { width: calc(84 * var(--u)); padding-left: calc(8 * var(--u)); background: var(--how-mock-submit); color: var(--color-clean-bg); font-weight: 500; }

/* 上端の案内（Drag to frame）。 */
.hint { position: absolute; width: max-content; top: calc(36 * var(--u)); left: 50%; translate: -50% 0; display: flex; align-items: center; gap: calc(10 * var(--u)); height: calc(36 * var(--u)); padding-inline: calc(14 * var(--u)); border: calc(1 * var(--u)) solid var(--color-white-border); border-radius: var(--radius-full); background: var(--surface-ink); box-shadow: var(--shadow-ink); color: var(--color-clean-bg); font-size: calc(13 * var(--u)); font-weight: 500; line-height: calc(16 * var(--u)); white-space: nowrap; }
.hint-dot { width: calc(8 * var(--u)); height: calc(8 * var(--u)); border-radius: var(--radius-full); background: var(--surface-red); box-shadow: 0 0 0 calc(3 * var(--u)) var(--color-red-halo); }
.hint-cancel { margin-left: calc(-4 * var(--u)); color: var(--color-steel); font: calc(11 * var(--u))/calc(14 * var(--u)) var(--font-mono); }

/* 画面下の操作ボタン。 */
.toolbar { position: absolute; width: max-content; top: calc(294 * var(--u)); left: 50%; translate: -50% 0; display: flex; align-items: center; gap: calc(6 * var(--u)); padding: calc(7 * var(--u)); border-radius: var(--radius-full); background: var(--surface-glass); backdrop-filter: blur(var(--glass-blur)); box-shadow: var(--shadow-glass); font-size: calc(13 * var(--u)); font-weight: 500; line-height: calc(16 * var(--u)); white-space: nowrap; }
.tool { position: relative; display: flex; align-items: center; gap: calc(6 * var(--u)); height: calc(38 * var(--u)); padding-inline: calc(14 * var(--u)); border-radius: var(--radius-full); background: var(--surface-white); box-shadow: var(--shadow-white); }
.tool-icon { width: calc(14 * var(--u)); height: calc(14 * var(--u)); margin-right: calc(2 * var(--u)); fill: none; stroke: var(--color-ink); stroke-width: 1.4; stroke-linecap: round; stroke-linejoin: round; }
.tool-icon circle { fill: var(--color-ink); stroke: none; }
.tool.copy { gap: calc(6 * var(--u)); padding-left: calc(5 * var(--u)); background: var(--surface-ink); box-shadow: var(--shadow-ink); color: var(--color-clean-bg); }
.copy-circle { display: flex; align-items: center; justify-content: center; width: calc(28 * var(--u)); height: calc(28 * var(--u)); margin-right: calc(4 * var(--u)); border-radius: var(--radius-full); background: var(--surface-red); box-shadow: var(--shadow-red); }
.copy-circle svg { width: calc(13 * var(--u)); height: calc(13 * var(--u)); fill: none; stroke: var(--color-clean-bg); stroke-width: 1.5; stroke-linecap: round; }
/* 注釈が 0 件のあいだ、すべて消す・コピーは押せない（アプリの disabledOpacity）。 */
.toolbar.empty .clear, .toolbar.empty .copy { opacity: .4; }
.badge { position: absolute; top: calc(-6 * var(--u)); right: calc(-6 * var(--u)); display: flex; align-items: center; justify-content: center; min-width: calc(20 * var(--u)); height: calc(20 * var(--u)); padding-inline: calc(5 * var(--u)); border-radius: var(--radius-full); background: var(--surface-red); box-shadow: 0 0 0 calc(2 * var(--u)) var(--color-clean-bg), var(--shadow-red); color: var(--color-clean-bg); font-size: calc(11 * var(--u)); font-weight: 600; line-height: calc(18 * var(--u)); }

/* 押したキーの表示。 */
.key-hud { position: absolute; width: max-content; top: calc(162 * var(--u)); left: 50%; translate: -50% 0; display: flex; align-items: center; gap: calc(12 * var(--u)); padding: calc(10 * var(--u)) calc(18 * var(--u)) calc(10 * var(--u)) calc(12 * var(--u)); border: calc(1 * var(--u)) solid var(--color-white-border); border-radius: var(--radius-full); background: var(--surface-ink); box-shadow: var(--shadow-ink); color: var(--color-clean-bg); font-size: calc(15 * var(--u)); font-weight: 500; line-height: calc(20 * var(--u)); white-space: nowrap; opacity: 0; }
.press .key-hud { padding-right: calc(12 * var(--u)); }
.hud-keys { gap: calc(3 * var(--u)); }
.hud-keys :global(.key-chip) { height: calc(26 * var(--u)); min-width: calc(26 * var(--u)); border-radius: calc(7 * var(--u)); font-size: calc(14 * var(--u)); }

/* カーソル。位置は translate で動かし、十字は中心、矢印は先端が指す点に合わせる。 */
.cursor { position: absolute; top: 0; left: 0; width: calc(24 * var(--u)); height: calc(24 * var(--u)); }
.cursor svg { position: absolute; inset: 0; width: 100%; height: 100%; }
.cursor-crosshair { translate: -50% -50%; fill: none; }
.cursor-halo { stroke: var(--color-clean-bg); stroke-width: 3; }
.cursor-line { stroke: var(--color-ink); stroke-width: 1; }
.cursor-arrow { translate: -16.667% -8.333%; fill: var(--color-ink); stroke: var(--color-clean-bg); stroke-width: 1.3; stroke-linejoin: round; }

/* 01 */
.press .cursor { translate: calc(250 * var(--u)) calc(196 * var(--u)); }
.press .cursor-arrow { opacity: 0; animation: how-press-arrow var(--how-cycle) step-end infinite; }
.press .cursor-crosshair { animation: how-press-crosshair var(--how-cycle) step-end infinite; }
.press .key-hud { animation: how-press-hud var(--how-cycle) var(--ease-spring) infinite; }
.press .hud-keys :global(.key-chip) { animation: how-press-key var(--how-cycle) var(--ease-out) infinite; }
.press .hint { animation: how-press-hint var(--how-cycle) var(--ease-spring) infinite; }
.press .toolbar { animation: how-press-toolbar var(--how-cycle) var(--ease-spring) infinite; }

/* 02: 場面を上へずらし、窓の下の方（Submit のボタン）を見せる。 */
.annotate .window { top: calc(-92 * var(--u)); }
.annotate .hint { top: calc(16 * var(--u)); opacity: 0; animation: how-annotate-hint var(--how-cycle) var(--ease-spring) infinite; }
.frame { position: absolute; top: calc(114 * var(--u)); left: calc(335 * var(--u)); width: calc(94 * var(--u)); height: calc(38 * var(--u)); border: calc(3 * var(--u)) solid var(--color-accent); border-radius: calc(10 * var(--u)); box-shadow: 0 0 0 calc(4 * var(--u)) var(--color-red-halo), var(--shadow-red); animation: how-frame var(--how-cycle) var(--ease-out) infinite; }
.size-label { position: absolute; top: calc(164 * var(--u)); right: calc(61 * var(--u)); display: flex; align-items: center; height: calc(22 * var(--u)); padding-inline: calc(8 * var(--u)); border-radius: var(--radius-full); background: var(--surface-ink); color: var(--color-clean-bg); font: calc(11 * var(--u))/calc(14 * var(--u)) var(--font-mono); white-space: nowrap; opacity: 0; animation: how-size-label var(--how-cycle) var(--ease-out) infinite; }
.comment { position: absolute; top: calc(162 * var(--u)); left: calc(129 * var(--u)); width: calc(300 * var(--u)); border-radius: calc(20 * var(--u)); background: var(--surface-white); backdrop-filter: blur(var(--glass-blur)); box-shadow: var(--shadow-glass); transform-origin: top right; animation: how-comment var(--how-cycle) var(--ease-spring) infinite; }
.comment-text { position: relative; padding: calc(14 * var(--u)) calc(16 * var(--u)) calc(10 * var(--u)); font-size: calc(14 * var(--u)); line-height: calc(21 * var(--u)); white-space: nowrap; }
.comment-placeholder { position: absolute; color: var(--color-steel); opacity: 0; animation: how-placeholder var(--how-cycle) step-end infinite; }
.comment-label { position: relative; display: inline-block; vertical-align: top; }
.typed { display: inline-block; animation: how-typing var(--how-cycle) linear infinite; }
.text-caret { position: absolute; top: calc(2 * var(--u)); left: 100%; width: calc(1.5 * var(--u)); height: calc(17 * var(--u)); background: var(--color-accent); animation: how-caret-move var(--how-cycle) linear infinite, how-blink var(--motion-caret) step-end infinite; }
.comment-footer { display: flex; align-items: center; justify-content: space-between; padding: calc(8 * var(--u)) calc(16 * var(--u)); border-top: calc(1 * var(--u)) solid var(--color-line); }
.comment-hints { display: flex; align-items: center; gap: calc(12 * var(--u)); }
.comment-hint { display: flex; align-items: center; gap: calc(6 * var(--u)); color: var(--color-steel); font-size: calc(11 * var(--u)); line-height: calc(14 * var(--u)); white-space: nowrap; }
.done-key { animation: how-done-key var(--how-cycle) var(--ease-out) infinite; }
.annotate .cursor { translate: calc(429 * var(--u)) calc(152 * var(--u)); animation: how-annotate-cursor var(--how-cycle) var(--ease-out) infinite; }

/* 03 */
.paste .toolbar { opacity: 0; animation: how-paste-toolbar var(--how-cycle) var(--ease-out) infinite; }
.paste .tool.copy { animation: how-press-copy var(--how-cycle) var(--ease-out) infinite; }
.toast { position: absolute; width: max-content; top: calc(294 * var(--u)); left: 50%; translate: -50% 0; padding: calc(6 * var(--u)); border-radius: var(--radius-full); background: var(--surface-glass); backdrop-filter: blur(var(--glass-blur)); box-shadow: var(--shadow-glass); opacity: 0; animation: how-toast var(--how-cycle) var(--ease-spring) infinite; }
.toast-pill { display: flex; align-items: center; gap: calc(10 * var(--u)); height: calc(36 * var(--u)); padding-right: calc(18 * var(--u)); padding-left: calc(4 * var(--u)); border-radius: var(--radius-full); background: var(--surface-ink); box-shadow: var(--shadow-ink); }
.toast-check { display: flex; align-items: center; justify-content: center; width: calc(28 * var(--u)); height: calc(28 * var(--u)); border-radius: var(--radius-full); background: var(--color-success); }
.toast-check svg { width: calc(13 * var(--u)); height: calc(13 * var(--u)); fill: none; stroke: var(--color-clean-bg); stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; stroke-dasharray: 1; animation: how-check var(--how-cycle) var(--ease-out) infinite; }
.toast-label { color: var(--color-clean-bg); font-size: calc(13 * var(--u)); font-weight: 500; line-height: calc(16 * var(--u)); white-space: nowrap; }
.chat { position: absolute; top: calc(40 * var(--u)); left: calc(36 * var(--u)); display: flex; flex-direction: column; width: calc(408 * var(--u)); height: calc(306 * var(--u)); overflow: clip; border-radius: var(--radius-media); background: var(--color-clean-bg); box-shadow: var(--how-mock-window-shadow); transform-origin: 50% 100%; animation: how-chat var(--how-cycle) var(--ease-spring) infinite; }
.chat-body { position: relative; flex-grow: 1; background: var(--color-clean-surface); }
.chat-message { display: flex; gap: calc(10 * var(--u)); padding: calc(18 * var(--u)) calc(20 * var(--u)); }
.chat-avatar { flex-shrink: 0; width: calc(22 * var(--u)); height: calc(22 * var(--u)); border-radius: var(--radius-full); background: var(--surface-ink); }
.chat-lines { display: flex; flex-direction: column; gap: calc(8 * var(--u)); padding-top: calc(4 * var(--u)); }
.chat-lines span { width: calc(260 * var(--u)); height: calc(7 * var(--u)); border-radius: calc(4 * var(--u)); background: var(--how-mock-skeleton); }
.chat-lines span + span { width: calc(180 * var(--u)); }
.composer { position: absolute; right: calc(14 * var(--u)); bottom: calc(14 * var(--u)); left: calc(14 * var(--u)); height: calc(196 * var(--u)); overflow: clip; border-radius: calc(16 * var(--u)); background: var(--color-clean-bg); box-shadow: var(--shadow-white), 0 0 0 calc(3 * var(--u)) var(--color-red-halo); outline: calc(1 * var(--u)) solid var(--color-line); animation: how-composer var(--how-cycle) var(--ease-spring) infinite; }
.composer-placeholder { position: absolute; top: calc(14 * var(--u)); left: calc(16 * var(--u)); color: var(--color-steel); font-size: calc(13 * var(--u)); line-height: calc(18 * var(--u)); opacity: 0; animation: how-composer-placeholder var(--how-cycle) step-end infinite; }
.composer-text { display: flex; flex-direction: column; gap: calc(8 * var(--u)); padding: calc(12 * var(--u)) calc(44 * var(--u)) calc(12 * var(--u)) calc(16 * var(--u)); font-size: calc(11 * var(--u)); line-height: calc(16 * var(--u)); animation: how-paste-text var(--how-cycle) var(--ease-out) infinite; }
.prompt-path { color: var(--color-ink-2); font: calc(10 * var(--u))/calc(16 * var(--u)) var(--font-mono); white-space: nowrap; }
.send-button { position: absolute; right: calc(10 * var(--u)); bottom: calc(10 * var(--u)); display: flex; align-items: center; justify-content: center; width: calc(28 * var(--u)); height: calc(28 * var(--u)); border-radius: var(--radius-full); background: var(--surface-red); box-shadow: var(--shadow-red); color: var(--color-clean-bg); animation: how-send var(--how-cycle) var(--ease-out) infinite; }
.send-button svg { width: calc(12 * var(--u)); height: calc(12 * var(--u)); fill: none; stroke: currentColor; stroke-width: 1.6; stroke-linecap: round; stroke-linejoin: round; }
.paste .key-hud { top: calc(150 * var(--u)); animation: how-paste-hud var(--how-cycle) var(--ease-spring) infinite; }
.paste .hud-keys :global(.key-chip) { animation: how-paste-key var(--how-cycle) var(--ease-out) infinite; }
.paste .cursor { opacity: 0; translate: calc(200 * var(--u)) calc(316 * var(--u)); animation: how-paste-cursor var(--how-cycle) var(--ease-out) infinite; }
.paste .cursor-arrow { animation: how-click var(--how-cycle) var(--ease-out) infinite; }

/* 時刻は 8 秒の周期に対する割合（10% = 0.8 秒）。 */
@keyframes how-progress {
  from { transform: scaleX(0); }
  to { transform: scaleX(1); }
}
@keyframes how-blink {
  50% { opacity: 0; }
}

/* 01（4 秒）: 0.9 秒で ⌘⇧6 を押す → 1.1〜1.8 秒で案内と操作ボタンが出て、カーソルが十字になる（カーソルは動かさない） → 3.7 秒で消えて始めに戻る。 */
@keyframes how-press-hud {
  0%, 8% { opacity: 0; scale: var(--motion-pop-scale); }
  14%, 32% { opacity: 1; scale: 1; }
  40%, 100% { opacity: 0; scale: 1; }
}
@keyframes how-press-key {
  0%, 20% { scale: 1; }
  23% { scale: .9; }
  28%, 100% { scale: 1; }
}
@keyframes how-press-hint {
  0%, 28% { opacity: 0; translate: -50% calc(-12 * var(--u)); scale: .96; }
  38%, 84% { opacity: 1; translate: -50% 0; scale: 1; }
  92%, 100% { opacity: 0; translate: -50% calc(-12 * var(--u)); scale: .96; }
}
@keyframes how-press-toolbar {
  0%, 31% { opacity: 0; translate: -50% calc(16 * var(--u)); scale: var(--motion-pop-scale); }
  44%, 84% { opacity: 1; translate: -50% 0; scale: 1; }
  92%, 100% { opacity: 0; translate: -50% calc(8 * var(--u)); scale: 1; }
}
@keyframes how-press-arrow {
  0% { opacity: 1; }
  28% { opacity: 0; }
  92% { opacity: 1; }
}
@keyframes how-press-crosshair {
  0% { opacity: 0; }
  28% { opacity: 1; }
  92% { opacity: 0; }
}

/* 02: 0.6〜1.9 秒で枠を描く → 2.2 秒でコメント入力が出る → 2.8〜4.6 秒で書く → 5.1 秒で ↵ → 5.6 秒で消え、また枠を描く状態に戻る。 */
@keyframes how-annotate-hint {
  0%, 22% { opacity: 1; translate: -50% 0; scale: 1; }
  27%, 74% { opacity: 0; translate: -50% calc(-12 * var(--u)); scale: .96; }
  80%, 100% { opacity: 1; translate: -50% 0; scale: 1; }
}
@keyframes how-frame {
  0%, 7% { opacity: 0; width: 0; height: 0; scale: 1; }
  8% { opacity: 1; width: 0; height: 0; scale: 1; animation-timing-function: linear; }
  24% { opacity: 1; width: calc(94 * var(--u)); height: calc(38 * var(--u)); scale: 1; }
  26% { scale: 1.015; }
  28%, 68% { opacity: 1; width: calc(94 * var(--u)); height: calc(38 * var(--u)); scale: 1; }
  72%, 100% { opacity: 0; width: calc(94 * var(--u)); height: calc(38 * var(--u)); scale: 1; }
}
@keyframes how-annotate-cursor {
  0%, 8% { translate: calc(335 * var(--u)) calc(114 * var(--u)); animation-timing-function: linear; }
  24%, 74% { translate: calc(429 * var(--u)) calc(152 * var(--u)); }
  92%, 100% { translate: calc(335 * var(--u)) calc(114 * var(--u)); }
}
@keyframes how-size-label {
  0%, 7% { opacity: 0; translate: calc(-94 * var(--u)) calc(-38 * var(--u)); }
  8% { opacity: 1; translate: calc(-94 * var(--u)) calc(-38 * var(--u)); animation-timing-function: linear; }
  24% { opacity: 1; translate: 0 0; }
  25%, 100% { opacity: 0; translate: 0 0; }
}
@keyframes how-comment {
  0%, 27% { opacity: 0; translate: 0 calc(12 * var(--u)); scale: var(--motion-pop-scale); }
  31%, 66% { opacity: 1; translate: 0 0; scale: 1; }
  70%, 100% { opacity: 0; translate: 0 0; scale: .96; }
}
@keyframes how-placeholder {
  0% { opacity: 1; }
  35% { opacity: 0; }
}
@keyframes how-typing {
  0%, 35% { clip-path: inset(0 100% 0 0); animation-timing-function: steps(12, end); }
  57%, 100% { clip-path: inset(0); }
}
@keyframes how-caret-move {
  0%, 35% { left: 0; animation-timing-function: steps(12, end); }
  57%, 100% { left: 100%; }
}
@keyframes how-done-key {
  0%, 62%, 66%, 100% { scale: 1; }
  64% { scale: .86; }
}

/* 03: 1 秒でコピーを押す → 1.3〜2.8 秒「コピーしました！」→ 3〜3.4 秒で AI のチャットへ → 4.3 秒で ⌘V → 7.4 秒で始めに戻る。 */
@keyframes how-paste-toolbar {
  0%, 15% { opacity: 1; translate: -50% 0; scale: 1; }
  17%, 92% { opacity: 0; translate: -50% 0; scale: .96; }
  98%, 100% { opacity: 1; translate: -50% 0; scale: 1; }
}
@keyframes how-press-copy {
  0%, 12%, 16%, 100% { scale: 1; }
  14% { scale: .95; }
}
@keyframes how-toast {
  0%, 16% { opacity: 0; translate: -50% calc(6 * var(--u)); scale: .9; }
  19% { opacity: 1; translate: -50% 0; scale: 1.03; }
  21%, 33% { opacity: 1; translate: -50% 0; scale: 1; }
  36%, 100% { opacity: 0; translate: -50% 0; scale: .96; }
}
@keyframes how-check {
  0%, 17% { stroke-dashoffset: 1; }
  21%, 100% { stroke-dashoffset: 0; }
}
@keyframes how-chat {
  0%, 36% { opacity: 0; translate: 0 calc(28 * var(--u)); scale: .96; }
  42%, 90% { opacity: 1; translate: 0 0; scale: 1; }
  96%, 100% { opacity: 0; translate: 0 0; scale: 1; }
}
@keyframes how-paste-cursor {
  0% { opacity: 1; translate: calc(250 * var(--u)) calc(210 * var(--u)); }
  4% { opacity: 1; translate: calc(250 * var(--u)) calc(210 * var(--u)); }
  12%, 36% { opacity: 1; translate: calc(344 * var(--u)) calc(318 * var(--u)); }
  44%, 53% { opacity: 1; translate: calc(200 * var(--u)) calc(316 * var(--u)); }
  55%, 94% { opacity: 0; translate: calc(200 * var(--u)) calc(316 * var(--u)); }
  100% { opacity: 1; translate: calc(250 * var(--u)) calc(210 * var(--u)); }
}
@keyframes how-click {
  0%, 12.5%, 15%, 45.5%, 48%, 100% { scale: 1; }
  13.5%, 46.5% { scale: .86; }
}
@keyframes how-composer {
  0%, 46% { height: calc(46 * var(--u)); box-shadow: var(--shadow-white), 0 0 0 0 transparent; }
  47%, 54% { height: calc(46 * var(--u)); box-shadow: var(--shadow-white), 0 0 0 calc(3 * var(--u)) var(--color-red-halo); }
  59%, 100% { height: calc(196 * var(--u)); box-shadow: var(--shadow-white), 0 0 0 calc(3 * var(--u)) var(--color-red-halo); }
}
@keyframes how-composer-placeholder {
  0% { opacity: 1; }
  54% { opacity: 0; }
}
@keyframes how-paste-text {
  0%, 54% { opacity: 0; background: transparent; }
  55% { opacity: 1; background: var(--color-paste-flash); }
  64%, 100% { opacity: 1; background: transparent; }
}
@keyframes how-send {
  0%, 55% { background: var(--color-clean-surface); box-shadow: none; color: var(--color-steel); }
  57%, 100% { background: var(--surface-red); box-shadow: var(--shadow-red); color: var(--color-clean-bg); }
}
@keyframes how-paste-hud {
  0%, 48% { opacity: 0; translate: -50% calc(12 * var(--u)); scale: var(--motion-pop-scale); }
  51%, 58% { opacity: 1; translate: -50% 0; scale: 1; }
  62%, 100% { opacity: 0; translate: -50% 0; scale: .96; }
}
@keyframes how-paste-key {
  0%, 53%, 56%, 100% { scale: 1; }
  54.5% { scale: .9; }
}

/* 3 枚を横に並べる幅がないときは、縦に積む。 */
@media (max-width: 959px) {
  .steps { grid-template-columns: minmax(0, 1fr); gap: var(--how-stack-gap); max-width: var(--how-stack-width); }
}
@media (max-width: 767px) {
  h2 { display: flex; flex-direction: column; align-items: center; gap: var(--how-phrase-stack-gap); }
}
</style>
