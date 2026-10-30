{{flutter_js}}
{{flutter_build_config}}

// No offline copy: a reload always gets the latest build. Older builds
// registered a service worker that could keep serving a stale version, so
// remove any that are still around.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(function (registrations) {
    registrations.forEach(function (r) { r.unregister(); });
  });
}

// The game runs in its box (#game in index.html), sized to what's on
// screen, rather than across the whole window.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      hostElement: document.getElementById('game'),
    });
    await appRunner.runApp();
  },
});
