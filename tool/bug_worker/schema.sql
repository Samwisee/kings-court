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

-- Accounts (auth.js): signing in is never needed to play. No email
-- addresses: an id, a name to show, what's owned and worn.
CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY,
  created TEXT NOT NULL,
  name TEXT NOT NULL,
  owns TEXT NOT NULL DEFAULT '[]', -- the looks bought, as a JSON list of ids
  look TEXT                        -- the look worn
);
-- The ways into an account: Google (subject: Google's id for the person)
-- or a passkey (subject: its credential id; key: its public key, SPKI).
CREATE TABLE IF NOT EXISTS logins (
  kind TEXT NOT NULL,
  subject TEXT NOT NULL,
  account TEXT NOT NULL,
  key TEXT,
  alg INTEGER,
  counter INTEGER NOT NULL DEFAULT 0,
  added TEXT NOT NULL,
  PRIMARY KEY (kind, subject)
);
CREATE INDEX IF NOT EXISTS logins_account ON logins (account);
-- Signed-in sessions, by a hash of their token.
CREATE TABLE IF NOT EXISTS sessions (
  hash TEXT PRIMARY KEY,
  account TEXT NOT NULL,
  created TEXT NOT NULL
);
-- Each device's anonymous id (rounds.player) and the account it signed in to.
CREATE TABLE IF NOT EXISTS account_players (
  player TEXT PRIMARY KEY,
  account TEXT NOT NULL,
  linked TEXT NOT NULL
);
-- One-time things that expire: sign-in challenges, Google's state, tickets.
CREATE TABLE IF NOT EXISTS challenges (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  value TEXT NOT NULL,
  expires INTEGER NOT NULL
);
