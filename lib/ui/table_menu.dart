part of 'table_page.dart';

/// The bar along the top, its menu and what each choice does, and the outcome over the table.
extension _Menu on HomePageState {
  /// The menu button: its bars fold into a cross while the menu is open.
  Widget _buildMenu() => Tooltip(
        message: Strings.menu,
        child: GoldBar(
          onTap: _openMenu,
          semanticLabel: 'Menu',
          child: OrnateMenuIcon(open: _menuOpen),
        ),
      );

  /// The menu: an ornate panel that drops down from the corner.
  Future<void> _openMenu() async {
    _ui(() => _menuOpen = true);
    final choice = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close the menu',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 260),
      // Settings switch in place and the menu stays open; anything that
      // goes somewhere closes it.
      pageBuilder: (context, _, __) => OrnateMenu(
        entries: _menuEntries,
        onToggle: _onMenuChoice,
      ),
      transitionBuilder: (context, a, _, child) {
        final t = Curves.easeOutCubic.transform(a.value);
        return Opacity(
          opacity: a.value,
          child: Transform.translate(offset: Offset(0, -14 * (1 - t)), child: child),
        );
      },
    );
    if (mounted) _ui(() => _menuOpen = false);
    if (choice == null || !mounted) return;
    _onMenuChoice(choice);
  }

  void _onMenuChoice(String choice) {
        Analytics.event([
          'menu',
          choice,
          if (choice == 'sound') Sfx.enabled ? 'off' : 'on',
          if (choice == 'suits') Settings.fourColourSuits ? 'off' : 'on',
          if (choice == 'keys') _showKeys ? 'off' : 'on',
          if (choice == 'share') GameLog.sharing ? 'off' : 'on',
        ]);
        switch (choice) {
          case 'main':
            unawaited(_mainMenu());
          case 'rules':
            showRulesPage(context, game: RulesContext.of(game));
          case 'shuffle':
            _shuffleTasks();
          case 'upright':
            _set(() {
              _upright = !_upright;
              if (_inGame && _table.dealtFor == game.dealId) _table.layoutOwned(_geo);
            });
            _saveSettings();
          case 'sound':
            _set(() => Sfx.enabled = !Sfx.enabled);
            _saveSettings();
          case 'keys':
            _ui(() => _showKeys = !_showKeys);
            _saveSettings();
          case 'bug':
            showBugReport(context, details: _bugDetails);
          case 'invite':
            _room?.invite().then((words) => words != null && mounted ? _showSnack(words, context.skin.feltDeep) : null);
          case 'leave': // a courtier takes your seat; back to the front page
            _leaveRoom();
            _set(() => game = GameState());
            _keepAwake(false);
          case 'skin':
            showLivery(context, wear: _wear);
          case 'nextLivery': // the benchmark's way through every skin
            if (skinAfter(context.skin, (s) => SkinScope.owns(context, s)) case final next?) _wear(next);
          case 'share':
            _set(() => GameLog.sharing = !GameLog.sharing);
            _saveSettings();
          case 'suits':
            _set(() => Settings.fourColourSuits = !Settings.fourColourSuits);
            // Every card on screen repaints in the new colours, even ones
            // built once and kept.
            void rebuild(Element e) {
              e.markNeedsBuild();
              e.visitChildren(rebuild);
            }
            (context as Element).visitChildren(rebuild);
            _saveSettings();
        }
  }

  List<MenuEntry> _menuEntries() => menuEntries(
        room: _room?.room.code,
        mainMenu: _inGame && _setupArgs == null,
        shuffle: _inGame && _setupArgs == null,
        // Only round a real table does the view need turning.
        upright: _inGame && !_digital ? _upright : null,
        look: context.skin.name,
        keys: HomePageState._desktop ? _showKeys : null,
        share: GameLog.sharing,
      );

  Map<String, dynamic> _bugDetails() => bugDetails(_inGame ? game : null,
      moves: _inGame ? _link.history : const [],
      settingUp: _setupArgs != null,
      keyboard: _showKeys,
      room: _room?.details());

  PreferredSizeWidget _buildAppBar() => GameBar(
      title: GameBar.titleOf(game),
      choosingKing: _choosingKing,
      decree: _round.decree,
      onDecree: () => showDecree(context, _round, game.players),
      passer: GameBar.passerOf(game),
      onPass: () => _pass(_round.pickTurn!),
      target: game.target,
      onPoints: _showPointsDialog,
      menu: _buildMenu());

  /// The table keeps a fixed text size so its layout always fits; dialogs
  /// and the rules still follow the phone's text size setting.
  Widget _buildTable() {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.0,
      child: RoundTable(
        table: _table,
        game: game,
        geometry: () => _geo,
        onScreen: _digital,
        choosingKing: _choosingKing,
        crowning: _crowning,
        crownAnimation: _crown,
        playAnimation: _play,
        readyToDeal: _readyToDeal,
        onDeal: () {
          if (mounted && _readyToDeal) _set(_dealCards);
        },
        // While choosing the King a tap crowns. During play a tap opens the
        // courtier's card, or with no roles just flips the card-reveal
        // token.
        seatTap: (i) => _choosingKing
            ? (_digital ? null : () => _sendCrown(i))
            : game.hasRoles
                ? () => _showCourtier(i)
                : () => _toggleSpoke(i),
        cardText: _cardText,
        onTaskTap: _showTaskDetail,
        onDragStart: _onDragStart,
        onDragUpdate: _onDragUpdate,
        onDragEnd: _onDragEnd,
      ),
    );
  }

  /// The end of a round. A win rains gold crowns and confetti and the
  /// result springs up; a loss pulses red and the result drops in with a
  /// shudder. Either way you can set the points for the next round here.
  /// The round's result, over the table.
  Widget _buildOutcomeOverlay() {
    final won = game.outcome == RoundOutcome.won;
    return OutcomeOverlay(
      animation: _outcome,
      won: won,
      dealId: game.dealId,
      child: game.isTutorial
          ? LessonCard(
              lesson: game.lesson, won: won, onRetry: _retryRound, onNext: _nextLesson)
          : OutcomeCard(
              game: game,
              won: won,
              you: _you,
              onScreen: _digital,
              crowns: _effects?.crowns ?? 0,
              nextTarget: _nextTarget,
              canUndo: game.lastMark != null,
              wording: _cardText,
              onRetry: _retryRound,
              onDeal: (target) => _shuffleTasks(target: target),
              onChapter: _beginChapter,
              onUndo: _undoLastMark),
    );
  }
}
