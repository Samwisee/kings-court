# Bug report worker

Turns "Report a bug" in the game into a GitHub issue labelled `bug` and
`from-game`, with the whole game state attached.

## Set up (once, about 10 minutes)

1. **GitHub token**: GitHub > Settings > Developer settings > Fine-grained
   tokens > Generate. Repository access: only `Samwisee/kings-court`.
   Permissions: Issues, read and write. Copy the token.
2. **Worker**: sign up at dash.cloudflare.com (free). Workers & Pages >
   Create > Create Worker > name it `kings-court-bugs` > Deploy > Edit code.
   Replace the code with `worker.js` from this folder and deploy.
3. **Settings**: in the Worker's Settings > Variables and Secrets add
   - `GITHUB_TOKEN`, type Secret: the token from step 1
   - `REPO`, Text: `Samwisee/kings-court`
   - `ALLOW_ORIGIN`, Text: `https://samwisee.github.io`
4. **Tell the game**: copy the Worker's URL
   (`https://kings-court-bugs.<you>.workers.dev`), then in the kings-court
   repo: Settings > Secrets and variables > Actions > Variables > New
   repository variable `BUG_REPORT_URL` = that URL. Re-run the
   "Test and deploy" workflow (or push anything).

Until step 4 is done, the game copies the report for the player to paste
into a message instead.

## Reading a report

The issue holds the game as saved. In a test:

```dart
final j = jsonDecode(reportJson) as Map<String, dynamic>;
final game = GameState.fromJson(Map<String, dynamic>.from(j['state']))!;
```
