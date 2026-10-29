var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// rooms.js
var LETTERS = "ABCDEFGHJKMNPQRSTUVWXYZ";
var IDLE = 2 * 24 * 60 * 60 * 1e3;
var AWAY = 2 * 60 * 1e3;
var HOUR = 60 * 60 * 1e3;
var MAX_MESSAGE = 2e4;
function newCode() {
  let code = "";
  for (let i = 0; i < 4; i++) code += LETTERS[Math.floor(Math.random() * LETTERS.length)];
  return code;
}
__name(newCode, "newCode");
async function handleRooms(request, env, path) {
  if (!env.ROOMS) return new Response("No rooms here", { status: 503 });
  if (request.headers.get("Upgrade") !== "websocket") {
    return new Response("Rooms are joined over a WebSocket", { status: 426 });
  }
  const url = new URL(request.url);
  if (path === "/rooms/new") {
    for (let i = 0; i < 8; i++) {
      const code2 = newCode();
      const target2 = new URL(url);
      target2.pathname = `/rooms/${code2}`;
      target2.searchParams.set("create", "1");
      const stub2 = env.ROOMS.get(env.ROOMS.idFromName(code2));
      const r = await stub2.fetch(new Request(target2, request));
      if (r.status !== 409) return r;
    }
    return new Response("No free code", { status: 503 });
  }
  const code = path.slice("/rooms/".length).toUpperCase();
  if (!/^[A-Z]{4}$/.test(code)) return new Response("Not a room code", { status: 400 });
  const stub = env.ROOMS.get(env.ROOMS.idFromName(code));
  const target = new URL(url);
  target.pathname = `/rooms/${code}`;
  target.searchParams.delete("create");
  return stub.fetch(new Request(target, request));
}
__name(handleRooms, "handleRooms");
var MOVES = "mv:";
var moveKey = /* @__PURE__ */ __name((seq) => MOVES + String(seq).padStart(8, "0"), "moveKey");
var Room = class {
  static {
    __name(this, "Room");
  }
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
    this.meta = null;
    this.count = 0;
    this.alarmSet = 0;
    ctx.blockConcurrencyWhile(async () => {
      this.meta = await ctx.storage.get("meta") || null;
      const last = await ctx.storage.list({ prefix: MOVES, reverse: true, limit: 1 });
      for (const move of last.values()) this.count = move.seq + 1;
      this.count = Math.max(this.count, this.meta?.count ?? 0);
    });
  }
  async fetch(request) {
    const url = new URL(request.url);
    const q = url.searchParams;
    const session = (q.get("session") || "").slice(0, 64);
    const name = (q.get("name") || "").trim().slice(0, 24) || "Player";
    const build = q.get("build") || "";
    const code = url.pathname.split("/").pop();
    if (q.get("create")) {
      if (this.meta) return new Response("Taken", { status: 409 });
      let setup;
      try {
        setup = JSON.parse(q.get("setup") || "");
      } catch {
        setup = null;
      }
      const players = setup && Array.isArray(setup.names) ? setup.names.length : 0;
      if (!session || players < 2 || players > 6) return this.refuse("bad");
      this.meta = {
        code,
        setup,
        build,
        host: session,
        started: false,
        seats: Array.from({ length: players }, () => ({ who: "empty" })),
        names: {},
        created: Date.now()
      };
    }
    if (!this.meta) return this.refuse("no-room");
    const m = this.meta;
    if (!session) return this.refuse("bad");
    if (m.build && build && build !== m.build) return this.refuse("version");
    let seat = m.seats.findIndex((h) => h.who === "person" && h.id === session);
    if (seat < 0) {
      seat = m.seats.findIndex((h) => h.who === (m.started ? "courtier" : "empty"));
      if (seat < 0 && m.started) {
        seat = m.seats.findIndex((h) => h.who === "person" && !h.connected && !this.connected(h.id) && Date.now() - (h.since ?? 0) > AWAY);
      }
      if (seat < 0) return this.refuse("full");
    }
    m.seats[seat] = { who: "person", id: session, connected: true };
    m.names[session] = name;
    if (!this.connected(m.host) && m.host !== session) {
      const hostSeat = m.seats.findIndex((h) => h.who === "person" && h.id === m.host);
      if (hostSeat < 0 || !m.seats[hostSeat].connected) m.host = session;
    }
    await this.save();
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server, [session]);
    server.serializeAttachment({ session });
    const after = q.get("after") === null ? NaN : Number(q.get("after"));
    const from = Number.isFinite(after) ? after + 1 : 0;
    const moves = from < this.count ? [...(await this.ctx.storage.list({ prefix: MOVES, start: moveKey(from) })).values()] : [];
    server.send(JSON.stringify({
      t: "hello",
      code: m.code,
      setup: m.setup,
      seats: m.seats,
      names: m.names,
      host: m.host,
      started: m.started,
      seat,
      moves
    }));
    this.broadcast({ t: "seats", seats: m.seats, names: m.names, host: m.host, started: m.started }, server);
    return new Response(null, { status: 101, webSocket: client });
  }
  /// Accepts the socket only to say why not, then closes it: a browser
  /// can't read why a WebSocket was turned away, but it can read this.
  refuse(why) {
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    server.accept();
    server.send(JSON.stringify({ t: "error", why }));
    server.close(4e3, why);
    return new Response(null, { status: 101, webSocket: client });
  }
  async webSocketMessage(ws, raw) {
    if (typeof raw !== "string" || raw.length > MAX_MESSAGE) return;
    let msg;
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }
    const m = this.meta;
    if (!m) return;
    const { session } = ws.deserializeAttachment() || {};
    const seat = m.seats.findIndex((h) => h.who === "person" && h.id === session);
    switch (msg.t) {
      case "ping":
        ws.send(JSON.stringify({ t: "pong" }));
        return;
      case "start":
        if (session !== m.host || m.started) return;
        m.seats = m.seats.map((h) => h.who === "empty" ? { who: "courtier" } : h);
        m.started = true;
        await this.save();
        this.broadcast({ t: "seats", seats: m.seats, names: m.names, host: m.host, started: true });
        return;
      case "leave": {
        if (seat < 0) return;
        m.seats[seat] = m.started ? { who: "courtier" } : { who: "empty" };
        if (m.host === session) {
          const next = m.seats.find((h) => h.who === "person" && h.connected);
          if (next) m.host = next.id;
        }
        await this.save();
        this.broadcast(this.seatsMessage(), ws);
        ws.close(1e3, "left");
        return;
      }
      case "move": {
        const a = msg.a;
        if (!a || typeof a !== "object" || typeof a.type !== "string") return;
        if (!m.started) return;
        const own = a.seat === seat || a.type === "pick" && seat >= 0;
        const forOthers = session === m.host && this.hostPlays(a.seat);
        if (!own && !forOthers) {
          ws.send(JSON.stringify({ t: "refused", why: "not your seat", a }));
          return;
        }
        const move = { ...a, seq: this.count };
        this.count++;
        await this.ctx.storage.put(moveKey(move.seq), move);
        await this.touch();
        this.broadcast({ t: "move", m: move });
        return;
      }
    }
  }
  async webSocketClose(ws) {
    await this.gone(ws);
  }
  async webSocketError(ws) {
    await this.gone(ws);
  }
  /// A device's socket closed: its seat is kept, played by the host until
  /// they're back; a host who goes hands the room to whoever's left.
  async gone(ws) {
    const m = this.meta;
    if (!m) return;
    const { session } = ws.deserializeAttachment() || {};
    if (!session || this.connected(session, ws)) return;
    const seat = m.seats.findIndex((h) => h.who === "person" && h.id === session);
    if (seat >= 0) m.seats[seat] = { who: "person", id: session, connected: false, since: Date.now() };
    if (m.host === session) {
      const next = m.seats.find((h) => h.who === "person" && h.connected);
      if (next) m.host = next.id;
    }
    await this.save();
    this.broadcast({ t: "seats", seats: m.seats, names: m.names, host: m.host, started: m.started }, ws);
  }
  /// Whether [session] has a socket open (other than [except]).
  connected(session, except) {
    return this.ctx.getWebSockets(session).some((s) => s !== except);
  }
  hostPlays(seat) {
    const h = this.meta.seats[seat];
    if (!h) return false;
    return h.who !== "person" || !h.connected;
  }
  broadcast(msg, except) {
    const text = JSON.stringify(msg);
    for (const s of this.ctx.getWebSockets()) {
      if (s === except) continue;
      try {
        s.send(text);
      } catch {
      }
    }
  }
  seatsMessage() {
    const m = this.meta;
    return { t: "seats", seats: m.seats, names: m.names, host: m.host, started: m.started };
  }
  /// The room's details changed (seats, the host, the start).
  async save() {
    this.meta.count = this.count;
    await this.ctx.storage.put("meta", this.meta);
    await this.touch();
  }
  /// The room is in use: its clearing is put off (an hour at a time, so a
  /// move doesn't write more than itself).
  async touch() {
    if (Date.now() - this.alarmSet < HOUR) return;
    this.alarmSet = Date.now();
    await this.ctx.storage.setAlarm(Date.now() + IDLE);
  }
  /// Unused for two days: the room and its moves are cleared.
  async alarm() {
    await this.ctx.storage.deleteAll();
    this.meta = null;
  }
};

// worker.js
var MAX_BODY = 2e5;
var MAX_ISSUE = 6e4;
var worker_default = {
  async fetch(request, env) {
    const origin = request.headers.get("Origin") || "";
    const allowed = origin === "" || origin === env.ALLOW_ORIGIN || origin.startsWith("http://localhost");
    const cors = {
      "Access-Control-Allow-Origin": allowed ? origin : env.ALLOW_ORIGIN,
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
      "Vary": "Origin"
    };
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    const path = new URL(request.url).pathname.replace(/\/+$/, "");
    if (path === "/rounds" && request.method === "GET") return readRounds(request, env);
    if (path.startsWith("/rooms/")) {
      if (!allowed) return new Response("Not from the game", { status: 403 });
      return handleRooms(request, env, path);
    }
    if (request.method !== "POST") return new Response("POST a report", { status: 405, headers: cors });
    if (!allowed) return new Response("Not from the game", { status: 403, headers: cors });
    const raw = await request.text();
    if (raw.length > MAX_BODY) return new Response("Too big", { status: 413, headers: cors });
    let r;
    try {
      r = JSON.parse(raw);
    } catch {
      return new Response("Not JSON", { status: 400, headers: cors });
    }
    if (path === "/rounds") return keepRound(r, raw, request, env, cors);
    const message = String(r.message || "").trim().slice(0, 2e3);
    if (!message) return new Response("Say what went wrong", { status: 400, headers: cors });
    const { message: _m, name, build, device, where, settings, time, ...rest } = r;
    const firstLine = message.split("\n")[0];
    const title = "Bug: " + (firstLine.length > 70 ? firstLine.slice(0, 67) + "\u2026" : firstLine);
    const quote = message.split("\n").map((l) => "> " + l).join("\n");
    const facts = [
      ["From", name || "anonymous"],
      ["Build", build ? `\`${build}\`` : "?"],
      ["When", time || (/* @__PURE__ */ new Date()).toISOString()],
      ["Device", device ? `${device.platform} \xB7 ${device.os} \xB7 ${device.screen} @${device.pixelRatio}x \xB7 ${device.locale}` : "?"],
      ["Browser", request.headers.get("User-Agent") || "?"],
      ["Where", where ? "`" + JSON.stringify(where) + "`" : "?"],
      ["Settings", settings ? "`" + JSON.stringify(settings) + "`" : "?"]
    ].map(([k, v]) => `| ${k} | ${String(v).replace(/\|/g, "\\|")} |`).join("\n");
    let state = JSON.stringify(rest);
    const head = `${quote}

| | |
|---|---|
${facts}

`;
    const wrap = /* @__PURE__ */ __name((s, note = "") => `<details><summary>Game state (load with GameState.fromJson)${note}</summary>

\`\`\`json
${s}
\`\`\`
</details>
`, "wrap");
    let body = head + wrap(state);
    if (body.length > MAX_ISSUE) {
      if (rest.state) {
        delete rest.state.annals;
        delete rest.state.courtNews;
      }
      state = JSON.stringify(rest);
      body = head + wrap(state.length > MAX_ISSUE - head.length - 300 ? state.slice(0, MAX_ISSUE - head.length - 300) : state, " (trimmed)");
    }
    const gh = await fetch(`https://api.github.com/repos/${env.REPO}/issues`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${env.GITHUB_TOKEN}`,
        "Accept": "application/vnd.github+json",
        "User-Agent": "kings-court-bug-worker"
      },
      body: JSON.stringify({ title, body, labels: ["bug", "from-game"] })
    });
    if (!gh.ok) return new Response("Couldn't file it: " + gh.status, { status: 502, headers: cors });
    const issue = await gh.json();
    return new Response(JSON.stringify({ number: issue.number }), {
      status: 201,
      headers: { ...cors, "Content-Type": "application/json" }
    });
  }
};
async function keepRound(r, raw, request, env, cors) {
  if (!env.DB) return new Response("No database bound", { status: 503, headers: cors });
  if (typeof r.v !== "number" || !r.round) return new Response("Not a round", { status: 400, headers: cors });
  await env.DB.prepare(
    "INSERT INTO rounds (received, version, build, player, mode, players, people, outcome, record) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
  ).bind(
    (/* @__PURE__ */ new Date()).toISOString(),
    r.v,
    String(r.build || ""),
    String(r.player || ""),
    String(r.mode || ""),
    Number(r.players) || 0,
    Array.isArray(r.people) ? r.people.length : 0,
    String(r.outcome || ""),
    raw
  ).run();
  return new Response(null, { status: 204, headers: cors });
}
__name(keepRound, "keepRound");
async function readRounds(request, env) {
  const auth = request.headers.get("Authorization") || "";
  if (!env.READ_KEY || auth !== `Bearer ${env.READ_KEY}`) return new Response("No", { status: 401 });
  if (!env.DB) return new Response("No database bound", { status: 503 });
  const url = new URL(request.url);
  const after = Number(url.searchParams.get("after")) || 0;
  const { results } = await env.DB.prepare(
    "SELECT id, received, record FROM rounds WHERE id > ? ORDER BY id LIMIT 500"
  ).bind(after).all();
  const lines = results.map((row) => JSON.stringify({ id: row.id, received: row.received, record: JSON.parse(row.record) }));
  return new Response(lines.join("\n") + (lines.length ? "\n" : ""), {
    headers: { "Content-Type": "application/x-ndjson" }
  });
}
__name(readRounds, "readRounds");

// ../../../../../tmp/claude-0/-home-claude/347433e7-7093-5863-b2a7-59cce4254725/scratchpad/wr/node_modules/wrangler/templates/middleware/middleware-ensure-req-body-drained.ts
var drainBody = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } finally {
    try {
      if (request.body !== null && !request.bodyUsed) {
        const reader = request.body.getReader();
        while (!(await reader.read()).done) {
        }
      }
    } catch (e) {
      console.error("Failed to drain the unused request body.", e);
    }
  }
}, "drainBody");
var middleware_ensure_req_body_drained_default = drainBody;

// ../../../../../tmp/claude-0/-home-claude/347433e7-7093-5863-b2a7-59cce4254725/scratchpad/wr/node_modules/wrangler/templates/middleware/middleware-miniflare3-json-error.ts
function reduceError(e) {
  return {
    name: e?.name,
    message: e?.message ?? String(e),
    stack: e?.stack,
    cause: e?.cause === void 0 ? void 0 : reduceError(e.cause)
  };
}
__name(reduceError, "reduceError");
var jsonError = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } catch (e) {
    const error = reduceError(e);
    return Response.json(error, {
      status: 500,
      headers: { "MF-Experimental-Error-Stack": "true" }
    });
  }
}, "jsonError");
var middleware_miniflare3_json_error_default = jsonError;

// .wrangler/tmp/bundle-8rB0Df/middleware-insertion-facade.js
var __INTERNAL_WRANGLER_MIDDLEWARE__ = [
  middleware_ensure_req_body_drained_default,
  middleware_miniflare3_json_error_default
];
var middleware_insertion_facade_default = worker_default;

// ../../../../../tmp/claude-0/-home-claude/347433e7-7093-5863-b2a7-59cce4254725/scratchpad/wr/node_modules/wrangler/templates/middleware/common.ts
var __facade_middleware__ = [];
function __facade_register__(...args) {
  __facade_middleware__.push(...args.flat());
}
__name(__facade_register__, "__facade_register__");
function __facade_invokeChain__(request, env, ctx, dispatch, middlewareChain) {
  const [head, ...tail] = middlewareChain;
  const middlewareCtx = {
    dispatch,
    next(newRequest, newEnv) {
      return __facade_invokeChain__(newRequest, newEnv, ctx, dispatch, tail);
    }
  };
  return head(request, env, ctx, middlewareCtx);
}
__name(__facade_invokeChain__, "__facade_invokeChain__");
function __facade_invoke__(request, env, ctx, dispatch, finalMiddleware) {
  return __facade_invokeChain__(request, env, ctx, dispatch, [
    ...__facade_middleware__,
    finalMiddleware
  ]);
}
__name(__facade_invoke__, "__facade_invoke__");

// .wrangler/tmp/bundle-8rB0Df/middleware-loader.entry.ts
var __Facade_ScheduledController__ = class ___Facade_ScheduledController__ {
  constructor(scheduledTime, cron, noRetry) {
    this.scheduledTime = scheduledTime;
    this.cron = cron;
    this.#noRetry = noRetry;
  }
  static {
    __name(this, "__Facade_ScheduledController__");
  }
  #noRetry;
  noRetry() {
    if (!(this instanceof ___Facade_ScheduledController__)) {
      throw new TypeError("Illegal invocation");
    }
    this.#noRetry();
  }
};
function wrapExportedHandler(worker) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return worker;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  const fetchDispatcher = /* @__PURE__ */ __name(function(request, env, ctx) {
    if (worker.fetch === void 0) {
      throw new Error("Handler does not export a fetch() function.");
    }
    return worker.fetch(request, env, ctx);
  }, "fetchDispatcher");
  return {
    ...worker,
    fetch(request, env, ctx) {
      const dispatcher = /* @__PURE__ */ __name(function(type, init) {
        if (type === "scheduled" && worker.scheduled !== void 0) {
          const controller = new __Facade_ScheduledController__(
            Date.now(),
            init.cron ?? "",
            () => {
            }
          );
          return worker.scheduled(controller, env, ctx);
        }
      }, "dispatcher");
      return __facade_invoke__(request, env, ctx, dispatcher, fetchDispatcher);
    }
  };
}
__name(wrapExportedHandler, "wrapExportedHandler");
function wrapWorkerEntrypoint(klass) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return klass;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  return class extends klass {
    #fetchDispatcher = /* @__PURE__ */ __name((request, env, ctx) => {
      this.env = env;
      this.ctx = ctx;
      if (super.fetch === void 0) {
        throw new Error("Entrypoint class does not define a fetch() function.");
      }
      return super.fetch(request);
    }, "#fetchDispatcher");
    #dispatcher = /* @__PURE__ */ __name((type, init) => {
      if (type === "scheduled" && super.scheduled !== void 0) {
        const controller = new __Facade_ScheduledController__(
          Date.now(),
          init.cron ?? "",
          () => {
          }
        );
        return super.scheduled(controller);
      }
    }, "#dispatcher");
    fetch(request) {
      return __facade_invoke__(
        request,
        this.env,
        this.ctx,
        this.#dispatcher,
        this.#fetchDispatcher
      );
    }
  };
}
__name(wrapWorkerEntrypoint, "wrapWorkerEntrypoint");
var WRAPPED_ENTRY;
if (typeof middleware_insertion_facade_default === "object") {
  WRAPPED_ENTRY = wrapExportedHandler(middleware_insertion_facade_default);
} else if (typeof middleware_insertion_facade_default === "function") {
  WRAPPED_ENTRY = wrapWorkerEntrypoint(middleware_insertion_facade_default);
}
var middleware_loader_entry_default = WRAPPED_ENTRY;
export {
  Room,
  __INTERNAL_WRANGLER_MIDDLEWARE__,
  middleware_loader_entry_default as default
};
//# sourceMappingURL=worker.js.map
