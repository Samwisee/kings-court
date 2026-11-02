/// Dynasty's first act, as data: the projects the King may set the court to,
/// and the petitions the court brings. Every stage names a task in the
/// task library (engine/tasks.dart); dynasty_test checks they all exist.
library;

import '../../../game/courtiers.dart';
import '../realm.dart';

const _d = Courtier.duke, _b = Courtier.bishop, _g = Courtier.general;
const _m = Courtier.merchant, _s = Courtier.spymaster, _j = Courtier.jester;
const _people = Meter.people, _army = Meter.army, _stores = Meter.stores;

/// The act's keystone: finished, the act is won.
const cathedral = Project('cathedral', 'Raise the cathedral', _people,
    keystone: true,
    stages: [
      'Win at least four ♠ cards',
      'Win the A♥ and the 9♥',
      'Win the Joker, the Jack and the Queen',
      'Win the last trick with a Court Card',
    ],
    reward: Effect(meters: {_people: 3, _stores: 1}),
    failure: Effect(meters: {_stores: -1}, coffers: -2),
    done: 'The cathedral stands. Its bells ring your name across the realm.',
    failed: 'A wall of the cathedral falls. Stone and gold, both lost.');

const projects = <Project>[
  cathedral,
  Project('temple', 'Mend the temple roof', _people,
      stages: ['Win the 9♠', 'Win at least six ♥ cards'],
      reward: Effect(meters: {_people: 2}, loyalty: {_b: 1}),
      failure: Effect(meters: {_people: -1}),
      done: 'The temple is dry again. The faithful bless the crown.',
      failed: 'Rain pours on the faithful. They mutter at the door.'),
  Project('missing', 'Search for the miller’s daughter', _people,
      stages: ['Win the 3♥', 'Win a trick where no one followed suit'],
      reward: Effect(meters: {_people: 2}, loyalty: {_s: 1}),
      failure: Effect(meters: {_people: -2}),
      done: 'She is found, alive, and talks of what she saw.',
      failed: 'The search turns up nothing. The village stops looking to the crown.'),
  Project('levy', 'Raise the levy', _army,
      stages: ['Win at least five ♣ cards', 'Win the 8♣'],
      reward: Effect(meters: {_army: 2}, loyalty: {_g: 1}),
      failure: Effect(meters: {_people: -1}),
      done: 'Fresh companies drill in the yard.',
      failed: 'The levy goes badly. Farms lose sons for nothing.'),
  Project('border', 'Fortify the border', _army,
      stages: ['Win the 6♣', 'Win the 7♥ and the 7♣', 'Win the last trick with a Court Card'],
      reward: Effect(meters: {_army: 3}),
      failure: Effect(meters: {_army: -1}),
      done: 'Stone towers watch the border now.',
      failed: 'A half-built fort is burned in the night.'),
  Project('bandits', 'Hunt the bandits', _army,
      stages: ['Win a trick with a 7'],
      reward: Effect(meters: {_people: 1, _army: 1}),
      failure: Effect(meters: {_army: -1}),
      done: 'The north road is safe again.',
      failed: 'The bandits slip away, and laugh about it.'),
  Project('granaries', 'Fill the granaries', _stores,
      stages: ['Win the 5♠ and the 5♣', 'Win at least four ♠ cards'],
      reward: Effect(meters: {_stores: 3}),
      failure: Effect(meters: {_stores: -1}),
      done: 'The granaries are full for winter.',
      failed: 'Rats get into the grain.'),
  Project('bridge', 'Mend the river bridge', _stores,
      stages: ['Win the A♠', 'Win a trick with a 5'],
      reward: Effect(meters: {_stores: 1}, coffers: 3, loyalty: {_d: 1}),
      failure: Effect(meters: {_stores: -1}),
      done: 'Carts cross the river again, and pay the toll.',
      failed: 'The bridge gives way under a loaded cart.'),
  Project('tax', 'Tax the guilds', null,
      stages: ['Win at least five ♦ cards', 'Win the A♦'],
      reward: Effect(coffers: 8, meters: {_people: -1}, loyalty: {_m: -1}),
      failure: Effect(coffers: -2),
      done: 'The guilds pay, and grumble.',
      failed: 'The tax collectors are chased out of the market.'),
  Project('feast', 'Hold the harvest feast', _people,
      stages: ['Win the 8♥'],
      reward: Effect(meters: {_people: 2, _stores: -1}),
      failure: Effect(meters: {_people: -1}),
      done: 'The whole town eats at the crown’s table.',
      failed: 'The feast is a shambles. Who planned this?'),
];

Project projectById(String id) => projects.firstWhere((p) => p.id == id);

/// The petitions, brought at random between hands (see run.dart).
final petitions = <Petition>[
  Petition('roads', _g, [
    (who: _g, text: 'Bandits on the north road, Your Grace. Give me men and I will clear it.'),
  ], [
    Choice('Send the army', Effect(meters: {_army: -1}, project: 'bandits', sits: [_g], loyalty: {_g: 1}),
        said: 'The General salutes and marches out.'),
    Choice('Let the villages fend', Effect(meters: {_people: -1}, loyalty: {_g: -1}),
        said: 'The villages fend, badly.'),
  ]),
  Petition('loan', _m, [
    (who: _m, text: 'A loan, Your Grace. Fair interest. Practically a gift.'),
  ], [
    Choice('Take the loan', Effect(coffers: 8, loyalty: {_m: 1}, sits: [_m]),
        said: 'Gold comes in. The Merchant smiles a little too long.'),
    Choice('Refuse', Effect(loyalty: {_m: -1}), said: 'The Merchant bows, stiffly.'),
  ]),
  Petition('roof', _b, [
    (who: _b, text: 'The temple roof leaks on the faithful. They pray in puddles.'),
  ], [
    Choice('Pay for the work', Effect(project: 'temple', loyalty: {_b: 1}, sits: [_b]),
        cost: 4, said: 'Masons climb the temple roof.'),
    Choice('Pray for dry weather', Effect(meters: {_people: -1}, loyalty: {_b: -1}),
        said: 'It rains.'),
  ]),
  Petition('tenants', _d, [
    (who: _d, text: 'My tenants refuse their rents. Lend me your soldiers.'),
  ], [
    Choice('Send soldiers', Effect(meters: {_army: -1, _people: -1}, coffers: 3, loyalty: {_d: 1}, sits: [_d]),
        said: 'The rents are paid, and resented.'),
    Choice('Refuse', Effect(loyalty: {_d: -1}), said: 'The Duke will remember this.'),
  ]),
  Petition('miller', _s, visitor: true, [
    (who: _s, text: 'A miller’s daughter is missing. She saw something she should not have.'),
    (who: null, text: 'The Spymaster waits, as if they already know your answer.'),
  ], [
    Choice('Find her', Effect(project: 'missing', joins: _s, sits: [_s]),
        said: 'The Spymaster takes a seat at your table.'),
    Choice('Leave it', Effect(meters: {_people: -1}), said: 'The village hears the crown did nothing.'),
  ]),
  Petition('jest', _j, visitor: true, [
    (who: _j, text: 'Your Grace’s crown sits crooked! Shall I make the court laugh?'),
  ], [
    Choice('Let them perform', Effect(meters: {_people: 1}, joins: _j, sits: [_j]),
        cost: 2, said: 'The court laughs. Even the Duke.'),
    Choice('Send them away', Effect(), said: 'The Jester cartwheels out, unbothered.'),
  ]),
  Petition('harvest', _m, [
    (who: _m, text: 'The harvest fair needs coin, or there is no fair.'),
  ], [
    Choice('Fund the fair', Effect(project: 'feast', meters: {_people: 1}, loyalty: {_m: 1}),
        cost: 4, said: 'Stalls go up in the square.'),
    Choice('No fair this year', Effect(meters: {_people: -1}), said: 'The square stays empty.'),
  ]),
  Petition('forts', _g, [
    (who: _g, text: 'The border forts are crumbling. One good push and they fall.'),
  ], [
    Choice('Rebuild them', Effect(project: 'border', sits: [_g], loyalty: {_g: 1}),
        said: 'The General gets to work.'),
    Choice('They’ll hold', Effect(meters: {_army: -1}, loyalty: {_g: -1}),
        said: 'They do not quite hold.'),
  ]),
  Petition('abbey', _d, [
    (who: _d, text: 'The abbey’s fields border mine. They would be better farmed by me.'),
    (who: _b, text: 'Those fields feed the poor, Your Grace.'),
  ], [
    Choice('Side with the Duke', Effect(coffers: 3, loyalty: {_d: 1, _b: -2}, sits: [_d], away: [_b]),
        said: 'The Bishop leaves the hall without a word.'),
    Choice('Side with the Bishop', Effect(meters: {_people: 1}, loyalty: {_b: 1, _d: -2}, sits: [_b], away: [_d]),
        said: 'The Duke smiles, the way a knife does.'),
  ]),
  Petition('winter', _b, [
    (who: _b, text: 'Winter comes early, and the granaries are low.'),
  ], [
    Choice('Fill the granaries', Effect(project: 'granaries', sits: [_b, _d]),
        said: 'Carts roll in from the farms.'),
    Choice('Ration the city', Effect(meters: {_stores: 1, _people: -2}),
        said: 'Bread is short in the city.'),
  ]),
  Petition('guilds', _m, [
    (who: _m, text: 'The soldiers want paying. The guilds could pay… or your coffers could.'),
  ], [
    Choice('Tax the guilds', Effect(project: 'tax', loyalty: {_m: -2, _g: 1}),
        said: 'The Merchant’s face is very still.'),
    Choice('Pay from the coffers', Effect(meters: {_army: 1}, loyalty: {_g: 1}),
        cost: 5, said: 'The soldiers drink to your health.'),
  ]),
  Petition('bridge', _d, when: (m, c) => (m[_stores] ?? 0) < 6, [
    (who: _d, text: 'The river bridge is failing. Trade will stop with it.'),
  ], [
    Choice('Mend it', Effect(project: 'bridge', sits: [_d]), cost: 2, said: 'Timber is hauled to the river.'),
    Choice('Use the ford', Effect(meters: {_stores: -1}), said: 'Carts are lost in the ford.'),
  ]),
];
