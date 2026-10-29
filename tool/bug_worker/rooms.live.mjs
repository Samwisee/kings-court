// A live check of the deployed rooms: two players join a room, the host
// starts, and each sees the other's move.   node rooms.live.mjs <url>
const base = process.argv[2].replace(/^http/, "ws").replace(/\/$/, "");
const setup = { mode: "free", names: ["A", "B", "C"], target: 6, seed: 1, digital: true };

function open(path) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(base + path);
    const got = [];
    ws.onmessage = (e) => got.push(JSON.parse(e.data));
    ws.onopen = () => resolve({ ws, got, send: (m) => ws.send(JSON.stringify(m)) });
    ws.onerror = (e) => reject(new Error("socket error " + (e.message || "")));
    setTimeout(() => reject(new Error("timed out opening " + path)), 10000);
  });
}
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
async function until(f, what) {
  for (let i = 0; i < 50; i++) { const v = f(); if (v) return v; await wait(100); }
  throw new Error("never: " + what);
}

const q = (o) => new URLSearchParams(o).toString();
const ann = await open(`/rooms/new?${q({ session: "live-ann-" + Date.now(), name: "Ann", build: "live", setup: JSON.stringify(setup) })}`);
const hello = await until(() => ann.got.find((m) => m.t === "hello"), "Ann's hello");
const code = hello.code;
console.log(`room ${code}: Ann in seat ${hello.seat}, hosting`);
const ben = await open(`/rooms/${code}?${q({ session: "live-ben-" + Date.now(), name: "Ben", build: "live" })}`);
const bh = await until(() => ben.got.find((m) => m.t === "hello"), "Ben's hello");
console.log(`Ben in seat ${bh.seat}`);
await until(() => ann.got.find((m) => m.t === "seats" && m.names && Object.values(m.names).includes("Ben")), "Ann hears Ben");
ann.send({ t: "start" });
await until(() => ben.got.find((m) => m.t === "seats" && m.started), "the start");
ann.send({ t: "move", a: { type: "crown", seat: 0, king: 0 } });
ben.send({ t: "move", a: { type: "pass", seat: 1 } });
const seen = (c) => c.got.filter((m) => m.t === "move").map((m) => `${m.m.seq}:${m.m.type}`).join(" ");
await until(() => seen(ann).split(" ").length === 2 && seen(ben).split(" ").length === 2, "both moves at both");
console.log(`Ann saw ${seen(ann)}; Ben saw ${seen(ben)}`);
if (seen(ann) !== seen(ben)) throw new Error("they saw different moves");
const wrong = await open(`/rooms/${code}?${q({ session: "live-zed", name: "Zed", build: "live" })}`);
const err = await until(() => wrong.got.find((m) => m.t === "error"), "a stranger turned away");
console.log(`a stranger after the start: ${err.why}`);
ann.ws.close(); ben.ws.close();
console.log("rooms: ok");
process.exit(0);
