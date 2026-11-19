<script lang="ts">
  import '@fontsource/ibm-plex-mono/400.css';
  import '../app.css';
  let { children } = $props();
</script>

{@render children()}

<style>
  /* 1280×800 の撮影枠いっぱいにデモだけを置く。 */
  :global(body) { margin: 0; background: transparent; }
</style>
