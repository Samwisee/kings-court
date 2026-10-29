/// The game's web service (tool/bug_worker/): bug reports, the rounds
/// played, and the multiplayer rooms. Set when the game is built
/// (`--dart-define=BUG_URL=https://…`); empty means there's none.
library;

const serviceUrl = String.fromEnvironment('BUG_URL');

/// Whether there's a service to reach.
bool get hasService => serviceUrl.isNotEmpty;
