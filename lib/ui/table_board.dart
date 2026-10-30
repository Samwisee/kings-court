part of 'table_page.dart';

/// The on-screen card table: the seats, the middle with its tasks and trick, and what flies between them.
extension _Board on HomePageState {
  /// Where a widget sat on the on-screen table last frame (safe mid-build).
  Rect? _rectOn(GlobalKey key) {
    final box = (key.currentContext as Element?)?.renderObject as RenderBox?;
    final table = (_digiKey.currentContext as Element?)?.renderObject as RenderBox?;
    if (box == null || table == null || !box.attached || !box.hasSize) {
      return null;
    }
    // Global positions, since your hand sits below the table itself.
    return (box.localToGlobal(Offset.zero) - table.localToGlobal(Offset.zero)) &
        box.size;
  }

  /// Sends each newly taken task flying from the middle to its owner.
  void _launchTaskFlights() {
    if (!_digital) return;
    _tasks.launch(game.tasks,
        rectOn: _rectOn,
        flight: (t, from, to, toFont) => Flight(skin: context.skin, t, from, to, _points(t), _cardText(t),
            fromFont: _tasks.openFontSize,
            toFont: toFont,
            toColor: t.owner == null ? context.skin.inkSoft : game.players[t.owner!].color),
        mounted: () => mounted,
        update: setState);
  }

  Widget _buildDigitalTable() {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.0,
      child: LayoutBuilder(builder: (context, c) {
        _table.tableSize = Size(c.maxWidth, c.maxHeight);
        final width = c.maxWidth - 32;
        return Stack(
          key: _digiKey,
          clipBehavior: Clip.none,
          children: [
            Padding(
              // Room above the tokens so a King's crown clears the edge.
              // On a phone the courtiers sit higher, leaving more room for
              // tasks and cards.
              padding: EdgeInsets.fromLTRB(16, width < 600 ? 8 : 16, 16, 4),
              child: Column(
                children: [
                  // As much room as the bots' tasks need, leaving enough for
                  // the trick and your own row.
                  // (The middle always keeps room for a full-size trick.)
                  _digiOpponents(
                      width,
                      clampD(
                          c.maxHeight -
                              120 -
                              PlayingCardView.heightFor(trickCardWidth(
                                  width, game.players.length)),
                          110,
                          math.max(110.0, c.maxHeight * 0.6))),
                  Expanded(
                    child: SizedBox(
                      key: _middleKey,
                      width: double.infinity,
                      child: _digiMiddle(width),
                    ),
                  ),
                  KeyedSubtree(key: _yourRowKey, child: _digiYou(width)),
                ],
              ),
            ),
            for (final f in _tasks.flights) f.build(),
            if (_crowning != null)
              Positioned.fill(child: IgnorePointer(child: _digiCrowning())),
            Positioned.fill(child: IgnorePointer(child: PlayFlourish(animation: _play))),
          ],
        );
      }),
    );
  }

  bool _seatActive(int seat) =>
      !_choosingKing &&
      (_round.pickTurn != null
          ? _round.pickTurn == seat
          : _playing && _lastTrick == null && _round.turn == seat);

  /// What tapping a seat does: their courtier's card, or (without roles)
  /// asking them to show a card.
  VoidCallback? _seatTap(int seat) => _choosingKing
      ? null
      : game.hasRoles
          ? () => _showCourtier(seat)
          : _digital && seat != _you
              ? () => _askToSpeak(seat)
              : null;

  Widget _digiToken(int seat, double size, {bool tight = false}) {
    final labels = seatLabels(game.players);
    // Each courtier springs in when they first come to the
    // table; the same courtier keeps the same token as they move seats.
    return CharacterToken(
        key: ValueKey('person-${game.hasRoles && seat < game.courtiers.length ? game.courtiers[seat].name : seat}'),
        mood: CharacterMood.arriving,
        delay: Duration(milliseconds: 150 * seat),
        size: size,
        child: KeyedSubtree(
        key: _seatKey(seat),
        child: SeatToken(
        player: game.players[seat],
        label: labels[seat],
        isKing: _round.king == seat,
        size: size,
        highlighted: _seatActive(seat),
        exiled: _round.exiledSeat == seat,
        shape: game.hasRoles && seat < game.courtiers.length
            ? game.courtiers[seat].shape
            : null,
        // Tap a courtier to ask them to show a card (once a round).
        onTap: _seatTap(seat),
        tight: tight,
      ),
      ),
    );
  }

  /// A task in front of its owner. It's laid out as soon as the task is
  /// taken, but kept hidden while its flying copy travels there: the
  /// flight lands exactly on it, then it shows, so nothing jumps.
  Widget _miniTask(RoundTask t, double width, {double fontSize = 12}) {
    final skin = context.skin;
    _tasks.miniStyle[t] = (width, fontSize);
    return Opacity(
        key: ValueKey('mini-${t.description}'),
        opacity: _tasks.landing.contains(t) ? 0 : 1,
        child: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: KeyedSubtree(
            key: _tasks.destKeys.putIfAbsent(t, GlobalKey.new),
            child: TaskChip(
            task: t,
            points: _points(t),
            text: _cardText(t),
            color: t.owner == null
                ? skin.inkSoft
                : game.players[t.owner!].color,
            width: width,
            fontSize: fontSize,
            progress: _progressOf(t),
            struck: _wonNamed(t),
            focused: _kbRow == 1 && _kbTask == t,
            onTap: () => _showTaskDetail(t, Offset.zero),
            onLongPress: () => _showTaskDetail(t, Offset.zero),
          ),
          ),
        ),
      );
  }

  /// The crowning on the on-screen table: from the middle of the table to
  /// the new King's token, with a trumpet from everyone else.
  Widget _digiCrowning() => AnimatedBuilder(
        // Measured afresh every frame, so the crown lands where the token
        // is even if the table is still settling.
        animation: _crown,
        builder: (context, _) => _digiCrowningNow(),
      );

  Widget _digiCrowningNow() {
    final king = _crowning;
    if (king == null || !_crown.isAnimating) return const SizedBox.shrink();
    final middle = _rectOn(_middleKey);
    final seat = _rectOn(_seatKey(king));
    if (middle == null || seat == null) return const SizedBox.shrink();
    // From the walk-in's crown: the middle of the screen, in the table's
    // own coordinates, at that crown's size.
    final table = _digiKey.currentContext?.findRenderObject() as RenderBox?;
    final screen = MediaQuery.sizeOf(context);
    final centre = table == null || !table.attached
        ? middle.center
        : screen.center(Offset.zero) - table.localToGlobal(Offset.zero);
    return CrowningScene(
      animation: _crown,
      from: _crownFromCentre ? centre : middle.center,
      startSize: _crownFromCentre
          ? math.min(screen.width, screen.height) * 0.28
          : null,
      // The crown sits in the slot above the token.
      to: seat.topCenter + const Offset(0, 8),
      spinTo: 0,
      seatSize: 44,
      king: king,
      seats: {
        for (int j = 0; j < game.players.length; j++)
          if (_rectOn(_seatKey(j)) case final r?) j: r.center
      },
    );
  }

  /// The bots across the top, each with their tasks under them.
  Widget _digiOpponents(double width, double maxHeight) {
    final c = _round;
    final big = width > 600;
    return OpponentsRow(
      // Round the table from you, in the order of play.
      seats: [for (var k = 1; k < game.players.length; k++) (_you + k) % game.players.length],
      width: width,
      maxHeight: maxHeight,
      name: (i) => game.hasRoles && i < game.courtiers.length && !_personAt(i)
          ? game.courtiers[i].short
          : game.players[i].name,
      token: (seat, size) => _withReveal(seat, _digiToken(seat, size, tight: true), size: size),
      onTap: _seatTap,
      // Trick counts once the tricks begin; their room is kept from the
      // start, so nothing shifts when they appear.
      tallyShown: c.hasCards && (_playing || c.tricks.isNotEmpty),
      won: _shownTricksWon,
      tally: (seat) => '${c.hasCards ? c.cardsIn(seat) : 0} cards',
      pileKey: _pileKey,
      tasks: (seat) => [for (final t in game.tasks) if (t.owner == seat) t],
      task: _miniTask,
      quip: (seat) => _quips[seat],
      tokenSize: big ? 48 : 38,
      taskWidth: big ? 170 : 130,
    );
  }

  Widget _withReveal(int seat, Widget token, {required double size}) =>
      withShownCard(token, _revealedView(seat, height: size), size: size);

  Widget? _revealedView(int seat, {double height = 40}) =>
      shownCard(context.skin, _round, seat, game.players[seat].color, height: height);

  Widget _digiYou(double width) => YourSeat(
        width: width,
        token: _digiToken(_you, 40),
        shown: _revealedView(_you),
        tallyShown: _round.hasCards && (_playing || _round.tricks.isNotEmpty),
        won: _shownTricksWon(_you),
        pileKey: _pileKey(_you),
        tasks: [for (final t in game.tasks) if (t.owner == _you) t],
        task: _miniTask,
        scrolled: _youScrolled,
      );

  Widget _digiMiddle(double width) {
    if (_choosingKing) return const SizedBox.expand();
    final open = [for (final t in game.tasks) if (t.owner == null) t];
    if (open.isEmpty && _tasks.landing.isEmpty && _tasks.flights.isEmpty) {
      // The trick, laid out right here so it always shows.
      return LayoutBuilder(
        builder: (context, box) => Stack(
          clipBehavior: Clip.none,
          children: _trickCards(box.biggest),
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tasks.openRects = {
        for (final e in _tasks.openKeys.entries)
          if (e.key.owner == null)
            if (_rectOn(e.value) case final r?) e.key: r,
      };
    });
    // Bigger on a big screen, where there's room to read them easily.
    final big = width > 600;
    final w = math.min(big ? 200.0 : 130.0, (width - 16) / 3);
    _tasks.openFontSize = big ? 16 : 13;
    // Open tasks, and any still flying to their owner. Once a taken task
    // has landed the rest close up, so the middle never runs out of room.
    final slots = [
      for (final t in game.tasks)
        if (t.owner == null ||
            _tasks.landing.contains(t) ||
            _tasks.flights.any((f) => f.task == t))
          t
    ];
    // The deal: first laid out unseen to find each task's place, then
    // dealt from a pile in the middle out to those places.
    final measured = _dealMeasuredFor == game.dealId;
    if (!measured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _dealMeasuredFor == game.dealId) return;
        final middle = _rectOn(_middleKey);
        if (middle == null) return;
        _set(() {
          _dealFrom = {
            for (final t in slots)
              if (_tasks.openKeys[t] case final key?)
                if (_rectOn(key) case final r?) t: middle.center - r.center,
          };
          _dealMeasuredFor = game.dealId;
        });
      });
    }
    // A moment as a pile before the first card goes.
    const pileMs = 300;
    // Packed in columns so short and tall cards fill the space; when one
    // is taken the rest glide to their new places.
    final taskChips = <Widget>[
        for (int i = 0; i < slots.length; i++)
          KeyedSubtree(
            key: ValueKey('slot-${slots[i].description}'),
            child: () {
            final t = slots[i];
            final taken = t.owner != null;
            // Who could take it: a task only one player may take is marked
            // in their colour, so the table knows it's theirs to choose.
            // Only what everyone can see: your own hand counts for you,
            // but nobody else's cards do.
            final able = [
              for (int s = 0; s < game.players.length; s++)
                if (s == _you
                    ? _round.mayTake(t, s)
                    : _round.whyCantTake(t, s, publicOnly: true) == null)
                  s
            ];
            final only = !taken && able.length == 1 ? able.single : null;
            final chip = OpenTask(
              placeKey: _tasks.openKeys.putIfAbsent(t, GlobalKey.new),
              task: t,
              taken: taken,
              faded: _yourPick && !_mayTake(t) && only == null,
              points: _points(t),
              text: _cardText(t),
              width: w,
              fontSize: big ? 16 : 13,
              focused: _kbRow == 1 && _kbTask == t,
              only: only == null
                  ? null
                  : (
                      only == _you
                          ? 'Only you can take this'
                          : 'Only ${game.players[only].name} can take this',
                      game.players[only].color
                    ),
              // A tap reads it; press and hold to take it, so taking a
              // task is always meant.
              onTap: () => _showTaskDetail(t, Offset.zero),
              onLongPress: () => _yourPick ? _takeTask(t) : _showTaskDetail(t, Offset.zero),
            );
            if (!measured) return Opacity(opacity: 0, child: chip);
            return DealtTask(
              key: ValueKey('deal-${game.dealId}-${t.description}'),
              index: i,
              from: _dealFrom[t] ?? Offset.zero,
              startMs: pileMs + i * 170,
              child: chip,
            );
          }(),
          ),
    ];
    // Full size, always readable; on the rare table with no room left the
    // middle scrolls rather than spilling over anything. The tasks centre
    // themselves in the middle, so when they close up (two rows to one)
    // they glide to the new centre too.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: Masonry(
          key: _middleTasksKey,
          columnWidth: w,
          minHeight: box.maxHeight.isFinite ? box.maxHeight : 0,
          children: taskChips,
        ),
      ),
    );
  }

  bool _mayTake(RoundTask t) => _round.decree == Decree.kingsCommand || _round.mayTake(t, _you);

  /// Your pick: take a task. Under King's Command you're the King handing
  /// tasks out, so choose who gets it.
  Future<void> _takeTask(RoundTask t) async {
    if (_round.decree != Decree.kingsCommand) {
      if (!_round.mayTake(t, _you)) {
        _showSnack(_round.whyCantTake(t, _you)!, context.skin.feltDeep);
        return;
      }
      _assignTask(t, _you);
      return;
    }
    final seats = [
      for (int s = 0; s < game.players.length; s++)
        if (_round.mayTake(t, s)) s
    ];
    final seat = await showWhoTakesDialog(context, seats: seats, players: game.players);
    if (seat != null && mounted && t.owner == null) {
      _assignTask(t, seat);
    }
  }

  /// The trick in the middle of the table (ui/table/trick_view.dart):
  /// each card from where it was played, and a won trick to its pile.
  List<Widget> _trickCards(Size area) => trickCardsOnTable(
      area: area,
      round: _round,
      trick: _lastTrick,
      collecting: _collecting,
      players: game.players,
      you: _you,
      middle: _rectOn(_middleKey),
      hand: _rectOn(_handKey),
      launchedFrom: (card) => _launchFrom[card.id],
      seatAt: (seat) => _rectOn(_seatKey(seat)),
      pileAt: (seat) => _rectOn(_pileKey(seat)));

  /// The speech token can be asked for at any time in the round, even
  /// while tasks are picked: it's used at the next gap between tricks.
  bool get _mayAskToSpeak =>
      _digital &&
      _inGame &&
      !_choosingKing &&
      game.outcome == RoundOutcome.inProgress &&
      _round.hasCards &&
      _round.hands.length > _you &&
      _round.hands[_you].isNotEmpty &&
      _round.spoke.length > _you &&
      !_round.spoke[_you] &&
      _round.canSpeak(_you);

  /// Speak now if it's between tricks, otherwise as soon as this trick is
  /// over. The table waits while you choose.
  void _speak() {
    if (_revealing) {
      _set(() => _revealing = false);
      return;
    }
    if (!_mayAskToSpeak) return;
    // Mid-trick, you speak as soon as the trick is over. Otherwise, while
    // tasks are being chosen or between tricks, right away.
    if (_round.current.isNotEmpty || _lastTrick != null) {
      _set(() => _wantsToSpeak = !_wantsToSpeak);
      return;
    }
    if (!_round.hands[_you].any((c) => _round.revealFor(_you, c) != null)) {
      _showSnack(
          'Nothing you may show: only your highest, lowest or only card of a suit',
          context.skin.feltDeep);
      return;
    }
    _set(() => _revealing = true);
  }

  /// Shows [card] for [seat]: sends the move, which shows it when it
  /// comes back. The card stays in their hand, face up for all.
  void _reveal(int seat, PlayingCard card) {
    if (_round.revealFor(seat, card) == null) return;
    _link.send(ShowCard(seat, card));
  }

  /// You ask a courtier to show a card. They show one a task needs if they
  /// can, else one that says the most (the only card of its suit, or the
  /// highest of their longest suit).
  void _askToSpeak(int seat) {
    if (!_round.hasCards || game.outcome != RoundOutcome.inProgress) return;
    switch (courtierShow(game, seat)) {
      case (no: final String no, card: _):
        _showSnack(no, context.skin.feltDeep);
      case (no: _, card: final PlayingCard card):
        _haptic(HapticFeedback.selectionClick);
        _reveal(seat, card);
    }
  }
}
