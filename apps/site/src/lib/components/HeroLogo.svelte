<script lang="ts">
  let { label }: { label: string } = $props();
</script>

<img class="hero-logo" src="/akapen-logo-long.png" alt={label} width="1858" height="578" />

<style>
.hero-logo { display: block; width: 100%; max-width: 820px; height: auto; }
</style>
