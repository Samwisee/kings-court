// Rooms: where people meet to play one game on several devices.
//
// Each room is a Durable Object, named by its 4-letter code. It keeps the
// game's setup, who sits where (as lib/game/seats.dart writes it), who is
// hosting, and every move. A device joins over a WebSocket; the room
// numbers each move as it arrives and sends it to every device, so every
// table plays the same moves in the same order (lib/net/online_table.dart
// is the game's side). The room doesn't know the rules: each device's
// table refuses a move the rules don't allow, the same way on every
// device, because they all see the same moves in the same order.
//
//   GET /rooms/new?session=&name=&build=&setup=   (WebSocket) a new room;
//       the creator hosts it, in seat 0
//   GET /rooms/CODE?session=&name=&build=&after=  (WebSocket) join, or come
//       back after a drop and catch up on the moves after `after`
//
// Messages, as JSON. From a device:
//   {t:"move", a:<action>}   a move (the action's JSON, as the game sends it)
//   {t:"start"}              the host starts the game; empty seats go to
//                            courtiers
//   {t:"ping"}               answered with {t:"pong"}
// To a device:
//   {t:"hello", code, setup, seats, names, host, started, seat}
//   {t:"seats", seats, names, host, started}   who sits where, changed
//   {t:"move", m:<move>}     a move, numbered: {seq, ...action}
//   {t:"error", why}         then the socket closes: no-room, full,
//                            started, version, taken, bad
//   {t:"refused", why, a}    a move not accepted (not this device's seat)

const LETTERS = "ABCDEFGHJKMNPQRSTUVWXYZ"; // no I, L or O: easy to read out
const IDLE = 2 * 24 * 60 * 60 * 1000; // a room unused this long is cleared
const MAX_MESSAGE = 20_000;

/// A new room's code.
export function newCode() {
  let code = "";
  for (let i = 0; i < 4; i++) code += LETTERS[Math.floor(Math.random() * LETTERS.length)];
  return code;
}

/// The worker's side: routes /rooms/... to the room's Durable Object.
export async function handleRooms(request, env, path) {
  if (!env.ROOMS) return new Response("No rooms here", { status: 503 });
  if (request.headers.get("Upgrade") !== "websocket") {
    return new Response("Rooms are joined over a WebSocket", { status: 426 });
  }
  const url = new URL(request.url);
  if (path === "/rooms/new") {
    // A code nobody is using: a few tries, the room says if it's taken.
    for (let i = 0; i < 8; i++) {
      const code = newCode();
      const target = new URL(url);
      target.pathname = `/rooms/${code}`;
      target.searchParams.set("create", "1");
      const stub = env.ROOMS.get(env.ROOMS.idFromName(code));
      const r = await stub.fetch(new Request(target, request));
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

const moveKey = (seq) => "m" + String(seq).padStart(8, "0");

export class Room {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
    this.meta = null;
    ctx.blockConcurrencyWhile(async () => {
      this.meta = (await ctx.storage.get("meta")) || null;
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
      try { setup = JSON.parse(q.get("setup") || ""); } catch { setup = null; }
      const players = setup && Array.isArray(setup.names) ? setup.names.length : 0;
      if (!session || players < 2 || players > 6) return this.refuse("bad");
      this.meta = {
        code, setup, build, host: session, started: false, count: 0,
        seats: Array.from({ length: players }, () => ({ who: "empty" })),
        names: {}, created: Date.now(),
      };
    }
    if (!this.meta) return this.refuse("no-room");
    const m = this.meta;
    if (!session) return this.refuse("bad");
    if (m.build && build && build !== m.build) return this.refuse("version");

    let seat = m.seats.findIndex((h) => h.who === "person" && h.id === session);
    if (seat < 0) {
      if (m.started) return this.refuse("started");
      seat = m.seats.findIndex((h) => h.who === "empty");
      if (seat < 0) return this.refuse("full");
    }
    m.seats[seat] = { who: "person", id: session, connected: true };
    m.names[session] = name;
    // A room whose host has gone is hosted by whoever comes in.
    if (!this.connected(m.host) && m.host !== session) {
      const hostSeat = m.seats.findIndex((h) => h.who === "person" && h.id === m.host);
      if (hostSeat < 0 || !m.seats[hostSeat].connected) m.host = session;
    }
    await this.save();

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server, [session]);
    server.serializeAttachment({ session });
    server.send(JSON.stringify({ t: "hello", code: m.code, setup: m.setup, seats: m.seats,
      names: m.names, host: m.host, started: m.started, seat }));
    // Everything after what this device has seen.
    const after = Number(q.get("after"));
    const from = Number.isFinite(after) ? after + 1 : 0;
    if (from < m.count) {
      const moves = await this.ctx.storage.list({ prefix: "m", start: moveKey(from) });
      for (const move of moves.values()) server.send(JSON.stringify({ t: "move", m: move }));
    }
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
    server.close(4000, why);
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, raw) {
    if (typeof raw !== "string" || raw.length > MAX_MESSAGE) return;
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }
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
        m.seats = m.seats.map((h) => (h.who === "empty" ? { who: "courtier" } : h));
        m.started = true;
        await this.save();
        this.broadcast({ t: "seats", seats: m.seats, names: m.names, host: m.host, started: true });
        return;
      case "move": {
        const a = msg.a;
        if (!a || typeof a !== "object" || typeof a.type !== "string") return;
        if (!m.started) return;
        // A device moves for its own seat; the host's also moves for the
        // courtiers and anyone who has dropped. A task may be handed to
        // anyone (the King's Command): every table checks whose pick it is.
        const own = a.seat === seat || (a.type === "pick" && seat >= 0);
        const forOthers = session === m.host && this.hostPlays(a.seat);
        if (!own && !forOthers) {
          ws.send(JSON.stringify({ t: "refused", why: "not your seat", a }));
          return;
        }
        const move = { ...a, seq: m.count };
        m.count++;
        await this.ctx.storage.put(moveKey(move.seq), move);
        await this.save();
        this.broadcast({ t: "move", m: move });
        return;
      }
    }
  }

  async webSocketClose(ws) { await this.gone(ws); }
  async webSocketError(ws) { await this.gone(ws); }

  /// A device's socket closed: its seat is kept, played by the host until
  /// they're back; a host who goes hands the room to whoever's left.
  async gone(ws) {
    const m = this.meta;
    if (!m) return;
    const { session } = ws.deserializeAttachment() || {};
    if (!session || this.connected(session, ws)) return;
    const seat = m.seats.findIndex((h) => h.who === "person" && h.id === session);
    if (seat >= 0) m.seats[seat] = { who: "person", id: session, connected: false };
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
      try { s.send(text); } catch { /* closing */ }
    }
  }

  async save() {
    await this.ctx.storage.put("meta", this.meta);
    await this.ctx.storage.setAlarm(Date.now() + IDLE);
  }

  /// Unused for two days: the room and its moves are cleared.
  async alarm() {
    await this.ctx.storage.deleteAll();
    this.meta = null;
  }
}
