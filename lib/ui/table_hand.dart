part of 'table_page.dart';

/// Your hand, and the card tracker beside it, with what each task needs and has.
extension _Hand on HomePageState {
  /// How far along an on-screen task is ("2/4"), for the card's corner.
  /// How [t] is going, in a sentence for its close-up (on-screen cards
  /// only, once it's been taken).
  String? _statusOf(RoundTask t) {
    if (!_digital ||
        !_round.hasCards ||
        t.owner == null) {
      return null;
    }
    if (t.isCompleted) return 'Done!';
    if (t.isFailed) return 'Failed this round.';
    if (_round.tricks.isEmpty && _round.pickTurn != null) {
      return 'The tricks haven’t started yet.';
    }
    return taskStatus(t.description, _shownView, t.owner!,
        t.x,
        names: [for (final p in game.players) p.name]);
  }

  /// The cards [t] names that its owner has already won, to cross out.
  Set<String> _wonNamed(RoundTask t) => !_digital || !_round.hasCards
      ? const {}
      : wonNamed(_round, t, trickPending: _lastTrick != null);

  void _showCardTracker() {
    if (_trackerOpen) {
      _closeTracker();
      return;
    }
    _trackerTimer?.cancel();
    // First built unseen (the slow frame, if there is one), then faded in,
    // so the fade itself runs smoothly.
    _ui(() {
      _trackerMounted = true;
      _trackerSliding = true;
      _trackerPeek = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _trackerSliding) _ui(() => _trackerOpen = true);
      });
    });
  }

  void _closeTracker() {
    _ui(() {
      _trackerOpen = false;
      _trackerPeek = false;
      _trackerSliding = true;
    });
    _trackerTimer?.cancel();
    _trackerTimer = Timer(HomePageState._trackerSlide + const Duration(milliseconds: 40), () {
      if (mounted && !_trackerOpen) {
        _ui(() {
          _trackerSliding = false;
          _trackerMounted = false;
        });
      }
    });
  }

  List<MarkedCard> _cardStates(RoundTask t) =>
      cardStates(t, round: _round, players: game.players, you: _you, onScreen: _digital);

  String? _progressOf(RoundTask t) {
    if (!_digital ||
        !_round.hasCards ||
        t.owner == null ||
        t.status != TaskStatus.pending) {
      return null;
    }
    return taskProgress(t.description, _shownView, t.owner!,
        t.x);
  }

  /// Colours of the players whose open tasks need [card] won.
  List<Color> _marksFor(PlayingCard card) => [
        for (final t in game.tasks)
          if (t.owner != null &&
              t.status == TaskStatus.pending &&
              neededCards(t.description).contains(card))
            game.players[t.owner!].color
      ];

  /// A task's wording, with the announced number filled in.
  String _cardText(RoundTask t) {
    final text = t.boardText(game.players.length);
    final x = _digital ? t.x : null;
    if (x == null) return text;
    final secret = t.description.contains('secret') && t.owner != _you;
    return text.replaceFirst('X', secret ? '?' : '$x');
  }

  /// What the table says is happening, under the cards.
  String get _cardStatus => tableStatus(game, you: _you, lastTrick: _lastTrick,
      choosingKing: _choosingKing, speakPrompt: _speakPromptDue, othersDeciding: _othersDeciding);

  Widget _buildHand() {
    final skin = context.skin;
    final c = _round;
    // Once a suit is led you may choose your card early; it's played as
    // soon as your turn comes.
    final canQueue = _playing &&
        !_yourPlay &&
        c.hasCards &&
        c.current.isNotEmpty &&
        !c.currentSeats.contains(_you) &&
        _lastTrick == null;
    if (!canQueue && !_yourPlay) _queued = null;
    // Showing a card: only those you may show stand out.
    final showing = _revealing || _speakPromptDue;
    final yourTurn = _yourPlay || showing;
    final legal = showing
        ? {
            for (final card in c.hasCards ? c.hands[_you] : const <PlayingCard>[])
              if (c.revealFor(_you, card) != null) card
          }
        : _yourPlay
            ? c.legalFor(_you).toSet()
            : const <PlayingCard>{};
    return Container(
      width: double.infinity,
      // Room below the cards so they clear the brass trim.
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
      decoration: BoxDecoration(
        color: skin.feltDeep,
        border: Border(top: BorderSide(color: skin.gold.withValues(alpha: 0x66 / 255))),
      ),
      child: Center(
        child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _handLimit),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HandBar(
            choice: !_barChoice
                ? null
                : _speakPromptDue
                    ? HandChoice.show
                    : HandChoice.pass,
            buttonKey: _kbButtonKey,
            buttonFocused: _kbRow == 2,
            onSkip: _skipShowing,
            onPass: _passPick,
            message: _toast != null
                ? _toast!
                : _revealing
                    ? 'Tap a card to show it (highest, lowest or only of its suit)'
                    : _queued != null
                        ? 'You\u2019ll play the ${_queued!.label} on your turn (tap it again to change your mind)'
                        : _wantsToSpeak && _playing
                            ? 'You\u2019ll show a card after this trick'
                            : _cardStatus,
            lit: yourTurn || _yourPick || _revealing,
            onTracker: _round.hasCards ? _showCardTracker : null,
            speech: (
              skipping: _speakPromptDue,
              revealing: _revealing,
              asked: _wantsToSpeak,
              ready: _mayAskToSpeak,
              used: _round.spoke.length > _you && _round.spoke[_you],
            ),
            onSpeak: _speakPromptDue
                ? _skipShowing
                : _mayAskToSpeak || _revealing
                    ? _speak
                    : null,
          ),
          const SizedBox(height: 2),
          LayoutBuilder(builder: (context, box) {
            final hand = c.hasCards ? c.hands[_you] : const <PlayingCard>[];
            final width = box.maxWidth;
            // Wider screens get bigger cards, as far as the height allows.
            final cardW = clampD(
                math.min(width / 6.2, _gameHeight * 0.105),
                44,
                108);
            final h = PlayingCardView.heightFor(cardW);
            if (hand.isEmpty) return SizedBox(height: h + 12);
            final step = hand.length == 1
                ? 0.0
                : math.min(cardW + 6, (width - cardW) / (hand.length - 1));
            final total = cardW + step * (hand.length - 1);
            return SizedBox(
              key: _handKey,
              height: h + 12,
              width: width,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (int i = 0; i < hand.length; i++)
                    () {
                      final card = hand[i];
                      final dragging = _drag.card == card.id;
                      final left = (width - total) / 2 + i * step;
                      if (i == 0) {
                        _handRects.clear();
                        // The card chosen with the arrow keys was played
                        // (or shown), or can't be played now a new trick
                        // has begun: the nearest card you can play is
                        // chosen instead.
                        final kb = _kbCard;
                        final pool = hand.where(legal.contains).toList();
                        if (_kbRow == 0 &&
                            kb != null &&
                            (!hand.contains(kb) ||
                                (pool.isNotEmpty && !pool.contains(kb)))) {
                          final area = _rectOn(_handKey);
                          final from = pool.isEmpty ? hand : pool;
                          final at = hand.indexOf(kb);
                          final lastX = at >= 0
                              ? (width - total) / 2 + at * step + cardW / 2
                              : _kbLast == null || area == null
                                  ? null
                                  : _kbLast!.center.dx - area.left;
                          if (lastX != null) {
                            final x = lastX;
                            _kbCard = from.reduce((a, b) {
                              double d(PlayingCard c) =>
                                  ((width - total) / 2 + hand.indexOf(c) * step + cardW / 2 - x)
                                      .abs();
                              return d(a) <= d(b) ? a : b;
                            });
                          }
                        }
                      }
                      _handRects[card] = Rect.fromLTWH(left, 0, cardW, h);
                      // The card chosen with the arrow keys stands up a
                      // little higher.
                      final chosen = _kbCard == card && _kbRow == 0;
                      final top = chosen
                          ? -8.0
                          : legal.contains(card) || _queued == card
                              ? 0.0
                              : 12.0;
                      // Whether the card went anywhere (played, shown or
                      // queued); a drag that didn't slides back.
                      bool play() {
                        if (_revealing || _speakPromptDue) {
                          if (_round.revealFor(_you, card) == null) {
                            _showSnack(
                                'Only your highest, lowest or only card of a suit can be shown, never a Court Card',
                                skin.feltDeep);
                            return false;
                          }
                          final opening = _speakPromptDue;
                          _reveal(_you, card);
                          if (opening) _startChoosing();
                          return true;
                        }
                        if (!_yourPlay && canQueue) {
                          final ok = legalPlays(c.hands[_you], c.current.first);
                          if (!ok.contains(card)) {
                            final led = c.current.first;
                            _showSnack(
                                led.isCourt
                                    ? 'You must follow with a Court Card'
                                    : 'You must follow ${led.suit.name}',
                                skin.feltDeep);
                            return false;
                          }
                          _set(() => _queued = _queued == card ? null : card);
                          return true;
                        }
                        if (!_yourPlay) return false;
                        if (!legal.contains(card)) {
                          final led = c.led!;
                          _showSnack(
                              led.isCourt
                                  ? 'You must follow with a Court Card'
                                  : 'You must follow ${led.suit.name}',
                              skin.feltDeep);
                          return false;
                        }
                        final area = _rectOn(_handKey);
                        if (area != null) {
                          _launchFrom[card.id] = area.topLeft +
                              Offset(left + cardW / 2, top + h / 2) +
                              (dragging ? _drag.offset.value : Offset.zero);
                        }
                        _playCard(_you, card);
                        return true;
                      }
                      _handPlays[card] = play;

                      return AnimatedPositioned(
                        key: ValueKey(card.id),
                        duration: dragging
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        left: left,
                        top: top,
                        child: ValueListenableBuilder<Offset>(
                          valueListenable: _drag.offset,
                          builder: (context, drag, child) => Transform.translate(
                              offset: dragging || _drag.snapping == card.id
                                  ? drag
                                  : Offset.zero,
                              child: child),
                          child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(
                          onTap: play,
                          // Or drag it up onto the table.
                          onPanStart: (_) => _drag.start(card.id),
                          onPanUpdate: (d) => _drag.move(d.delta),
                          onPanEnd: (_) {
                            final far = _drag.offset.value.dy < -h * 0.6;
                            // Let go first, so the play below is saved.
                            _drag.card = null;
                            if (far && play()) {
                              _ui(() => _drag.offset.value = Offset.zero);
                            } else {
                              _drag.snapBack(card.id);
                            }
                          },
                          onPanCancel: () {
                            _drag.card = null;
                            _drag.snapBack(card.id);
                          },
                          child: HandCard(
                            card: card,
                            width: cardW,
                            index: i,
                            dealId: game.dealId,
                            lifted: dragging,
                            dimmed: yourTurn && !legal.contains(card),
                            glow: (yourTurn && card == _tutorialHint) || _queued == card || chosen,
                            marks: _marksFor(card),
                            // With the shortcuts showing: the key that plays it.
                            keyLabel: _keysShown && i < cardKeyLabels.length ? cardKeyLabels[i] : null,
                          ),
                        )),
                        ),
                      );
                    }(),
                ],
              ),
            );
          }),
        ],
      ),
      ),
      ),
    );
  }
}
