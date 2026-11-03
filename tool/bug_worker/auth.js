// Accounts: signing in to The King's Court with Google or a passkey.
// Playing never needs one; an account keeps what a player owns and wears,
// on every device they sign in on. Nothing else is kept: an id, a name to
// show, the ways in, the devices' anonymous ids (game_log.dart) linked to
// it, and sessions. No email address.
//
//   GET  /auth/config            {google, passkey}: which ways in are set up
//   GET  /auth/google/start      ?back=<the game's page>: off to Google…
//   GET  /auth/google/back       …and back here, then to the game with
//                                ?signin=<ticket> (or ?signin=failed)
//   POST /auth/ticket            {ticket, player} → {token, me}
//   POST /auth/passkey/begin     {} → {id, challenge, user}; with a session,
//                                for adding a passkey to that account
//   POST /auth/passkey/create    a new passkey → {token, me}
//   POST /auth/passkey/sign      signing in with a passkey → {token, me}
//   GET  /me                     the signed-in account
//   POST /me                     {name?, look?}: changes to it
//   POST /auth/out               signs this session out
//
// Sessions are `Authorization: Bearer <token>` (the game and the service
// are on different sites, where browsers drop cookies). Only a hash of a
// token is kept. Google sign-in goes by whole-page redirect: the game's
// page is cross-origin isolated (web/_headers), which breaks Google's
// pop-ups and buttons. Needs GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET.
// Passkeys belong to the game's own address (their relying party is the
// page's host), checked against ALLOW_ORIGIN.

const MINUTE = 60_000;
const NAME_MAX = 24;

// ---- bytes ----------------------------------------------------------------

export const b64u = {
  from(bytes) {
    let s = "";
    for (const b of new Uint8Array(bytes)) s += String.fromCharCode(b);
    return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  },
  to(text) {
    const s = atob(String(text).replace(/-/g, "+").replace(/_/g, "/") + "===".slice((text.length + 3) % 4));
    return Uint8Array.from(s, (c) => c.charCodeAt(0));
  },
};

const random = (n = 32) => b64u.from(crypto.getRandomValues(new Uint8Array(n)));
const sha256 = async (bytes) => new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
const hashToken = async (token) => b64u.from(await sha256(new TextEncoder().encode(token)));
const same = (a, b) => a.length === b.length && a.every((x, i) => x === b[i]);

// ---- storage --------------------------------------------------------------

// The database, as the few things auth asks of it (memStore in the tests).
export function d1Store(db) {
  const one = (sql, ...a) => db.prepare(sql).bind(...a).first();
  const run = (sql, ...a) => db.prepare(sql).bind(...a).run();
  return {
    async putChallenge(id, kind, value, ttl) {
      await run("INSERT INTO challenges (id, kind, value, expires) VALUES (?, ?, ?, ?)", id, kind, value, Date.now() + ttl);
    },
    async takeChallenge(id, kind) {
      const row = await one("SELECT value, expires FROM challenges WHERE id = ? AND kind = ?", String(id), kind);
      if (!row) return null;
      await run("DELETE FROM challenges WHERE id = ? OR expires < ?", String(id), Date.now());
      return row.expires >= Date.now() ? row.value : null;
    },
    login: (kind, subject) => one("SELECT * FROM logins WHERE kind = ? AND subject = ?", kind, subject),
    async addLogin(l) {
      await run("INSERT INTO logins (kind, subject, account, key, alg, counter, added) VALUES (?, ?, ?, ?, ?, ?, ?)",
        l.kind, l.subject, l.account, l.key ?? null, l.alg ?? null, l.counter ?? 0, new Date().toISOString());
    },
    async setCounter(kind, subject, counter) {
      await run("UPDATE logins SET counter = ? WHERE kind = ? AND subject = ?", counter, kind, subject);
    },
    async logins(account) {
      return (await db.prepare("SELECT kind, added FROM logins WHERE account = ? ORDER BY added").bind(account).all()).results;
    },
    account: (id) => one("SELECT * FROM accounts WHERE id = ?", id),
    async addAccount(id, name) {
      await run("INSERT INTO accounts (id, created, name, owns, look) VALUES (?, ?, ?, '[]', NULL)", id, new Date().toISOString(), name);
    },
    async setAccount(id, { name, look }) {
      if (name !== undefined) await run("UPDATE accounts SET name = ? WHERE id = ?", name, id);
      if (look !== undefined) await run("UPDATE accounts SET look = ? WHERE id = ?", look, id);
    },
    async session(hash) {
      return (await one("SELECT account FROM sessions WHERE hash = ?", hash))?.account ?? null;
    },
    async addSession(hash, account) {
      await run("INSERT INTO sessions (hash, account, created) VALUES (?, ?, ?)", hash, account, new Date().toISOString());
    },
    async dropSession(hash) { await run("DELETE FROM sessions WHERE hash = ?", hash); },
    async linkPlayer(player, account) {
      await run("INSERT OR REPLACE INTO account_players (player, account, linked) VALUES (?, ?, ?)", player, account, new Date().toISOString());
    },
  };
}

// ---- requests ---------------------------------------------------------------

export async function handleAuth(request, env, path, { cors, origin, homes }, store = env.DB && d1Store(env.DB)) {
  const json = (body, status = 200) => new Response(JSON.stringify(body), {
    status, headers: { ...cors, "Content-Type": "application/json" },
  });
  const no = (why, status = 400) => json({ error: why }, status);
  if (!store) return no("No database bound", 503);
  const google = Boolean(env.GOOGLE_CLIENT_ID && env.GOOGLE_CLIENT_SECRET);
  const here = new URL(request.url);

  try {
    if (path === "/auth/config") return json({ google, passkey: true });

    if (path === "/auth/google/start") {
      const back = here.searchParams.get("back") || "";
      if (!google || !isHome(back, homes)) return new Response("Not set up for this page", { status: 400 });
      const state = random();
      await store.putChallenge(state, "google", back, 10 * MINUTE);
      const to = new URL("https://accounts.google.com/o/oauth2/v2/auth");
      to.search = new URLSearchParams({
        client_id: env.GOOGLE_CLIENT_ID,
        redirect_uri: here.origin + "/auth/google/back",
        response_type: "code",
        scope: "openid profile",
        state,
        prompt: "select_account",
      });
      return Response.redirect(to.toString(), 302);
    }

    if (path === "/auth/google/back") {
      const back = await store.takeChallenge(here.searchParams.get("state") || "", "google");
      if (!back) return new Response("That sign-in had expired: try again from the game", { status: 400 });
      const send = (signin) => {
        const u = new URL(back);
        u.searchParams.set("signin", signin);
        return Response.redirect(u.toString(), 302);
      };
      const code = here.searchParams.get("code");
      if (!code) return send("failed");
      const person = await googlePerson(code, here.origin + "/auth/google/back", env);
      if (!person) return send("failed");
      let login = await store.login("google", person.sub);
      if (!login) {
        const account = random(12);
        await store.addAccount(account, cleanName(person.name) || "Courtier");
        await store.addLogin({ kind: "google", subject: person.sub, account });
        login = { account };
      }
      const ticket = random();
      await store.putChallenge(ticket, "ticket", login.account, 2 * MINUTE);
      return send(ticket);
    }

    if (request.method === "GET" && path === "/me") {
      const account = await signedIn(request, store);
      return account ? json(await me(store, account)) : no("Not signed in", 401);
    }

    if (request.method !== "POST") return no("POST", 405);
    let body = {};
    try { body = JSON.parse((await request.text()) || "{}"); } catch { return no("Not JSON"); }

    if (path === "/auth/ticket") {
      const account = await store.takeChallenge(String(body.ticket || ""), "ticket");
      return account ? json(await startSession(store, account, body.player)) : no("That sign-in had expired", 401);
    }

    if (path === "/auth/passkey/begin") {
      const account = await signedIn(request, store);
      const id = random(16), challenge = random();
      // The account a new passkey would be for: this one, or a new one.
      const user = account || random(12);
      await store.putChallenge(id, "passkey", JSON.stringify({ challenge, user, adding: Boolean(account) }), 5 * MINUTE);
      return json({ id, challenge, user: b64u.from(new TextEncoder().encode(user)) });
    }

    if (path === "/auth/passkey/create" || path === "/auth/passkey/sign") {
      const saved = await store.takeChallenge(String(body.id || ""), "passkey");
      if (!saved) return no("That had expired: try again", 401);
      const { challenge, user, adding } = JSON.parse(saved);
      const checked = await checkCeremony(body, {
        challenge, origin, homes, type: path.endsWith("create") ? "webauthn.create" : "webauthn.get",
      });
      if (checked.error) return no(checked.error, 401);
      const credential = String(body.credentialId || "");
      if (!credential) return no("No passkey");

      if (path.endsWith("create")) {
        // A passkey for this account (adding one), or for a new account.
        if (adding && (await signedIn(request, store)) !== user) return no("Not signed in", 401);
        if (await store.login("passkey", credential)) return no("That passkey is in use already", 409);
        const alg = Number(body.alg);
        if (![-7, -8, -257].includes(alg) || !body.publicKey) return no("A kind of passkey this can't use");
        await importKey(body.publicKey, alg); // throws on a key that isn't one
        if (!adding) await store.addAccount(user, cleanName(body.name) || "Courtier");
        await store.addLogin({ kind: "passkey", subject: credential, account: user, key: body.publicKey, alg, counter: checked.counter });
        return json(await startSession(store, user, body.player));
      }

      const login = await store.login("passkey", credential);
      if (!login) return no("This game doesn't know that passkey", 401);
      const key = await importKey(login.key, login.alg);
      const signed = concat(b64u.to(body.authenticatorData), await sha256(b64u.to(body.clientDataJSON)));
      if (!(await verify(key, login.alg, b64u.to(body.signature || ""), signed))) return no("The passkey's signature didn't check out", 401);
      if (checked.counter && login.counter && checked.counter <= login.counter) return no("That passkey may have been copied", 401);
      if (checked.counter) await store.setCounter("passkey", credential, checked.counter);
      return json(await startSession(store, login.account, body.player));
    }

    if (path === "/me") {
      const account = await signedIn(request, store);
      if (!account) return no("Not signed in", 401);
      const change = {};
      if (body.name !== undefined) {
        change.name = cleanName(body.name);
        if (!change.name) return no("A name, please");
      }
      if (body.look !== undefined) change.look = body.look === null ? null : String(body.look).slice(0, 40);
      await store.setAccount(account, change);
      return json(await me(store, account));
    }

    if (path === "/auth/out") {
      const token = bearer(request);
      if (token) await store.dropSession(await hashToken(token));
      return json({ ok: true });
    }
  } catch (e) {
    return no("Something went wrong: " + (e?.message || e), 500);
  }
  return no("Nothing here", 404);
}

// ---- pieces -----------------------------------------------------------------

function isHome(url, homes) {
  let o;
  try { o = new URL(url).origin; } catch { return false; }
  return o.startsWith("http://localhost") || homes.some((h) => o === h ||
    (h.endsWith(".pages.dev") && o.endsWith("." + h.replace("https://", ""))));
}

function cleanName(name) {
  return String(name ?? "").replace(/[\u0000-\u001f<>]/g, "").replace(/\s+/g, " ").trim().slice(0, NAME_MAX);
}

const bearer = (request) => (request.headers.get("Authorization") || "").match(/^Bearer (\S+)$/)?.[1] || null;

async function signedIn(request, store) {
  const token = bearer(request);
  return token ? store.session(await hashToken(token)) : null;
}

async function me(store, account) {
  const a = await store.account(account);
  if (!a) return null;
  let owns = [];
  try { owns = JSON.parse(a.owns || "[]"); } catch {}
  return { id: a.id, name: a.name, owns, look: a.look ?? null, logins: await store.logins(account) };
}

async function startSession(store, account, player) {
  const token = random();
  await store.addSession(await hashToken(token), account);
  if (typeof player === "string" && /^[0-9a-f]{16}$/.test(player)) await store.linkPlayer(player, account);
  return { token, me: await me(store, account) };
}

// Swaps Google's one-time code for who signed in. The id token comes
// straight from Google over TLS, so its claims are read, not re-verified;
// who it was for and from are still checked.
async function googlePerson(code, redirect, env) {
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code, client_id: env.GOOGLE_CLIENT_ID, client_secret: env.GOOGLE_CLIENT_SECRET,
      redirect_uri: redirect, grant_type: "authorization_code",
    }),
  });
  if (!r.ok) return null;
  const { id_token } = await r.json();
  if (!id_token) return null;
  const claims = JSON.parse(new TextDecoder().decode(b64u.to(id_token.split(".")[1] || "")));
  const fromGoogle = ["accounts.google.com", "https://accounts.google.com"].includes(claims.iss);
  if (!fromGoogle || claims.aud !== env.GOOGLE_CLIENT_ID || !claims.sub) return null;
  return { sub: String(claims.sub), name: claims.given_name || claims.name || "" };
}

// What every passkey ceremony must show: it was for this challenge, on the
// game's own page, for the game's own address, with the person there.
export async function checkCeremony(body, { challenge, origin, homes, type }) {
  let client;
  try { client = JSON.parse(new TextDecoder().decode(b64u.to(body.clientDataJSON || ""))); } catch { return { error: "Not a passkey's answer" }; }
  if (client.type !== type) return { error: "Not that kind of answer" };
  if (client.challenge !== challenge) return { error: "Not this sign-in's challenge" };
  if (client.origin !== origin || !isHome(client.origin, homes)) return { error: "Not from the game's page" };
  const auth = b64u.to(body.authenticatorData || "");
  if (auth.length < 37) return { error: "Not a passkey's answer" };
  const rp = await sha256(new TextEncoder().encode(new URL(client.origin).hostname));
  if (!same(auth.slice(0, 32), rp)) return { error: "A passkey for some other site" };
  if (!(auth[32] & 0x01)) return { error: "No one was there" };
  const counter = new DataView(auth.buffer, auth.byteOffset + 33, 4).getUint32(0);
  return { counter };
}

const ALGS = {
  [-7]: { importAs: { name: "ECDSA", namedCurve: "P-256" }, verifyAs: { name: "ECDSA", hash: "SHA-256" } },
  [-257]: { importAs: { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, verifyAs: { name: "RSASSA-PKCS1-v1_5" } },
  [-8]: { importAs: { name: "Ed25519" }, verifyAs: { name: "Ed25519" } },
};

const importKey = (spki, alg) => crypto.subtle.importKey("spki", b64u.to(spki), ALGS[alg].importAs, false, ["verify"]);

async function verify(key, alg, signature, data) {
  const sig = alg === -7 ? derToRaw(signature) : signature;
  return sig ? crypto.subtle.verify(ALGS[alg].verifyAs, key, sig, data) : false;
}

// An ECDSA signature as passkeys give it (DER) to the r‖s WebCrypto wants.
function derToRaw(der) {
  if (der[0] !== 0x30) return null;
  let i = 2;
  const part = () => {
    if (der[i++] !== 0x02) throw new Error("bad signature");
    const n = der[i++];
    let v = der.slice(i, i + n);
    i += n;
    while (v.length > 32 && v[0] === 0) v = v.slice(1);
    const out = new Uint8Array(32);
    out.set(v, 32 - v.length);
    return out;
  };
  try { return concat(part(), part()); } catch { return null; }
}

function concat(a, b) {
  const out = new Uint8Array(a.length + b.length);
  out.set(a);
  out.set(b, a.length);
  return out;
}
