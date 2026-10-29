// The King's Court's small web service, a Cloudflare Worker:
//   POST /          a bug report from the game (lib/ui/bug_report.dart),
//                   filed as a GitHub issue labelled "bug"
//   POST /rounds    a round just played (lib/platform/game_log.dart), kept
//                   in the D1 database for balancing the game
//   GET  /rounds    the rounds kept, for tool/games/pull.py (needs READ_KEY)
// Tokens live here, as Worker secrets, never in the game.
//
// Secrets / variables (Cloudflare dashboard > Worker > Settings > Variables):
//   GITHUB_TOKEN  (secret) fine-grained token: kings-court repo, Issues: read & write
//   REPO          (text)   Samwisee/kings-court
//   ALLOW_ORIGIN  (text)   https://samwisee.github.io
//   READ_KEY      (secret) any long random string; tool/games/pull.py sends it
// Bindings: DB, the D1 database "kings-court-rounds" (schema.sql).

const MAX_BODY = 200_000; // bytes accepted from the game
const MAX_ISSUE = 60_000; // GitHub's limit is 65,536 characters

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin") || "";
    const allowed = origin === env.ALLOW_ORIGIN || origin.startsWith("http://localhost");
    const cors = {
      "Access-Control-Allow-Origin": allowed ? origin : env.ALLOW_ORIGIN,
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
      "Vary": "Origin",
    };
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    const path = new URL(request.url).pathname.replace(/\/+$/, "");
    if (path === "/rounds" && request.method === "GET") return readRounds(request, env);
    if (request.method !== "POST") return new Response("POST a report", { status: 405, headers: cors });
    if (!allowed) return new Response("Not from the game", { status: 403, headers: cors });

    const raw = await request.text();
    if (raw.length > MAX_BODY) return new Response("Too big", { status: 413, headers: cors });
    let r;
    try { r = JSON.parse(raw); } catch { return new Response("Not JSON", { status: 400, headers: cors }); }
    if (path === "/rounds") return keepRound(r, raw, request, env, cors);
    const message = String(r.message || "").trim().slice(0, 2000);
    if (!message) return new Response("Say what went wrong", { status: 400, headers: cors });

    const { message: _m, name, build, device, where, settings, time, ...rest } = r;
    const firstLine = message.split("\n")[0];
    const title = "Bug: " + (firstLine.length > 70 ? firstLine.slice(0, 67) + "…" : firstLine);
    const quote = message.split("\n").map((l) => "> " + l).join("\n");
    const facts = [
      ["From", name || "anonymous"],
      ["Build", build ? `\`${build}\`` : "?"],
      ["When", time || new Date().toISOString()],
      ["Device", device ? `${device.platform} · ${device.os} · ${device.screen} @${device.pixelRatio}x · ${device.locale}` : "?"],
      ["Browser", request.headers.get("User-Agent") || "?"],
      ["Where", where ? "`" + JSON.stringify(where) + "`" : "?"],
      ["Settings", settings ? "`" + JSON.stringify(settings) + "`" : "?"],
    ].map(([k, v]) => `| ${k} | ${String(v).replace(/\|/g, "\\|")} |`).join("\n");

    let state = JSON.stringify(rest);
    const head = `${quote}\n\n| | |\n|---|---|\n${facts}\n\n`;
    const wrap = (s, note = "") =>
      `<details><summary>Game state (load with GameState.fromJson)${note}</summary>\n\n\`\`\`json\n${s}\n\`\`\`\n</details>\n`;
    let body = head + wrap(state);
    if (body.length > MAX_ISSUE) {
      // Too long for one issue: drop the history first, then truncate.
      if (rest.state) { delete rest.state.annals; delete rest.state.courtNews; }
      state = JSON.stringify(rest);
      body = head + wrap(state.length > MAX_ISSUE - head.length - 300
        ? state.slice(0, MAX_ISSUE - head.length - 300) : state, " (trimmed)");
    }

    const gh = await fetch(`https://api.github.com/repos/${env.REPO}/issues`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${env.GITHUB_TOKEN}`,
        "Accept": "application/vnd.github+json",
        "User-Agent": "kings-court-bug-worker",
      },
      body: JSON.stringify({ title, body, labels: ["bug", "from-game"] }),
    });
    if (!gh.ok) return new Response("Couldn't file it: " + gh.status, { status: 502, headers: cors });
    const issue = await gh.json();
    return new Response(JSON.stringify({ number: issue.number }), {
      status: 201,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  },
};

// A round from the game: a few columns to find rounds by, and the whole
// record as sent.
async function keepRound(r, raw, request, env, cors) {
  if (!env.DB) return new Response("No database bound", { status: 503, headers: cors });
  if (typeof r.v !== "number" || !r.round) return new Response("Not a round", { status: 400, headers: cors });
  await env.DB.prepare(
    "INSERT INTO rounds (received, version, build, player, mode, players, people, outcome, record)" +
      " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
  ).bind(
    new Date().toISOString(),
    r.v,
    String(r.build || ""),
    String(r.player || ""),
    String(r.mode || ""),
    Number(r.players) || 0,
    Array.isArray(r.people) ? r.people.length : 0,
    String(r.outcome || ""),
    raw,
  ).run();
  return new Response(null, { status: 204, headers: cors });
}

// The rounds kept after id `after` (500 at a time), newest last, as JSON
// lines: {"id": …, "received": …, "record": {…}}.
async function readRounds(request, env) {
  const auth = request.headers.get("Authorization") || "";
  if (!env.READ_KEY || auth !== `Bearer ${env.READ_KEY}`) return new Response("No", { status: 401 });
  if (!env.DB) return new Response("No database bound", { status: 503 });
  const url = new URL(request.url);
  const after = Number(url.searchParams.get("after")) || 0;
  const { results } = await env.DB.prepare(
    "SELECT id, received, record FROM rounds WHERE id > ? ORDER BY id LIMIT 500"
  ).bind(after).all();
  const lines = results.map((row) =>
    JSON.stringify({ id: row.id, received: row.received, record: JSON.parse(row.record) }));
  return new Response(lines.join("\n") + (lines.length ? "\n" : ""), {
    headers: { "Content-Type": "application/x-ndjson" },
  });
}

