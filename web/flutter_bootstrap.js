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

// The game is built twice: as WebAssembly (the skwasm renderer), and as
// JavaScript. WebKit (Safari, and every browser on an iPhone or iPad,
// which are all WebKit underneath) gets the JavaScript: the WebAssembly
// build doesn't start there yet. Everything else gets WebAssembly if it can
// run it (the loader falls back to JavaScript if not).
const ua = navigator.userAgent;
const webkit = /AppleWebKit/.test(ua) && !/(Chrome|Chromium)\//.test(ua);

// When the game's first screen is drawn: the device lab times the page to
// this mark (performance.mark('ready')).
window.addEventListener('flutter-first-frame', function () {
  performance.mark('ready');
}, { once: true });

// The game runs in its box (#game in index.html), sized to what's on
// screen, rather than across the whole window.
_flutter.loader.load({
  config: webkit ? { renderer: 'canvaskit' } : {},
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      hostElement: document.getElementById('game'),
    });
    await appRunner.runApp();
  },
});
