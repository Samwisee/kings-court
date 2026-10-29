/// The words the chrome shows: the menu, the top bar, the front page and
/// the table's small dialogs. Content (the tasks' words, help, lessons,
/// lore) stays in its data files. Constants for now, so the widgets that
/// show them stay const; translating the game would make this an object
/// chosen by locale, beside translated data files (future work).
library;

abstract final class Strings {
  // The top bar.
  static const menu = 'Menu';
  static const pointsTarget = 'Points target';

  // The menu.
  static const newGame = 'New game';
  static const shuffleTasks = 'Shuffle tasks';
  static const howToPlay = 'How to Play';
  static const laptopView = 'Laptop view';
  static const tableView = 'Table view';
  static const sounds = 'Sounds';
  static const fourColourSuits = 'Four-colour suits';
  /// The menu's skin choice, naming the one worn.
  static String look(String name) => 'Look: $name';
  static const locked = '(locked)';
  static const keyboardShortcuts = 'Keyboard shortcuts';
  static const reportBug = 'Report a bug';
  static const leaveRoom = 'Leave the room';
  static String inviteTo(String room) => 'Invite to room $room';
  static const sharePlayData = 'Share play data';

  // The front page.
  static const continueGame = 'Continue';

  // The table's small dialogs.
  static const cancel = 'Cancel';
  static const deal = 'Deal';
  static const announce = 'Announce';
  static const howManyTricks = 'How many tricks?';
  static const playAGame = 'Play a game';
  static const notNow = 'Not now';
  static const pass = 'Pass';
}
