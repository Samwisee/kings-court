/// Passkeys and the page's address, off the web: none (the apps don't
/// offer signing in yet).
library;

class PasskeyError implements Exception {
  PasskeyError(this.message);
  final String message;
}

bool passkeysHere() => false;

Future<Map<String, Object?>?> createPasskey({required String challenge, required String user, required String name}) async =>
    throw PasskeyError('Passkeys work in the web game for now');

Future<Map<String, Object?>?> usePasskey({required String challenge}) async =>
    throw PasskeyError('Passkeys work in the web game for now');

void goTo(String url) {}

void dropFromAddress(String key) {}
