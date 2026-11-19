<script lang="ts">
  import type { Snippet } from 'svelte';
  let { children, dark = false, escape = false }: { children: Snippet; dark?: boolean; escape?: boolean } = $props();
</script>

<span class="key-chip" class:dark class:escape>{@render children()}</span>

<style>
.key-chip {
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-clean-bg);
  border-radius: calc(5 * var(--demo-unit));
  box-shadow: var(--shadow-white);
  height: calc(18 * var(--demo-unit));
  min-width: calc(18 * var(--demo-unit));
  padding-inline: calc(4 * var(--demo-unit));
  color: var(--color-ink-2);
  font: 500 calc(11 * var(--demo-unit))/calc(14 * var(--demo-unit)) var(--font-sans);
}
.dark { background: #FFFFFF1F; box-shadow: inset 0 0 0 calc(.5 * var(--demo-unit)) #FFFFFF14; color: #D4D4D8; }
.escape { padding-inline: calc(5 * var(--demo-unit)); }
</style>
