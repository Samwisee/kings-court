-- The rounds people play, for balancing the game (see worker.js and
-- lib/platform/game_log.dart). Run once:
--   wrangler d1 execute kings-court-rounds --remote --file tool/bug_worker/schema.sql
-- or paste it into the database's Console in the Cloudflare dashboard.
CREATE TABLE IF NOT EXISTS rounds (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  received TEXT NOT NULL,   -- when it arrived (UTC, ISO 8601)
  version INTEGER NOT NULL, -- the record's shape (GameLog.version)
  build TEXT,               -- the game's commit
  player TEXT,              -- the device's anonymous id
  mode TEXT,                -- free, chronicle, tutorial…
  players INTEGER,          -- seats at the table
  people INTEGER,           -- how many of them were people
  outcome TEXT,             -- won or lost
  record TEXT NOT NULL      -- the whole record, as JSON
);
CREATE INDEX IF NOT EXISTS rounds_mode ON rounds (mode, players);
