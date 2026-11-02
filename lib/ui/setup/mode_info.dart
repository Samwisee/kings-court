/// What each way to play is about, as the New Game panel's first step
/// shows it.
library;

import '../../game/state.dart';

/// What each way to play is about, shown on the first step.
const modeInfo = {
  GameMode.free: (
    'Free play',
    'Choose a points target; add surprise seals and decrees if you like.'
  ),
  GameMode.endless: (
    'Endless',
    'Each win adds a point to the next round. How long can your streak last?'
  ),
  GameMode.chronicle: (
    'The Chronicle',
    '24 chapters of rising difficulty. Earn up to three crowns for each.'
  ),
  GameMode.dynasty: (
    'Dynasty',
    'A story of kings. Rule until wounds bring you down; face dilemmas, keep your courtiers loyal, watch for traitors.'
  ),
  GameMode.tutorial: (
    'Tutorial',
    'New to the court? Four short, guided rounds teach you to lead, follow, use Court Cards and help each other.'
  ),
};
