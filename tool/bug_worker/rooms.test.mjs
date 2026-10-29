// Tests for the rooms (rooms.js), on mocks of what Cloudflare gives a
// Durable Object.   node --test tool/bug_worker/
import test from "node:test";
import assert from "node:assert/strict";

class FakeResponse {
  constructor(body, init = {}) { this.status = init.status ?? 200; this.webSocket = init.webSocket; this.body = body; }
}
globalThis.Response = FakeResponse;

class FakeSocket {
  constructor() { this.sent = []; this.closed = null; this.attachment = null; this.peer = null; }
  send(text) { this.peer.sent.push(JSON.parse(text)); }
  accept() {}
  close(code, why) { this.closed = { code, why }; }
  serializeAttachment(a) { this.attachment = a; }
  deserializeAttachment() { return this.attachment; }
}
globalThis.WebSocketPair = function () {
  const client = new FakeSocket(), server = new FakeSocket();
  client.peer = server; server.peer = client;
  return { 0: client, 1: server };
};

const { Room } = await import("./rooms.js");

function fakeCtx(storage = new Map()) {
  const sockets = [];
  return {
    storage: {
      data: storage,
      async get(k) { return structuredClone(storage.get(k)); },
      async put(k, v) { storage.set(k, structuredClone(v)); },
      async list({ prefix, start }) {
        return new Map([...storage.entries()].filter(([k]) => k.startsWith(prefix) && k !== "meta" && (!start || k >= start)).sort());
      },
      async setAlarm() {},
      async deleteAll() { storage.clear(); },
    },
    blockConcurrencyWhile(fn) { this.pending = fn(); },
    acceptWebSocket(ws, tags) { ws.tags = tags; sockets.push(ws); },
    getWebSockets(tag) { return sockets.filter((s) => !s.gone && (!tag || s.tags.includes(tag))); },
    sockets,
  };
}

const setup = { mode: "free", names: ["A", "B", "C"], target: 6, seed: 1, digital: true };

async function room(ctx = fakeCtx()) {
  const r = new Room(ctx, {});
  await ctx.pending;
  return r;
}

/// Connects [session]: the client's end, whose .sent is what it received.
async function connect(r, session, { create = false, after, build = "b1", name = session } = {}) {
  const q = new URLSearchParams({ session, name, build });
  if (create) { q.set("create", "1"); q.set("setup", JSON.stringify(setup)); }
  if (after !== undefined) q.set("after", String(after));
  const res = await r.fetch(new Request(`https://x/rooms/ABCD?${q}`));
  assert.equal(res.status, 101);
  return res.webSocket;
}

const serverOf = (r, session) => r.ctx.sockets.find((s) => s.tags.includes(session) && !s.gone);
const say = (r, session, msg) => r.webSocketMessage(serverOf(r, session), JSON.stringify(msg));
const last = (client, t) => [...client.sent].reverse().find((m) => m.t === t);

test("The creator hosts in seat 0; others take the next seats; a full room says so", async () => {
  const r = await room();
  const ann = await connect(r, "ann", { create: true });
  assert.deepEqual([last(ann, "hello").seat, last(ann, "hello").host, last(ann, "hello").code], [0, "ann", "ABCD"]);
  const ben = await connect(r, "ben");
  assert.equal(last(ben, "hello").seat, 1);
  assert.equal(last(ann, "seats").names.ben, "ben", "the others hear who came in");
  await connect(r, "cal");
  const dee = await connect(r, "dee");
  assert.equal(last(dee, "error").why, "full");
  assert.equal(dee.peer.closed.why, "full");
});

test("A second room can't take a code in use", async () => {
  const r = await room();
  await connect(r, "ann", { create: true });
  const res = await r.fetch(new Request(`https://x/rooms/ABCD?session=zed&create=1&setup=${encodeURIComponent(JSON.stringify(setup))}`));
  assert.equal(res.status, 409);
});

test("No such room, or another build, is turned away with the reason", async () => {
  const r = await room();
  assert.equal(last(await connect(r, "ann"), "error").why, "no-room");
  await connect(r, "ann", { create: true });
  assert.equal(last(await connect(r, "ben", { build: "b2" }), "error").why, "version");
});

test("Moves wait for the start, then are numbered and sent to everyone", async () => {
  const r = await room();
  const ann = await connect(r, "ann", { create: true });
  const ben = await connect(r, "ben");
  await say(r, "ann", { t: "move", a: { type: "crown", seat: 0, king: 0 } });
  assert.equal(last(ben, "move"), undefined, "not started");
  await say(r, "ben", { t: "start" });
  assert.equal(last(ben, "seats")?.started, undefined, "only the host starts");
  await say(r, "ann", { t: "start" });
  const seats = last(ben, "seats");
  assert.equal(seats.started, true);
  assert.deepEqual(seats.seats[2], { who: "courtier" }, "the empty seat goes to a courtier");
  await say(r, "ann", { t: "move", a: { type: "crown", seat: 0, king: 0 } });
  await say(r, "ben", { t: "move", a: { type: "pass", seat: 1 } });
  for (const c of [ann, ben]) {
    assert.deepEqual(c.sent.filter((m) => m.t === "move").map((m) => [m.m.seq, m.m.type]), [[0, "crown"], [1, "pass"]]);
  }
});

test("A device moves only for its own seat; the host also for courtiers", async () => {
  const r = await room();
  await connect(r, "ann", { create: true });
  const ben = await connect(r, "ben");
  await say(r, "ann", { t: "start" });
  await say(r, "ben", { t: "move", a: { type: "pass", seat: 2 } });
  assert.equal(last(ben, "refused").why, "not your seat");
  await say(r, "ann", { t: "move", a: { type: "pass", seat: 2 } });
  assert.equal(last(ben, "move").m.seat, 2, "the host plays the courtier");
  await say(r, "ann", { t: "move", a: { type: "pass", seat: 1 } });
  assert.equal(last(ben, "move").m.seq, 0, "but not a person who's there");
});

test("A device that drops keeps its seat, and catches up when it comes back", async () => {
  const ctx = fakeCtx();
  const r = await room(ctx);
  await connect(r, "ann", { create: true });
  const ben = await connect(r, "ben");
  await say(r, "ann", { t: "start" });
  await say(r, "ann", { t: "move", a: { type: "crown", seat: 0, king: 0 } });
  // Ben drops.
  const old = serverOf(r, "ben");
  old.gone = true;
  await r.webSocketClose(old);
  assert.equal(r.meta.seats[1].connected, false);
  await say(r, "ann", { t: "move", a: { type: "pass", seat: 1 } });
  assert.equal(r.meta.count, 2, "the host plays a dropped seat");
  // Back, having seen move 0: only move 1 comes.
  const back = await connect(r, "ben", { after: 0 });
  assert.equal(last(back, "hello").seat, 1);
  assert.deepEqual(back.sent.filter((m) => m.t === "move").map((m) => m.m.seq), [1]);
  assert.equal(r.meta.seats[1].connected, true);
  // A stranger can't join a game that's begun.
  assert.equal(last(await connect(r, "zed"), "error").why, "started");
  assert.ok(ben);
});

test("A host who goes hands the room to whoever's left", async () => {
  const r = await room();
  await connect(r, "ann", { create: true });
  const ben = await connect(r, "ben");
  const s = serverOf(r, "ann");
  s.gone = true;
  await r.webSocketClose(s);
  assert.equal(last(ben, "seats").host, "ben");
});

test("A room wakes from storage as it was", async () => {
  const ctx = fakeCtx();
  const r = await room(ctx);
  await connect(r, "ann", { create: true });
  await connect(r, "ben");
  await say(r, "ann", { t: "start" });
  await say(r, "ann", { t: "move", a: { type: "crown", seat: 0, king: 0 } });
  const woken = await room(fakeCtx(ctx.storage.data));
  assert.equal(woken.meta.count, 1);
  assert.equal(woken.meta.started, true);
  const ben = await connect(woken, "ben", { after: -1 });
  assert.equal(ben.sent.filter((m) => m.t === "move").length, 1);
});
