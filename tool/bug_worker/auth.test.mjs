// Tests for accounts (auth.js): a passkey made and signed in with, by a
// pretend authenticator; Google's round trip, with Google pretended; and
// everything a stranger might try turned away.   node --test tool/bug_worker/
import test from "node:test";
import assert from "node:assert/strict";
import { handleAuth, b64u } from "./auth.js";

const GAME = "https://kings-court-c8n.pages.dev";
const HOMES = [GAME, "https://samwisee.github.io"];
const SERVICE = "https://kings-court-bugs.example.workers.dev";
const env = { GOOGLE_CLIENT_ID: "client-1", GOOGLE_CLIENT_SECRET: "shh" };

function memStore() {
  const challenges = new Map(), logins = new Map(), accounts = new Map(), sessions = new Map(), players = new Map();
  return {
    challenges, players, sessions,
    async putChallenge(id, kind, value, ttl) { challenges.set(id, { kind, value, expires: Date.now() + ttl }); },
    async takeChallenge(id, kind) {
      const c = challenges.get(id);
      if (!c || c.kind !== kind) return null;
      challenges.delete(id);
      return c.expires >= Date.now() ? c.value : null;
    },
    async login(kind, subject) { return logins.get(kind + " " + subject) ?? null; },
    async addLogin(l) { logins.set(l.kind + " " + l.subject, { counter: 0, ...l, added: new Date().toISOString() }); },
    async setCounter(kind, subject, counter) { logins.get(kind + " " + subject).counter = counter; },
    async logins(account) { return [...logins.values()].filter((l) => l.account === account).map(({ kind, added }) => ({ kind, added })); },
    async account(id) { return accounts.get(id) ?? null; },
    async addAccount(id, name) { accounts.set(id, { id, name, owns: "[]", look: null }); },
    async setAccount(id, change) { Object.assign(accounts.get(id), change); },
    async session(hash) { return sessions.get(hash) ?? null; },
    async addSession(hash, account) { sessions.set(hash, account); },
    async dropSession(hash) { sessions.delete(hash); },
    async linkPlayer(player, account) { players.set(player, account); },
  };
}

function ask(store, path, { body, token, origin = GAME, query = "" } = {}) {
  const headers = new Headers({ "Content-Type": "application/json" });
  if (token) headers.set("Authorization", "Bearer " + token);
  const request = new Request(SERVICE + path + query, { method: body === undefined ? "GET" : "POST", headers, body: body === undefined ? undefined : JSON.stringify(body) });
  return handleAuth(request, env, path, { cors: {}, origin, homes: HOMES }, store);
}
const read = async (r) => ({ status: r.status, ...(await r.json()) });

// A pretend authenticator: a key of its own, answers as a browser would.
async function authenticator(alg = "ES256", host = "kings-court-c8n.pages.dev") {
  const kp = alg === "ES256"
    ? await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"])
    : await crypto.subtle.generateKey({ name: "Ed25519" }, true, ["sign", "verify"]);
  const spki = b64u.from(await crypto.subtle.exportKey("spki", kp.publicKey));
  const id = b64u.from(crypto.getRandomValues(new Uint8Array(16)));
  let count = 0;
  const authData = async (n, flags = 0x05) => {
    const out = new Uint8Array(37);
    out.set(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(host))));
    out[32] = flags;
    new DataView(out.buffer).setUint32(33, n);
    return out;
  };
  const client = (type, challenge, origin = GAME) =>
    new TextEncoder().encode(JSON.stringify({ type, challenge, origin, crossOrigin: false }));
  return {
    id,
    async create(begun, { origin, flags } = {}) {
      return { id: begun.id, credentialId: id, alg: alg === "ES256" ? -7 : -8, publicKey: spki,
        clientDataJSON: b64u.from(client("webauthn.create", begun.challenge, origin)),
        authenticatorData: b64u.from(await authData(0, flags)), player: "00112233445566ff", name: "Ann" };
    },
    async sign(begun, { origin, counter = ++count } = {}) {
      const cd = client("webauthn.get", begun.challenge, origin);
      const ad = await authData(counter);
      const data = new Uint8Array([...ad, ...new Uint8Array(await crypto.subtle.digest("SHA-256", cd))]);
      let sig = new Uint8Array(await crypto.subtle.sign(alg === "ES256" ? { name: "ECDSA", hash: "SHA-256" } : { name: "Ed25519" }, kp.privateKey, data));
      if (alg === "ES256") sig = toDer(sig);
      return { id: begun.id, credentialId: id, clientDataJSON: b64u.from(cd), authenticatorData: b64u.from(ad), signature: b64u.from(sig), player: "aabbccddeeff0011" };
    },
  };
}

function toDer(raw) {
  const int = (b) => {
    let i = 0;
    while (i < b.length - 1 && b[i] === 0) i++;
    b = b.slice(i);
    return b[0] & 0x80 ? [0x02, b.length + 1, 0, ...b] : [0x02, b.length, ...b];
  };
  const body = [...int(raw.slice(0, 32)), ...int(raw.slice(32))];
  return new Uint8Array([0x30, body.length, ...body]);
}

test("A passkey makes an account, signs in to it again, and only it can", async () => {
  const store = memStore();
  for (const alg of ["ES256", "Ed25519"]) {
    const key = await authenticator(alg);
    const made = await read(await ask(store, "/auth/passkey/create", { body: await key.create(await read(await ask(store, "/auth/passkey/begin", { body: {} }))) }));
    assert.equal(made.status, 200, made.error);
    assert.equal(made.me.name, "Ann");
    assert.deepEqual(made.me.logins.map((l) => l.kind), ["passkey"]);
    assert.equal(store.players.get("00112233445566ff"), made.me.id);

    const again = await read(await ask(store, "/auth/passkey/sign", { body: await key.sign(await read(await ask(store, "/auth/passkey/begin", { body: {} }))) }));
    assert.equal(again.status, 200, again.error);
    assert.equal(again.me.id, made.me.id);
    assert.notEqual(again.token, made.token);

    const mine = await read(await ask(store, "/me", { token: again.token }));
    assert.equal(mine.id, made.me.id);

    // Someone else's key, pretending to be this passkey.
    const other = await authenticator(alg);
    const forged = await other.sign(await read(await ask(store, "/auth/passkey/begin", { body: {} })));
    forged.credentialId = key.id;
    assert.equal((await ask(store, "/auth/passkey/sign", { body: forged })).status, 401);
  }
});

test("A passkey's answer from the wrong page, for an old challenge, used twice or replayed is turned away", async () => {
  const store = memStore();
  const key = await authenticator();
  const begun = await read(await ask(store, "/auth/passkey/begin", { body: {} }));
  // Another site's page.
  assert.equal((await ask(store, "/auth/passkey/create", { body: await key.create(begun, { origin: "https://evil.example" }), origin: "https://evil.example" })).status, 401);
  // That challenge is used up.
  assert.equal((await ask(store, "/auth/passkey/create", { body: await key.create(begun) })).status, 401);
  // No one there (no user-present flag).
  assert.equal((await ask(store, "/auth/passkey/create", { body: await key.create(await read(await ask(store, "/auth/passkey/begin", { body: {} })), { flags: 0 }) })).status, 401);
  // Made properly; then a signature whose counter went backwards.
  assert.equal((await ask(store, "/auth/passkey/create", { body: await key.create(await read(await ask(store, "/auth/passkey/begin", { body: {} }))) })).status, 200);
  const begin = async () => read(await ask(store, "/auth/passkey/begin", { body: {} }));
  assert.equal((await ask(store, "/auth/passkey/sign", { body: await key.sign(await begin(), { counter: 5 }) })).status, 200);
  assert.equal((await ask(store, "/auth/passkey/sign", { body: await key.sign(await begin(), { counter: 5 }) })).status, 401);
  // A passkey made for another site's address.
  const elsewhere = await authenticator("ES256", "evil.example");
  assert.equal((await ask(store, "/auth/passkey/create", { body: await elsewhere.create(await begin()) })).status, 401);
});

test("A second passkey is added to the account signed in, and signing out ends the session", async () => {
  const store = memStore();
  const first = await authenticator(), second = await authenticator();
  const made = await read(await ask(store, "/auth/passkey/create", { body: await first.create(await read(await ask(store, "/auth/passkey/begin", { body: {} }))) }));
  const adding = await read(await ask(store, "/auth/passkey/begin", { body: {}, token: made.token }));
  const added = await read(await ask(store, "/auth/passkey/create", { body: await second.create(adding), token: made.token }));
  assert.equal(added.me.id, made.me.id);
  assert.equal(added.me.logins.length, 2);
  // Without the session, the same begin can't be used to add one.
  const stolen = await read(await ask(store, "/auth/passkey/begin", { body: {}, token: made.token }));
  assert.equal((await ask(store, "/auth/passkey/create", { body: await (await authenticator()).create(stolen) })).status, 401);

  const renamed = await read(await ask(store, "/me", { body: { name: "  Lady   Ann <b> ", look: "midnight" }, token: made.token }));
  assert.equal(renamed.name, "Lady Ann b");
  assert.equal(renamed.look, "midnight");
  assert.equal((await ask(store, "/auth/out", { body: {}, token: made.token })).status, 200);
  assert.equal((await ask(store, "/me", { token: made.token })).status, 401);
});

test("Google: off to Google and back to the game's page with a ticket, which is good once for a session", async () => {
  const store = memStore();
  const start = await ask(store, "/auth/google/start", { query: "?back=" + encodeURIComponent(GAME + "/?x=1") });
  assert.equal(start.status, 302);
  const to = new URL(start.headers.get("Location"));
  assert.equal(to.host, "accounts.google.com");
  assert.equal(to.searchParams.get("redirect_uri"), SERVICE + "/auth/google/back");
  const state = to.searchParams.get("state");

  const realFetch = globalThis.fetch;
  const claims = { iss: "https://accounts.google.com", aud: "client-1", sub: "g-42", given_name: "Ben" };
  globalThis.fetch = async (url, init) => {
    assert.equal(String(url), "https://oauth2.googleapis.com/token");
    assert.equal(new URLSearchParams(init.body).get("code"), "the-code");
    const part = (o) => b64u.from(new TextEncoder().encode(JSON.stringify(o)));
    return new Response(JSON.stringify({ id_token: part({ alg: "RS256" }) + "." + part(claims) + ".sig" }));
  };
  try {
    const back = await ask(store, "/auth/google/back", { query: `?code=the-code&state=${state}`, origin: "" });
    assert.equal(back.status, 302);
    const home = new URL(back.headers.get("Location"));
    assert.equal(home.origin, GAME);
    assert.equal(home.searchParams.get("x"), "1");
    const ticket = home.searchParams.get("signin");
    const s = await read(await ask(store, "/auth/ticket", { body: { ticket } }));
    assert.equal(s.me.name, "Ben");
    assert.equal(s.me.logins[0].kind, "google");
    assert.equal((await ask(store, "/auth/ticket", { body: { ticket } })).status, 401);
    // The state is used up too.
    assert.equal((await ask(store, "/auth/google/back", { query: `?code=the-code&state=${state}`, origin: "" })).status, 400);

    // The same person again: the same account.
    const again = new URL((await ask(store, "/auth/google/start", { query: "?back=" + encodeURIComponent(GAME) })).headers.get("Location"));
    const home2 = new URL((await ask(store, "/auth/google/back", { query: `?code=the-code&state=${again.searchParams.get("state")}`, origin: "" })).headers.get("Location"));
    assert.equal((await read(await ask(store, "/auth/ticket", { body: { ticket: home2.searchParams.get("signin") } }))).me.id, s.me.id);

    // A token meant for some other app.
    claims.aud = "someone-else";
    const third = new URL((await ask(store, "/auth/google/start", { query: "?back=" + encodeURIComponent(GAME) })).headers.get("Location"));
    const failed = new URL((await ask(store, "/auth/google/back", { query: `?code=the-code&state=${third.searchParams.get("state")}`, origin: "" })).headers.get("Location"));
    assert.equal(failed.searchParams.get("signin"), "failed");
  } finally {
    globalThis.fetch = realFetch;
  }
  // Only back to the game's own pages.
  assert.equal((await ask(store, "/auth/google/start", { query: "?back=" + encodeURIComponent("https://evil.example/") })).status, 400);
});

test("Which ways in are set up", async () => {
  assert.deepEqual(await (await ask(memStore(), "/auth/config")).json(), { google: true, passkey: true });
});
