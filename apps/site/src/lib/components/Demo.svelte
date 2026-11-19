<script lang="ts">
  import { messages, type Language } from '$lib/i18n';
  import KeyChip from './KeyChip.svelte';
  // LP の動画（static/demo/）を撮るための絵。LP には直接置かず、scripts/record-demo.mjs が 1 コマずつ止めて撮る。
  let { language }: { language: Language } = $props();
  const text = $derived(messages[language]);
  const promptPath = '/Users/you/Library/Caches/akapen/20261117-1432/';
</script>

<div class="demo-section">
  <div class="demo-container">
    <div aria-hidden="true">
    <div class="desktop">

      <!-- Menu bar -->
      <div class="menubar">
        <svg style="width: calc(13 * var(--demo-unit)); height: calc(15 * var(--demo-unit))" viewBox="0 0 13 15">
          <path d="M10.6 8c0-1.9 1.6-2.8 1.6-2.9-.9-1.3-2.2-1.5-2.7-1.5-1.1-.1-2.2.7-2.8.7-.6 0-1.5-.7-2.4-.6C3 3.7 1.9 4.4 1.3 5.5 0 7.7 1 11 2.2 12.8c.6.9 1.3 1.8 2.2 1.8.9 0 1.2-.6 2.3-.6 1.1 0 1.4.6 2.3.6 1 0 1.6-.9 2.2-1.8.7-1 1-2 1-2.1 0 0-1.6-.6-1.6-2.7zM8.8 2.4c.5-.6.8-1.4.7-2.2-.7 0-1.6.5-2.1 1.1-.5.5-.9 1.4-.8 2.2.8.1 1.6-.4 2.2-1.1z" fill="#121214" />
        </svg>
        <div class="menu-app"><span class="menu-app-sample">{text.demoApp}</span><span class="menu-app-chat">{text.demoChatApp}</span></div>
        <div class="menu-file">{text.demoFile}</div>
        <div class="menu-edit">{text.demoEdit}</div>
        <div class="menu-view">{text.demoView}</div>
        <div class="menu-window">{text.demoWindow}</div>
        <div class="menu-help">{text.demoHelp}</div>
        <div class="menu-spacer"></div>
        <img class="menu-hand" src="/akapen-menubar.png" alt="" />
        <div class="menu-clock">{text.demoClock}</div>
      </div>

      <!-- Window -->
      <div class="sample-window">
        <div class="titlebar">
          <div class="traffic-close"></div>
          <div class="traffic-minimize"></div>
          <div class="traffic-zoom"></div>
          <div class="window-title">{text.demoApp}</div>
        </div>
        <div class="window-body">
          <!-- サイドバー -->
          <div class="sidebar">
            <div class="sidebar-selected">
              <div class="sidebar-label-selected"></div>
            </div>
            <div class="sidebar-item-two">
              <div class="sidebar-label-two"></div>
            </div>
            <div class="sidebar-item-three">
              <div class="sidebar-label-three"></div>
            </div>
            <div class="sidebar-item-four">
              <div class="sidebar-label-four"></div>
            </div>
          </div>
          <!-- 本文（フォームの絵） -->
          <div class="form">
            <div class="form-heading">
              <div class="heading-placeholder"></div>
              <div class="subtitle-placeholder"></div>
            </div>
            <div class="field-one">
              <div class="label-one"></div>
              <div class="input-one"></div>
            </div>
            <div class="field-two">
              <div class="label-two"></div>
              <div class="input-two"></div>
            </div>
            <div class="field-three">
              <div class="label-three"></div>
              <div class="input-three"></div>
            </div>
            <div class="form-divider"></div>
            <div class="form-actions">
              <div class="cancel-button">
                <div class="cancel-label">{messages.en.demoCancel}</div>
              </div>
              <div class="submit-button">
                <div class="submit-label">{text.demoSubmit}</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 貼り付け先の AI チャット -->
      <div class="chat-window">
        <div class="titlebar">
          <div class="traffic-close"></div>
          <div class="traffic-minimize"></div>
          <div class="traffic-zoom"></div>
          <div class="window-title">{text.demoChatApp}</div>
        </div>
        <div class="chat-body">
          <div class="chat-message">
            <div class="chat-avatar"></div>
            <div class="chat-lines">
              <div class="chat-line-one"></div>
              <div class="chat-line-two"></div>
              <div class="chat-line-three"></div>
            </div>
          </div>
          <div class="composer">
            <div class="composer-placeholder">{text.demoChatPlaceholder}<span class="composer-caret"></span></div>
            <div class="composer-text">
              <div>{text.demoPromptIntro}</div>
              <div>{text.demoPromptInstruction}</div>
              <div class="prompt-gap"></div>
              <div class="prompt-path">{promptPath}01.png</div>
              <div>{text.demoEarlierComment}</div>
              <div class="prompt-gap"></div>
              <div class="prompt-path">{promptPath}02.png</div>
              <div>{text.demoComment}</div>
            </div>
            <div class="send-button">
              <svg viewBox="0 0 14 14"><path d="M7 11.5v-9M3 6.5l4-4 4 4" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" /></svg>
            </div>
          </div>
        </div>
      </div>

      <!-- 枠描画中の案内 -->
      <div class="guide-pill"><span class="guide-dot"></span><span>{text.demoGuide}</span><KeyChip dark escape>esc</KeyChip><span class="guide-cancel">{text.demoCancel}</span></div>
      <!-- 赤枠 -->
      <div class="red-frame"></div>

      <!-- Comment input -->
      <div class="comment">
        <div class="comment-text">
          <div class="comment-label">
            <span class="typed-text">{text.demoComment}</span><span class="caret">|</span>
          </div>
        </div>
        <div class="comment-footer">
          <div class="comment-hints">
            <div class="done-hint">
              <KeyChip>↵</KeyChip>
              <span class="hint">{text.demoDone}</span>
            </div>
            <div class="newline-hint">
              <div class="newline-keys">
                <KeyChip>⇧</KeyChip>
                <KeyChip>↵</KeyChip>
              </div>
              <span class="hint">{text.demoNewLine}</span>
            </div>
          </div>
          <div class="cancel-hint">
            <KeyChip escape>esc</KeyChip>
            <span class="hint">{text.demoCancel}</span>
          </div>
        </div>
      </div>

      <!-- Floating bar -->
      <div class="toolbar">
        <div class="trash-button">
          <svg viewBox="0 0 14 14"><path d="M3 4h8M5 4V2.5h4V4M4 4l.5 8h5l.5-8" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round" /></svg>
          <KeyChip>⌘</KeyChip><KeyChip>⌫</KeyChip>
        </div>
        <!-- 一覧 -->
        <div class="list-button">
          <svg style="width: calc(14 * var(--demo-unit)); height: calc(14 * var(--demo-unit))" viewBox="0 0 14 14">
            <path d="M5 3.5h7M5 7h7M5 10.5h7" fill="#000000" stroke="#121214" stroke-width="1.5" stroke-linecap="round" />
            <circle cx="2" cy="3.5" r="1" fill="#121214" />
            <circle cx="2" cy="7" r="1" fill="#121214" />
            <circle cx="2" cy="10.5" r="1" fill="#121214" />
          </svg>
          <div class="list-content">
            <div class="list-label">{text.demoList}</div>
            <div class="list-keys">
              <KeyChip>⌘</KeyChip>
              <KeyChip>L</KeyChip>
            </div>
          </div>
          <!-- 件数のバッジ -->
          <div class="count-badge">
            <div class="count-label count-one">1</div>
            <div class="count-label count-two">2</div>
          </div>
        </div>
        <!-- Copy prompt -->
        <div class="copy-button">
          <div class="copy-content">
            <div class="copy-label">{text.demoCopy}</div>
            <div class="copy-keys">
              <KeyChip dark>⌘</KeyChip>
              <KeyChip dark>C</KeyChip>
            </div>
          </div>
          <div class="copy-icon">
            <svg style="width: calc(13 * var(--demo-unit)); height: calc(13 * var(--demo-unit))" viewBox="0 0 14 14">
              <rect x="4.75" y="4.75" width="7.5" height="7.5" rx="1.6" fill="none" stroke="#FFFFFF" stroke-width="1.5" />
              <path d="M9.25 4.75V3.4c0-.9-.7-1.6-1.6-1.6H3.4c-.9 0-1.6.7-1.6 1.6v4.25c0 .9.7 1.6 1.6 1.6h1.35" fill="none" stroke="#FFFFFF" stroke-width="1.5" stroke-linecap="round" />
            </svg>
          </div>
        </div>
      </div>

      <!-- 貼り付けのキー操作 -->
      <div class="paste-hud"><span class="paste-keys"><KeyChip dark>⌘</KeyChip><KeyChip dark>V</KeyChip></span><span>{text.demoPaste}</span></div>

      <!-- コピー完了とカーソルも絵の一部。読み上げは外側の説明にまとめる。 -->
      <div class="copied-toast">
        <div class="copied-pill">
          <span class="copied-check">
            <svg viewBox="0 0 14 14"><path d="M3 7l2.5 2.5L11 4" pathLength="1" /></svg>
          </span>
          <span class="copied-label">{text.demoCopied}</span>
        </div>
      </div>
      <div class="demo-cursor">
        <svg class="crosshair-cursor" viewBox="0 0 24 24">
          <path d="M12 1v22M1 12h22" fill="none" stroke="white" stroke-width="3" />
          <path d="M12 1v22M1 12h22" fill="none" stroke="black" stroke-width="1" />
        </svg>
        <svg class="arrow-cursor" viewBox="0 0 24 24">
          <path d="M4 2v18l4.8-4.8 3.8 7 3.4-1.9-3.8-6.8H19Z" fill="black" stroke="white" stroke-width="1.3" stroke-linejoin="round" />
        </svg>
      </div>
    </div>
    </div>
  </div>
</div>

<style>
.demo-container { width: 100%; aspect-ratio: 1280 / 800; container-type: inline-size; }
/* 1280×800 の絵は、線・影・文字を含めて同じ比率で縮める。 */
.demo-container > div {
  --demo-unit: calc(100cqw / 1280);
  --spacing-1: calc(4 * var(--demo-unit));
  --spacing-2: calc(8 * var(--demo-unit));
  --spacing-3: calc(12 * var(--demo-unit));
  --spacing-4: calc(16 * var(--demo-unit));
  --spacing-5: calc(20 * var(--demo-unit));
  --spacing-6: calc(24 * var(--demo-unit));
  --spacing-10: calc(40 * var(--demo-unit));
  --spacing-16: calc(64 * var(--demo-unit));
  --spacing-shell: calc(80 * var(--demo-unit));
  --radius-field: calc(8 * var(--demo-unit));
  --radius-media: calc(12 * var(--demo-unit));
  --text-label: calc(12 * var(--demo-unit));
  --text-sm: calc(14 * var(--demo-unit));
  --text-base: calc(17 * var(--demo-unit));
  --text-xl: calc(20 * var(--demo-unit));
}
.hint { color: var(--color-steel); font-size: calc(11 * var(--demo-unit)); line-height: calc(14 * var(--demo-unit)); }
.desktop {
  background-image: linear-gradient(in oklab 160deg, #EEF0F5 0%, #D8DDE6 100%);
  border-radius: calc(16 * var(--demo-unit));
  box-shadow: var(--color-line) calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(1 * var(--demo-unit)), #12121440 calc(0 * var(--demo-unit)) calc(40 * var(--demo-unit)) calc(80 * var(--demo-unit)) calc(-40 * var(--demo-unit));
  flex-shrink: 0;
  height: calc(800 * var(--demo-unit));
  overflow: clip;
  position: relative;
  width: calc(1280 * var(--demo-unit));
}

.menubar {
  align-items: center;
  background-color: #FFFFFFB8;
  display: flex;
  gap: var(--spacing-5);
  height: calc(28 * var(--demo-unit));
  left: calc(0 * var(--demo-unit));
  padding-inline: var(--spacing-4);
  position: absolute;
  top: calc(0 * var(--demo-unit));
  width: calc(1280 * var(--demo-unit));
}

.menu-app {
  color: var(--color-ink);
  font-family: var(--font-sans);
  font-size: calc(13 * var(--demo-unit));
  font-weight: 600;
  line-height: calc(16 * var(--demo-unit));
}

.menu-file {
  color: var(--color-ink);
  font-family: var(--font-sans);
  font-size: calc(13 * var(--demo-unit));
  line-height: calc(16 * var(--demo-unit));
}

.menu-edit {
  color: var(--color-ink);
  font-family: var(--font-sans);
  font-size: calc(13 * var(--demo-unit));
  line-height: calc(16 * var(--demo-unit));
}

.menu-view {
  color: var(--color-ink);
  font-family: var(--font-sans);
  font-size: calc(13 * var(--demo-unit));
  line-height: calc(16 * var(--demo-unit));
}

.menu-window {
  color: var(--color-ink);
  font-family: var(--font-sans);
  font-size: calc(13 * var(--demo-unit));
  line-height: calc(16 * var(--demo-unit));
}

.menu-help {
  color: var(--color-ink);
  font-family: var(--font-sans);
  font-size: calc(13 * var(--demo-unit));
  line-height: calc(16 * var(--demo-unit));
}

.menu-spacer {
  flex-grow: 1;
}

.menu-hand {
  flex-shrink: 0;
  height: calc(17 * var(--demo-unit));
  width: auto;
}

.menu-clock {
  color: var(--color-ink);
  font-family: var(--font-sans);
  font-size: calc(13 * var(--demo-unit));
  line-height: calc(16 * var(--demo-unit));
}

.sample-window {
  background-color: var(--color-clean-bg);
  border-radius: var(--radius-media);
  box-shadow: #0000004D calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(0.5 * var(--demo-unit)), #00000040 calc(0 * var(--demo-unit)) calc(24 * var(--demo-unit)) calc(60 * var(--demo-unit));
  display: flex;
  flex-direction: column;
  height: calc(660 * var(--demo-unit));
  left: calc(140 * var(--demo-unit));
  overflow: clip;
  position: absolute;
  top: calc(64 * var(--demo-unit));
  width: calc(1000 * var(--demo-unit));
}

.titlebar {
  align-items: center;
  background-color: #F6F6F8;
  border-bottom: calc(1 * var(--demo-unit)) solid #00000014;
  display: flex;
  flex-shrink: 0;
  gap: var(--spacing-2);
  height: calc(52 * var(--demo-unit));
  padding-inline: var(--spacing-5);
  position: relative;
}

.traffic-close {
  background-color: #FF5F57;
  border-radius: calc(6 * var(--demo-unit));
  height: calc(12 * var(--demo-unit));
  width: calc(12 * var(--demo-unit));
}

.traffic-minimize {
  background-color: #FEBC2E;
  border-radius: calc(6 * var(--demo-unit));
  height: calc(12 * var(--demo-unit));
  width: calc(12 * var(--demo-unit));
}

.traffic-zoom {
  background-color: #28C840;
  border-radius: calc(6 * var(--demo-unit));
  height: calc(12 * var(--demo-unit));
  width: calc(12 * var(--demo-unit));
}

.window-title {
  color: #000000;
  font-family: var(--font-sans);
  font-size: calc(13 * var(--demo-unit));
  font-weight: 600;
  left: calc(0 * var(--demo-unit));
  line-height: calc(52 * var(--demo-unit));
  position: absolute;
  right: calc(0 * var(--demo-unit));
  text-align: center;
}

.window-body {
  display: flex;
  flex-grow: 1;
}

.sidebar {
  background-color: #F4F4F6;
  border-right: calc(1 * var(--demo-unit)) solid #00000014;
  display: flex;
  flex-direction: column;
  flex-shrink: 0;
  gap: calc(2 * var(--demo-unit));
  padding-block: var(--spacing-4);
  padding-inline: var(--spacing-2);
  width: calc(200 * var(--demo-unit));
}

.sidebar-selected {
  align-items: center;
  background-color: #00000012;
  border-radius: calc(6 * var(--demo-unit));
  display: flex;
  height: calc(28 * var(--demo-unit));
  padding-inline: var(--spacing-3);
}

.sidebar-label-selected {
  background-color: #AEAEB2;
  border-radius: calc(4 * var(--demo-unit));
  height: calc(8 * var(--demo-unit));
  width: calc(72 * var(--demo-unit));
}

.sidebar-item-two {
  align-items: center;
  display: flex;
  height: calc(28 * var(--demo-unit));
  padding-inline: var(--spacing-3);
}

.sidebar-label-two {
  background-color: #D1D1D6;
  border-radius: calc(4 * var(--demo-unit));
  height: calc(8 * var(--demo-unit));
  width: calc(96 * var(--demo-unit));
}

.sidebar-item-three {
  align-items: center;
  display: flex;
  height: calc(28 * var(--demo-unit));
  padding-inline: var(--spacing-3);
}

.sidebar-label-three {
  background-color: #D1D1D6;
  border-radius: calc(4 * var(--demo-unit));
  height: calc(8 * var(--demo-unit));
  width: calc(60 * var(--demo-unit));
}

.sidebar-item-four {
  align-items: center;
  display: flex;
  height: calc(28 * var(--demo-unit));
  padding-inline: var(--spacing-3);
}

.sidebar-label-four {
  background-color: #D1D1D6;
  border-radius: calc(4 * var(--demo-unit));
  height: calc(8 * var(--demo-unit));
  width: calc(84 * var(--demo-unit));
}

.form {
  display: flex;
  flex-direction: column;
  flex-grow: 1;
  gap: var(--spacing-5);
  padding-block: calc(36 * var(--demo-unit));
  padding-inline: var(--spacing-10);
}

.form-heading {
  display: flex;
  flex-direction: column;
  gap: calc(10 * var(--demo-unit));
}

.heading-placeholder {
  background-color: #C7C7CC;
  border-radius: calc(7 * var(--demo-unit));
  height: calc(14 * var(--demo-unit));
  width: calc(180 * var(--demo-unit));
}

.subtitle-placeholder {
  background-color: #E5E5EA;
  border-radius: calc(4 * var(--demo-unit));
  height: calc(8 * var(--demo-unit));
  width: calc(320 * var(--demo-unit));
}

.field-one {
  display: flex;
  flex-direction: column;
  gap: calc(6 * var(--demo-unit));
  padding-top: calc(10 * var(--demo-unit));
}

.label-one {
  background-color: #D1D1D6;
  border-radius: calc(4 * var(--demo-unit));
  height: calc(8 * var(--demo-unit));
  width: calc(110 * var(--demo-unit));
}

.input-one {
  border-radius: calc(6 * var(--demo-unit));
  box-shadow: #00000029 calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(1 * var(--demo-unit)) inset;
  height: calc(30 * var(--demo-unit));
  width: calc(420 * var(--demo-unit));
}

.field-two {
  display: flex;
  flex-direction: column;
  gap: calc(6 * var(--demo-unit));
}

.label-two {
  background-color: #D1D1D6;
  border-radius: calc(4 * var(--demo-unit));
  height: calc(8 * var(--demo-unit));
  width: calc(80 * var(--demo-unit));
}

.input-two {
  border-radius: calc(6 * var(--demo-unit));
  box-shadow: #00000029 calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(1 * var(--demo-unit)) inset;
  height: calc(72 * var(--demo-unit));
  width: calc(560 * var(--demo-unit));
}

.field-three {
  display: flex;
  flex-direction: column;
  gap: calc(6 * var(--demo-unit));
}

.label-three {
  background-color: #D1D1D6;
  border-radius: calc(4 * var(--demo-unit));
  height: calc(8 * var(--demo-unit));
  width: calc(90 * var(--demo-unit));
}

.input-three {
  border-radius: calc(6 * var(--demo-unit));
  box-shadow: #00000029 calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(1 * var(--demo-unit)) inset;
  height: calc(30 * var(--demo-unit));
  width: calc(320 * var(--demo-unit));
}

.form-divider {
  background-color: #0000001A;
  height: calc(1 * var(--demo-unit));
  margin-top: var(--spacing-3);
}

.form-actions {
  display: flex;
  gap: var(--spacing-2);
  justify-content: end;
}

.cancel-button {
  align-items: center;
  border-radius: calc(6 * var(--demo-unit));
  box-shadow: #00000029 calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(1 * var(--demo-unit)) inset;
  display: flex;
  height: calc(30 * var(--demo-unit));
  justify-content: center;
  width: calc(76 * var(--demo-unit));
}

.cancel-label {
  color: #000000;
  font-family: var(--font-sans);
  font-size: calc(13 * var(--demo-unit));
  line-height: calc(16 * var(--demo-unit));
}

.submit-button {
  align-items: center;
  background-color: #0A64D2;
  border-radius: calc(6 * var(--demo-unit));
  display: flex;
  height: calc(30 * var(--demo-unit));
  justify-content: center;
  width: calc(92 * var(--demo-unit));
}

.submit-label {
  color: var(--color-clean-bg);
  font-family: var(--font-sans);
  font-size: calc(13 * var(--demo-unit));
  font-weight: 500;
  line-height: calc(16 * var(--demo-unit));
}

.red-frame {
  border: calc(3 * var(--demo-unit)) solid var(--color-accent);
  border-radius: calc(6 * var(--demo-unit));
  box-shadow: #FF3E3E26 calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(4 * var(--demo-unit));
  height: calc(56 * var(--demo-unit));
  left: calc(910 * var(--demo-unit));
  position: absolute;
  top: calc(468 * var(--demo-unit));
  width: calc(204 * var(--demo-unit));
}

.comment {
  background-color: var(--color-clean-bg);
  border-radius: var(--radius-media);
  box-shadow: #0000002E calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(0.5 * var(--demo-unit)), #00000040 calc(0 * var(--demo-unit)) calc(16 * var(--demo-unit)) calc(40 * var(--demo-unit)) calc(-8 * var(--demo-unit));
  display: flex;
  flex-direction: column;
  left: calc(814 * var(--demo-unit));
  position: absolute;
  top: calc(536 * var(--demo-unit));
  width: calc(300 * var(--demo-unit));
}

.comment-text {
  padding-bottom: calc(10 * var(--demo-unit));
  padding-inline: var(--spacing-4);
  padding-top: calc(14 * var(--demo-unit));
}

.comment-label {
  color: var(--color-ink);
  font-family: var(--font-sans);
  font-size: var(--text-sm);
  line-height: calc(21 * var(--demo-unit));
}

.caret {
  color: var(--color-accent);
}

.comment-footer {
  align-items: center;
  border-top: calc(1 * var(--demo-unit)) solid var(--color-line);
  display: flex;
  justify-content: space-between;
  padding-block: var(--spacing-2);
  padding-inline: var(--spacing-4);
}

.comment-hints {
  align-items: center;
  display: flex;
  gap: var(--spacing-3);
}

.done-hint {
  align-items: center;
  display: flex;
  gap: calc(6 * var(--demo-unit));
}

.newline-hint {
  align-items: center;
  display: flex;
  gap: calc(6 * var(--demo-unit));
}

.newline-keys {
  align-items: center;
  display: flex;
  gap: calc(2 * var(--demo-unit));
}

.cancel-hint {
  align-items: center;
  display: flex;
  gap: calc(6 * var(--demo-unit));
}

.toolbar {
  align-items: center;
  background-color: #FFFFFFE6;
  border-radius: var(--radius-full);
  box-shadow: #0000002E calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(0.5 * var(--demo-unit)), #00000040 calc(0 * var(--demo-unit)) calc(12 * var(--demo-unit)) calc(32 * var(--demo-unit)) calc(-8 * var(--demo-unit));
  display: flex;
  gap: calc(6 * var(--demo-unit));
  left: calc(480 * var(--demo-unit));
  padding: calc(6 * var(--demo-unit));
  position: absolute;
  top: calc(736 * var(--demo-unit));
}

.list-button {
  align-items: center;
  background-color: var(--color-clean-surface);
  border-radius: var(--radius-full);
  display: flex;
  gap: var(--spacing-2);
  height: calc(36 * var(--demo-unit));
  padding-inline: calc(14 * var(--demo-unit));
  position: relative;
}

.list-content {
  align-items: center;
  display: flex;
  gap: calc(6 * var(--demo-unit));
}

.list-label {
  color: var(--color-ink);
  font-family: var(--font-sans);
  font-size: calc(13 * var(--demo-unit));
  font-weight: 500;
  line-height: calc(16 * var(--demo-unit));
}

.list-keys {
  align-items: center;
  display: flex;
  gap: calc(2 * var(--demo-unit));
}

.count-badge {
  align-items: center;
  background-color: var(--color-accent);
  border-radius: var(--radius-full);
  box-shadow: var(--color-clean-bg) calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(0 * var(--demo-unit)) calc(2 * var(--demo-unit));
  display: flex;
  height: calc(18 * var(--demo-unit));
  justify-content: center;
  min-width: calc(18 * var(--demo-unit));
  padding-inline: calc(5 * var(--demo-unit));
  position: absolute;
  right: calc(-6 * var(--demo-unit));
  top: calc(-6 * var(--demo-unit));
}

.count-label {
  color: var(--color-clean-bg);
  font-family: var(--font-sans);
  font-size: calc(11 * var(--demo-unit));
  font-weight: 600;
  line-height: calc(18 * var(--demo-unit));
}

.copy-button {
  align-items: center;
  background-color: var(--color-ink);
  border-radius: var(--radius-full);
  display: flex;
  gap: calc(10 * var(--demo-unit));
  height: calc(36 * var(--demo-unit));
  padding-left: var(--spacing-4);
  padding-right: var(--spacing-1);
}

.copy-content {
  align-items: center;
  display: flex;
  gap: calc(6 * var(--demo-unit));
}

.copy-label {
  color: var(--color-clean-bg);
  font-family: var(--font-sans);
  font-size: calc(13 * var(--demo-unit));
  font-weight: 500;
  line-height: calc(16 * var(--demo-unit));
}

.copy-keys {
  align-items: center;
  display: flex;
  gap: calc(2 * var(--demo-unit));
}

.copy-icon {
  align-items: center;
  background-color: var(--color-accent);
  border-radius: var(--radius-full);
  display: flex;
  flex-shrink: 0;
  height: calc(28 * var(--demo-unit));
  justify-content: center;
  width: calc(28 * var(--demo-unit));
}

/* 撮影用の絵。時間の流れはすべて下の @keyframes が決める。 */
.comment-label { display: inline-block; position: relative; white-space: nowrap; }
.typed-text { display: inline-block; }
.caret { position: absolute; left: 100%; top: 0; }
.count-badge { display: grid; }
.count-label { grid-area: 1 / 1; }
.copied-toast {
  position: absolute;
  left: 50%;
  top: calc(736 * var(--demo-unit));
  padding: calc(6 * var(--demo-unit));
  border-radius: var(--radius-full);
  background: #FFFFFFE6;
  box-shadow: #0000002E 0 0 0 calc(.5 * var(--demo-unit)), #00000040 0 calc(12 * var(--demo-unit)) calc(32 * var(--demo-unit)) calc(-8 * var(--demo-unit));
  transform: translateX(-50%);
}
.copied-pill {
  display: flex;
  align-items: center;
  gap: calc(10 * var(--demo-unit));
  height: calc(36 * var(--demo-unit));
  padding-left: calc(4 * var(--demo-unit));
  padding-right: calc(18 * var(--demo-unit));
  border-radius: var(--radius-full);
  background: var(--color-ink);
}
.copied-check {
  display: flex;
  align-items: center;
  justify-content: center;
  width: calc(28 * var(--demo-unit));
  height: calc(28 * var(--demo-unit));
  border-radius: var(--radius-full);
  background: #1F9D55;
}
.copied-check svg { width: calc(13 * var(--demo-unit)); height: calc(13 * var(--demo-unit)); }
.copied-check path { fill: none; stroke: white; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; }
.copied-label { color: var(--color-clean-bg); font-size: calc(13 * var(--demo-unit)); font-weight: 500; line-height: calc(16 * var(--demo-unit)); }
.demo-cursor { position: absolute; width: calc(24 * var(--demo-unit)); height: calc(24 * var(--demo-unit)); pointer-events: none; }
.demo-cursor svg { position: absolute; width: 100%; height: 100%; }
.crosshair-cursor { transform: translate(-50%, -50%); }
.arrow-cursor { transform: translate(-16.667%, -8.333%); }

/*
  18 秒で 1 回だけ流す（--demo-cycle）。
  0〜6.7%: 待機 → 15.3%: 枠を描き終える → 18.7〜32.7%: 入力 → 36.7%: 確定
  → 47.7%: コピーを押す → 48.7〜62%: コピー完了 → 63〜67%: AI チャットへ切り替え
  → 69%: 入力欄をクリック → 72.5%: ⌘V → 73%: 貼り付け → 100% まで止めて見せる。
*/
.red-frame { transform-origin: top left; animation: draw-frame var(--demo-cycle) linear both; }
.comment { animation: show-comment var(--demo-cycle) var(--ease-spring) both; }
.typed-text { animation: type-comment var(--demo-cycle) var(--ease-out) both; }
.caret { animation: move-caret var(--demo-cycle) var(--ease-out) both, blink-caret var(--motion-caret) steps(1) infinite; }
.count-one { animation: first-count var(--demo-cycle) steps(1) both; }
.count-two { animation: second-count var(--demo-cycle) steps(1) both; }
.count-badge { animation: count-bounce var(--demo-cycle) var(--ease-out) both; }
.toolbar { animation: show-toolbar var(--demo-cycle) var(--ease-spring) both; }
.guide-pill { animation: show-guide var(--demo-cycle) var(--ease-out) both; }
.red-frame::after { animation: frame-ring var(--demo-cycle) var(--ease-out) both; }
.copy-button { animation: press-copy var(--demo-cycle) var(--ease-out) both; }
.demo-cursor { animation: move-cursor var(--demo-cycle) var(--ease-out) both; }
.crosshair-cursor { animation: crosshair-visible var(--demo-cycle) steps(1) both; }
.arrow-cursor { animation: arrow-visible var(--demo-cycle) steps(1) both, click-cursor var(--demo-cycle) var(--ease-out) both; }
.copied-toast { animation: show-copied var(--demo-cycle) var(--ease-out) both; }
.copied-check path { stroke-dasharray: 1; animation: draw-check var(--demo-cycle) var(--ease-out) both; }
.copied-label { animation: show-copied-label var(--demo-cycle) var(--ease-out) both; }
.menu-app-sample { animation: hide-at-switch var(--demo-cycle) steps(1) both; }
.menu-app-chat { animation: show-at-switch var(--demo-cycle) steps(1) both; }
.chat-window { animation: show-chat var(--demo-cycle) var(--ease-spring) both; }
.composer { animation: focus-composer var(--demo-cycle) var(--ease-out) both, grow-composer var(--demo-cycle) var(--ease-spring) both; }
.composer-placeholder { animation: hide-placeholder var(--demo-cycle) steps(1) both; }
.composer-caret { animation: show-composer-caret var(--demo-cycle) steps(1) both, blink-caret var(--motion-caret) steps(1) infinite; }
.composer-text { animation: paste-text var(--demo-cycle) var(--ease-out) both; }
.paste-hud { animation: show-paste-hud var(--demo-cycle) var(--ease-out) both; }
.paste-keys { animation: press-paste var(--demo-cycle) var(--ease-out) both; }
.send-button { animation: enable-send var(--demo-cycle) var(--ease-out) both; }

@keyframes draw-frame {
  0%, 6.67% { opacity: 0; transform: scale(0); }
  6.73% { opacity: 1; transform: scale(0); }
  15.33% { opacity: 1; transform: scale(1); }
  16.33% { transform: scale(1.015); }
  17.33%, 36.6% { opacity: 1; transform: scale(1); }
  36.67%, 100% { opacity: 0; transform: scale(1); }
}
@keyframes show-comment {
  0%, 16% { opacity: 0; transform: translateY(var(--demo-pop-shift)) scale(var(--motion-pop-scale)); filter: blur(var(--demo-pop-blur)); }
  18% { opacity: 1; transform: translateY(0) scale(1.02); filter: blur(0); }
  19.33%, 36.6% { opacity: 1; transform: translateY(0) scale(1); filter: blur(0); }
  36.67%, 100% { opacity: 0; transform: translateY(0); }
}
@keyframes type-comment {
  0%, 18.67% { clip-path: inset(0 100% 0 0); animation-timing-function: steps(29, end); }
  32.67%, 100% { clip-path: inset(0 0 0 0); }
}
@keyframes move-caret {
  0%, 18.67% { left: 0; animation-timing-function: steps(29, end); }
  32.67%, 100% { left: 100%; }
}
@keyframes blink-caret { 0%, 100% { opacity: 1; } 50% { opacity: 0; } }
@keyframes first-count { 0% { opacity: 1; } 36.67%, 100% { opacity: 0; } }
@keyframes second-count { 0% { opacity: 0; } 36.67%, 100% { opacity: 1; } }
@keyframes count-bounce { 0%, 36.6%, 39.33%, 100% { transform: scale(1); } 37.33% { transform: scale(1.25); } 38.33% { transform: scale(.94); } }
@keyframes show-toolbar {
  0% { opacity: 0; transform: translateX(-50%) translateY(var(--demo-pop-shift)) scale(var(--motion-pop-scale)); filter: blur(var(--demo-pop-blur)); }
  4%, 48.6% { opacity: 1; transform: translateX(-50%) translateY(0) scale(1); filter: blur(0); }
  48.67%, 100% { opacity: 0; transform: translateX(-50%); }
}
@keyframes show-guide {
  0% { opacity: 0; transform: translate(-50%, calc(-1 * var(--demo-pop-shift))); }
  4%, 36% { opacity: 1; transform: translate(-50%, 0); }
  37.33%, 100% { opacity: 0; transform: translate(-50%, 0); }
}
@keyframes frame-ring { 0%, 15.33% { opacity: 0; } 18%, 100% { opacity: 1; } }
@keyframes press-copy { 0%, 46.67%, 48.67%, 100% { transform: scale(1); } 47.67% { transform: scale(.95); } }
@keyframes move-cursor {
  0%, 6.67% { left: calc(910 * var(--demo-unit)); top: calc(468 * var(--demo-unit)); opacity: 1; animation-timing-function: linear; }
  15.33%, 40% { left: calc(1114 * var(--demo-unit)); top: calc(524 * var(--demo-unit)); opacity: 1; }
  46%, 63% { left: calc(750 * var(--demo-unit)); top: calc(760 * var(--demo-unit)); opacity: 1; }
  68%, 71.9% { left: calc(560 * var(--demo-unit)); top: calc(648 * var(--demo-unit)); opacity: 1; }
  72%, 100% { left: calc(560 * var(--demo-unit)); top: calc(648 * var(--demo-unit)); opacity: 0; }
}
@keyframes crosshair-visible { 0% { opacity: 1; } 40%, 100% { opacity: 0; } }
@keyframes arrow-visible { 0% { opacity: 0; } 40%, 100% { opacity: 1; } }
@keyframes click-cursor {
  0%, 46.9%, 48.4%, 68.6%, 70.1%, 100% { scale: 1; }
  47.5%, 69.2% { scale: .86; }
}
@keyframes show-copied {
  0%, 48.67% { opacity: 0; transform: translate(-50%, calc(6 * var(--demo-unit))) scale(.9); filter: blur(calc(6 * var(--demo-unit))); }
  50.67% { opacity: 1; transform: translate(-50%, 0) scale(1.03); filter: blur(0); }
  52%, 60.67% { opacity: 1; transform: translate(-50%, 0) scale(1); filter: blur(0); }
  62%, 100% { opacity: 0; transform: translate(-50%, 0) scale(.96); filter: blur(calc(4 * var(--demo-unit))); }
}
@keyframes draw-check { 0%, 49.33% { stroke-dashoffset: 1; } 51.33%, 100% { stroke-dashoffset: 0; } }
@keyframes show-copied-label {
  0%, 49.53% { opacity: 0; transform: translateX(calc(-4 * var(--demo-unit))); }
  51.33%, 100% { opacity: 1; transform: translateX(0); }
}
@keyframes hide-at-switch { 0% { opacity: 1; } 64%, 100% { opacity: 0; } }
@keyframes show-at-switch { 0% { opacity: 0; } 64%, 100% { opacity: 1; } }
@keyframes show-chat {
  0%, 63% { opacity: 0; transform: translateY(calc(28 * var(--demo-unit))) scale(.96); filter: blur(calc(8 * var(--demo-unit))); }
  67% { opacity: 1; transform: translateY(0) scale(1); filter: blur(0); }
  100% { opacity: 1; transform: translateY(0) scale(1); filter: blur(0); }
}
@keyframes focus-composer {
  0%, 69% { box-shadow: var(--shadow-white), 0 0 0 0 transparent; }
  70%, 100% { box-shadow: var(--shadow-white), 0 0 0 calc(3 * var(--demo-unit)) var(--color-red-halo); }
}
@keyframes grow-composer {
  0%, 73% { height: var(--composer-closed); }
  76%, 100% { height: var(--composer-open); }
}
@keyframes hide-placeholder { 0% { opacity: 1; } 73%, 100% { opacity: 0; } }
@keyframes show-composer-caret { 0%, 69.2% { visibility: hidden; } 69.3% { visibility: visible; } 73%, 100% { visibility: hidden; } }
@keyframes paste-text {
  0%, 73% { opacity: 0; background-color: transparent; }
  73.4% { opacity: 1; background-color: var(--color-paste-flash); }
  80%, 100% { opacity: 1; background-color: transparent; }
}
@keyframes show-paste-hud {
  0%, 70.5% { opacity: 0; transform: translate(-50%, var(--demo-pop-shift)) scale(var(--motion-pop-scale)); filter: blur(var(--demo-pop-blur)); }
  72%, 77.5% { opacity: 1; transform: translate(-50%, 0) scale(1); filter: blur(0); }
  79.5%, 100% { opacity: 0; transform: translate(-50%, 0) scale(.96); filter: blur(calc(4 * var(--demo-unit))); }
}
@keyframes press-paste { 0%, 72.4%, 73.6%, 100% { transform: scale(1); } 73% { transform: scale(.9); } }
@keyframes enable-send {
  0%, 73.4% { background: var(--color-clean-surface); color: var(--color-steel); box-shadow: none; transform: scale(1); }
  75% { background: var(--surface-red); color: var(--color-clean-bg); box-shadow: var(--shadow-red); transform: scale(1.12); }
  77%, 100% { background: var(--surface-red); color: var(--color-clean-bg); box-shadow: var(--shadow-red); transform: scale(1); }
}

/* 角丸・縁取り・影は LP の動画の枠（DemoVideo.svelte）が付ける。 */
.desktop { border-radius: 0; background: var(--surface-desktop); box-shadow: none; }
.guide-pill { position: absolute; left: 50%; top: var(--demo-guide-top); transform: translateX(-50%); display: flex; align-items: center; gap: var(--spacing-2); padding: var(--spacing-2) var(--spacing-4); border: var(--demo-fine-border) solid var(--color-white-border); border-radius: var(--radius-full); background: var(--surface-ink); box-shadow: var(--shadow-ink); color: var(--color-clean-bg); font-size: var(--demo-guide-font); white-space: nowrap; }
.guide-dot { width: var(--demo-dot-size); height: var(--demo-dot-size); border-radius: var(--radius-full); background: var(--surface-red); box-shadow: 0 0 0 var(--demo-dot-ring) var(--color-red-halo); }
.guide-cancel { color: var(--color-steel); font-size: var(--demo-hint-font); }
.red-frame { border-color: var(--color-accent); border-radius: var(--demo-frame-radius); box-shadow: none; }
.red-frame::after { content: ''; position: absolute; inset: 0; border-radius: inherit; box-shadow: 0 0 0 var(--demo-frame-ring) var(--color-red-halo), var(--shadow-red); pointer-events: none; }
.comment { background: var(--surface-white); border-radius: var(--demo-comment-radius); backdrop-filter: blur(var(--glass-blur)); box-shadow: var(--shadow-glass); transform-origin: top right; }
.toolbar, .copied-toast { left: 50%; top: var(--demo-toolbar-top); padding: var(--demo-toolbar-padding); transform: translateX(-50%); background: var(--surface-glass); backdrop-filter: blur(var(--glass-blur)); box-shadow: var(--shadow-glass); }
.trash-button, .list-button { background: var(--surface-white); box-shadow: var(--shadow-white); height: var(--demo-button-height); }
.trash-button { display: flex; align-items: center; gap: var(--demo-key-gap); padding-inline: var(--spacing-3); border-radius: var(--radius-full); }
.trash-button svg { width: var(--demo-icon-size); height: var(--demo-icon-size); margin-right: var(--spacing-1); }
.copy-button { flex-direction: row-reverse; height: var(--demo-button-height); padding-left: var(--spacing-1); padding-right: var(--spacing-3); background: var(--surface-ink); box-shadow: var(--shadow-ink); }
.copy-icon, .count-badge { background: var(--surface-red); box-shadow: var(--shadow-red); }
.count-badge { outline: var(--demo-fine-border) solid var(--color-clean-bg); }
.copied-pill { background: var(--surface-ink); box-shadow: var(--shadow-ink); }
.copied-check { background: var(--color-success); }
.menu-app { display: grid; }
.menu-app > span { grid-area: 1 / 1; }
.chat-window {
  --composer-closed: calc(56 * var(--demo-unit));
  --composer-open: calc(206 * var(--demo-unit));
  position: absolute;
  left: calc(250 * var(--demo-unit));
  top: calc(92 * var(--demo-unit));
  width: calc(780 * var(--demo-unit));
  height: calc(612 * var(--demo-unit));
  display: flex;
  flex-direction: column;
  overflow: clip;
  border-radius: var(--radius-media);
  background: var(--color-clean-bg);
  box-shadow: #0000004D 0 0 0 calc(.5 * var(--demo-unit)), #00000059 0 calc(30 * var(--demo-unit)) calc(70 * var(--demo-unit));
  transform-origin: 50% 100%;
}
.chat-body { position: relative; flex-grow: 1; background: var(--color-clean-surface); }
.chat-message { display: flex; gap: var(--spacing-3); padding: calc(28 * var(--demo-unit)) calc(32 * var(--demo-unit)); }
.chat-avatar { flex-shrink: 0; width: calc(28 * var(--demo-unit)); height: calc(28 * var(--demo-unit)); border-radius: var(--radius-full); background: var(--surface-ink); }
.chat-lines { display: flex; flex-direction: column; gap: calc(10 * var(--demo-unit)); padding-top: calc(6 * var(--demo-unit)); }
.chat-line-one, .chat-line-two, .chat-line-three { height: calc(8 * var(--demo-unit)); border-radius: calc(4 * var(--demo-unit)); background: #D1D1D6; }
.chat-line-one { width: calc(420 * var(--demo-unit)); }
.chat-line-two { width: calc(360 * var(--demo-unit)); }
.chat-line-three { width: calc(240 * var(--demo-unit)); }
.composer {
  position: absolute;
  left: calc(24 * var(--demo-unit));
  right: calc(24 * var(--demo-unit));
  bottom: calc(24 * var(--demo-unit));
  height: var(--composer-closed);
  overflow: clip;
  border-radius: calc(18 * var(--demo-unit));
  background: var(--color-clean-bg);
  box-shadow: var(--shadow-white);
  outline: calc(1 * var(--demo-unit)) solid var(--color-line);
}
.composer-placeholder {
  position: absolute;
  left: calc(20 * var(--demo-unit));
  top: calc(18 * var(--demo-unit));
  display: flex;
  align-items: center;
  color: var(--color-steel);
  font-size: var(--text-sm);
  line-height: calc(20 * var(--demo-unit));
}
.composer-caret { position: absolute; left: calc(-3 * var(--demo-unit)); width: calc(1.5 * var(--demo-unit)); height: calc(18 * var(--demo-unit)); background: var(--color-accent); }
.composer-text {
  position: absolute;
  left: calc(14 * var(--demo-unit));
  top: calc(12 * var(--demo-unit));
  padding: calc(6 * var(--demo-unit));
  border-radius: calc(6 * var(--demo-unit));
  color: var(--color-ink);
  font-size: calc(13 * var(--demo-unit));
  line-height: calc(20 * var(--demo-unit));
  white-space: nowrap;
}
.prompt-gap { height: calc(10 * var(--demo-unit)); }
.prompt-path { color: var(--color-ink-2); font-family: var(--font-mono); font-size: calc(12 * var(--demo-unit)); }
.send-button {
  position: absolute;
  right: calc(12 * var(--demo-unit));
  bottom: calc(12 * var(--demo-unit));
  display: flex;
  align-items: center;
  justify-content: center;
  width: calc(32 * var(--demo-unit));
  height: calc(32 * var(--demo-unit));
  border-radius: var(--radius-full);
}
.send-button svg { width: calc(14 * var(--demo-unit)); height: calc(14 * var(--demo-unit)); }
.paste-hud { position: absolute; left: 50%; top: calc(724 * var(--demo-unit)); display: flex; align-items: center; gap: var(--spacing-3); padding: calc(10 * var(--demo-unit)) calc(18 * var(--demo-unit)) calc(10 * var(--demo-unit)) calc(12 * var(--demo-unit)); border: var(--demo-fine-border) solid var(--color-white-border); border-radius: var(--radius-full); background: var(--surface-ink); box-shadow: var(--shadow-ink); color: var(--color-clean-bg); font-size: calc(15 * var(--demo-unit)); font-weight: 500; white-space: nowrap; }
.paste-keys { display: flex; gap: calc(3 * var(--demo-unit)); }
.paste-keys :global(.key-chip) { height: calc(26 * var(--demo-unit)); min-width: calc(26 * var(--demo-unit)); font-size: calc(14 * var(--demo-unit)); border-radius: calc(7 * var(--demo-unit)); }
</style>
