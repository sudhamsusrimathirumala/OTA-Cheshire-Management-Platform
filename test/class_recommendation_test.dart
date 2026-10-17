import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/class_session.dart';
import 'package:ota_cheshire_management_platform/models/student.dart';
import 'package:ota_cheshire_management_platform/services/class_recommendation_service.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service.dart';

void main() {
  Student child(
    int age, {
    String belt = 'Black',
    List<String> preferred = const [],
  }) => Student(
    id: 'child-$age',
    name: 'Child',
    locationId: 'cheshire',
    belt: belt,
    legacyAge: age,
    stickerCount: 0,
    stickersRequired: 0,
    nextRank: belt,
    preferredClassGroupIds: preferred,
  );
  ClassSession session({
    required String id,
    required String name,
    required String type,
    required int hour,
    String group = '',
    List<String> belts = const <String>[],
    String location = 'cheshire',
    bool published = true,
  }) => ClassSession(
    id: id,
    className: name,
    classTypeId: type,
    bulkGroupId: group.isEmpty ? '$type-standard' : group,
    locationId: location,
    startTime: DateTime(2026, 1, 1, hour),
    endTime: DateTime(2026, 1, 1, hour + 1),
    eligibleBelts: belts,
    description: '',
    isPublished: published,
  );

  Student student({required bool older, List<String> preferred = const []}) =>
      Student(
        id: older ? 'older' : 'younger',
        name: 'Student',
        locationId: 'cheshire',
        belt: 'Blue',
        dateOfBirth: older ? DateTime(1990) : DateTime(2018),
        stickerCount: 0,
        stickersRequired: 0,
        nextRank: 'Blue-Red',
        preferredClassGroupIds: preferred,
      );

  final level = session(
    id: 'level',
    name: 'Level 3',
    type: 'level-3',
    hour: 16,
    belts: const ['Blue'],
  );
  final teen = session(
    id: 'teen',
    name: 'Teen & Black Belt',
    type: 'teen-adult',
    hour: 18,
    belts: const ['Black'],
  );

  ClassSession? recommend(Student profile, List<ClassSession> classes) =>
      nextRecommendedClassFromSchedule(
        {DateTime.monday: classes},
        profile,
        currentWeekday: DateTime.monday,
        currentMinutes: 0,
      );

  test('Little Tigers: ages 3-5 are eligible regardless of belt', () {
    final littleTigers = session(
      id: 'tigers',
      name: 'Little Tigers',
      type: 'little-tiger',
      hour: 16,
    );
    final legacy = session(
      id: 'legacy-tiger',
      name: 'Little Tiger (Age 3-5)',
      type: 'little-tiger',
      hour: 18,
    );
    for (final age in [3, 4, 5]) {
      for (final belt in ['No Belt', 'White', 'Black']) {
        final profile = child(age, belt: belt);
        expect(recommend(profile, [littleTigers]), same(littleTigers));
        expect(recommend(profile, [legacy]), same(legacy));
        expect(isTypicallyRecommendedFor(littleTigers, profile), isTrue);
        expect(littleTigers.isEligibleFor(profile), isTrue);
      }
    }
    expect(littleTigers.eligibilityLabel, 'Ages 3-5 • All belt ranks');
    expect(classGuidanceFor(littleTigers, child(4)), contains('regardless of belt'));
  });

  test('Little Tigers excludes other ages, including saved preferences', () {
    final littleTigers = session(
      id: 'tigers',
      name: 'Little Tigers',
      type: 'little-tiger',
      group: 'little-tiger-standard',
      hour: 16,
    );
    for (final age in [2, 6, 10, 13]) {
      final profile = child(age, preferred: ['little-tiger-standard']);
      expect(recommend(profile, [littleTigers]), isNull);
      expect(isTypicallyRecommendedFor(littleTigers, profile), isFalse);
      expect(littleTigers.isEligibleFor(profile), isFalse);
    }
    expect(preferredClassGroupIdForClassName('Little Tigers'), 'little-tiger-standard');
    expect(preferredClassGroupIdForClassName('Little Tiger (Age 3-5)'),
        'little-tiger-standard');
  });

  test('Little Tigers never loosens other classes with empty belts', () {
    final littleTigers = session(
      id: 'tigers',
      name: 'Little Tigers',
      type: 'little-tiger',
      hour: 16,
    );
    final level1 = session(
      id: 'level-1',
      name: 'Level 1',
      type: 'level-1',
      hour: 17,
    );
    final profile = child(4, belt: 'Blue');
    expect(recommend(profile, [level1, littleTigers]), same(littleTigers));
    expect(recommend(profile, [level1]), isNull);
    expect(isTypicallyRecommendedFor(level1, profile), isFalse);
  });

  test('changing Red Belt from 9 to 17 never recommends Black Belt', () {
    final levelThree = session(
      id: 'level-three',
      name: 'Level 3',
      type: 'level-3',
      hour: 16,
      belts: const ['Blue', 'Blue-Red', 'Red', 'Red-Yellow'],
    );
    final blackBelt = session(
      id: 'black-belt',
      name: 'Black Belt',
      type: 'teen-adult',
      hour: 17,
      belts: const ['Black'],
    );
    final adult = session(
      id: 'adult',
      name: 'Adult',
      type: 'teen-adult',
      hour: 18,
    );
    expect(
      recommend(child(9, belt: 'Red'), [blackBelt, levelThree, adult]),
      same(levelThree),
    );
    expect(
      recommend(child(17, belt: 'Red'), [blackBelt, levelThree, adult]),
      same(adult),
    );
    expect(
      recommend(child(17, belt: 'Red'), [blackBelt, levelThree]),
      isNull,
    );
    expect(
      isTypicallyRecommendedFor(blackBelt, child(17, belt: 'Red')),
      isFalse,
    );
  });

  test('age 12-18 gets earliest upcoming Teen or Adult regardless of belt', () {
    final teenEarly = session(
      id: 'teen-early',
      name: 'Teen & Black Belt',
      type: 'teen-adult',
      hour: 16,
      belts: const ['Black'],
    );
    final adultLater = session(
      id: 'adult-later',
      name: 'Adult',
      type: 'teen-adult',
      hour: 18,
    );
    final blackBelt = session(
      id: 'black-belt',
      name: 'Black Belt',
      type: 'teen-adult',
      hour: 15,
      belts: const ['Black'],
    );

    for (final age in [12, 13, 17, 18]) {
      final profile = child(age, belt: 'Red');
      expect(recommend(profile, [adultLater, blackBelt, teenEarly]), same(teenEarly));
      expect(isTypicallyRecommendedFor(teenEarly, profile), isTrue);
      expect(isTypicallyRecommendedFor(adultLater, profile), isTrue);
      expect(isTypicallyRecommendedFor(blackBelt, profile), isFalse);
      expect(classGuidanceFor(teenEarly, profile), contains('12-18'));
    }
    // "Next" means a future start, not a class already in progress.
    expect(
      nextRecommendedClassFromSchedule(
        {DateTime.monday: [teenEarly, adultLater]},
        child(17, belt: 'Red'),
        currentWeekday: DateTime.monday,
        currentMinutes: 16 * 60 + 5,
      ),
      same(adultLater),
    );
    // Return to the next week when today's qualifying sessions have passed.
    expect(
      nextRecommendedClassFromSchedule(
        {DateTime.monday: [teenEarly, adultLater]},
        child(17, belt: 'Red'),
        currentWeekday: DateTime.monday,
        currentMinutes: 19 * 60,
      ),
      same(teenEarly),
    );
  });

  test('19+ only gets Adult, never Teen & Black Belt', () {
    final teen = session(
      id: 'teen',
      name: 'Teen & Black Belt',
      type: 'teen-adult',
      hour: 15,
    );
    final adult = session(
      id: 'adult',
      name: 'Adult',
      type: 'teen-adult',
      hour: 18,
    );
    for (final age in [19, 20, 30, 60]) {
      final profile = child(age, belt: 'Black');
      expect(recommend(profile, [teen, adult]), same(adult));
      expect(recommend(profile, [teen]), isNull);
      expect(isTypicallyRecommendedFor(adult, profile), isTrue);
      expect(isTypicallyRecommendedFor(teen, profile), isFalse);
    }
  });

  test('age 6-11 is belt-based; age below 3 has no recommendation', () {
    final levelThree = session(
      id: 'level-three',
      name: 'Level 3',
      type: 'level-3',
      hour: 16,
      belts: const ['Red'],
    );
    final adult = session(
      id: 'adult',
      name: 'Adult',
      type: 'teen-adult',
      hour: 15,
    );
    for (final age in [6, 9, 11]) {
      expect(recommend(child(age, belt: 'Red'), [adult, levelThree]), same(levelThree));
      expect(recommend(child(age, belt: 'Blue'), [adult, levelThree]), isNull);
    }
    expect(recommend(child(2, belt: 'Red'), [adult, levelThree]), isNull);
  });

  test('age-group priority prevents incompatible saved preferences', () {
    final little = session(
      id: 'little',
      name: 'Little Tigers',
      type: 'little-tiger',
      hour: 16,
    );
    final teen = session(
      id: 'teen',
      name: 'Teen & Black Belt',
      type: 'teen-adult',
      hour: 17,
    );
    final adult = session(
      id: 'adult',
      name: 'Adult',
      type: 'teen-adult',
      hour: 18,
    );
    final level = session(
      id: 'level',
      name: 'Level 3',
      type: 'level-3',
      hour: 15,
      belts: const ['Red'],
    );

    expect(recommend(child(4, preferred: ['level-3-standard']), [level, little]), same(little));
    expect(
      recommend(child(17, belt: 'Red', preferred: ['level-3-standard']),
          [level, teen, adult]),
      same(teen),
    );
    expect(
      recommend(child(19, preferred: ['teen-adult-standard']), [teen, adult]),
      same(adult),
    );
  });

  test('dashboard wrapper and age-based selection stay consistent', () {
    final levelThree = session(
      id: 'level-three',
      name: 'Level 3',
      type: 'level-3',
      hour: 16,
      belts: const ['Blue'],
    );
    final adult = session(
      id: 'adult',
      name: 'Adult',
      type: 'teen-adult',
      hour: 18,
    );
    final schedule = {DateTime.monday: [levelThree, teen, adult]};
    for (final profile in [student(older: false), student(older: true)]) {
      expect(
        nextEligibleClassFromSchedule(
          schedule,
          profile,
          currentWeekday: DateTime.monday,
          currentMinutes: 0,
        ),
        same(nextRecommendedClassFromSchedule(
          schedule,
          profile,
          currentWeekday: DateTime.monday,
          currentMinutes: 0,
        )),
      );
    }
    expect(recommend(student(older: false), [levelThree, teen, adult]),
        same(levelThree));
    expect(recommend(student(older: true), [levelThree, teen, adult]),
        same(adult));
  });

  Student beginner({
    String belt = 'No Belt',
    List<String> preferred = const [],
  }) => Student(
    id: 'test',
    name: 'Student',
    locationId: 'cheshire',
    belt: belt,
    dateOfBirth: DateTime.now().subtract(const Duration(days: 17 * 366)),
    stickerCount: 0,
    stickersRequired: 0,
    nextRank: 'White',
    preferredClassGroupIds: preferred,
  );
  for (final age in [7, 10]) {
    test('age $age Black Belt has no beginner or placement fallback', () {
      final white = session(
        id: 'white',
        name: 'Level 1',
        type: 'level-1',
        hour: 16,
        belts: ['White'],
      );
      final placement = session(
        id: 'placement',
        name: 'Level 4',
        type: 'level-4',
        hour: 18,
      );
      expect(recommend(child(age), [white, placement]), isNull);
      expect(isTypicallyRecommendedFor(placement, child(age)), isFalse);
      expect(recommend(child(age), [white, teen]), isNull);
      expect(
        recommend(child(age, preferred: ['level-1-standard']), [white, teen]),
        same(white),
      );
    });
  }
  test('canonical belt spelling and selected siblings stay independent', () {
    final black = session(
      id: 'black',
      name: 'Black Belt',
      type: 'teen-adult',
      hour: 18,
      belts: ['Black'],
    );
    final white = session(
      id: 'white',
      name: 'Level 1',
      type: 'level-1',
      hour: 16,
      belts: ['White'],
    );
    expect(
      recommend(child(7, belt: ' black belt '), [white, black]),
      same(black),
    );
    expect(recommend(child(10, belt: 'Black-Belt'), [white, black]), same(black));
    expect(recommend(child(10, belt: 'White'), [white, black]), same(white));
    expect(recommend(child(7), [white, black]), same(black));
  });
  test('dashboard wrapper and schedule use the same selected-child policy', () {
    final schedule = {
      DateTime.monday: [level, teen],
    };
    for (final profile in [
      child(7),
      child(10, belt: 'Blue'),
      child(7, belt: 'Blue', preferred: ['level-3']),
    ]) {
      expect(
        nextEligibleClassFromSchedule(
          schedule,
          profile,
          currentWeekday: DateTime.monday,
          currentMinutes: 0,
        ),
        same(
          nextRecommendedClassFromSchedule(
            schedule,
            profile,
            currentWeekday: DateTime.monday,
            currentMinutes: 0,
          ),
        ),
      );
    }
    expect(
      recommend(child(7, belt: 'Blue', preferred: ['level-3']), [level, teen]),
      same(level),
    );
  });

  test('teen recommendation has no belt requirement', () {
    final teenEarly = session(
      id: 'teen-early',
      name: 'Teen & Black Belt',
      type: 'teen-adult',
      hour: 16,
      belts: const ['Black'],
    );
    final adultLater = session(
      id: 'adult-later',
      name: 'Adult',
      type: 'teen-adult',
      hour: 19,
    );
    final ineligibleBeltClass = session(
      id: 'black',
      name: 'Black Belt',
      type: 'teen-adult',
      hour: 15,
      belts: const ['Black'],
    );
    expect(
      recommend(beginner(), [ineligibleBeltClass, teenEarly, adultLater]),
      same(teenEarly),
    );
    expect(recommend(beginner(), [ineligibleBeltClass]), isNull);
    expect(isTypicallyRecommendedFor(teenEarly, beginner()), isTrue);
    expect(isTypicallyRecommendedFor(ineligibleBeltClass, beginner()), isFalse);
  });

  test('age-based adult recommendation needs no belt configuration', () {
    final adult = session(
      id: 'adult',
      name: 'Adult',
      type: 'adult',
      hour: 18,
    );
    expect(recommend(beginner(), [adult]), same(adult));
    expect(isTypicallyRecommendedFor(adult, beginner()), isTrue);
  });

  test('younger student is not sent to a different numbered belt level', () {
    final levelOne = session(
      id: 'level-one',
      name: 'Level 1',
      type: 'level-1',
      hour: 16,
      belts: const ['White', 'White-Yellow'],
    );
    final levelFour = session(
      id: 'level-four',
      name: 'Level 4',
      type: 'level-4',
      hour: 18,
      belts: const ['Red-Green', 'Red-Blue', 'Red-Black'],
    );
    final youngerBlueBelt = student(older: false);

    expect(recommend(youngerBlueBelt, [levelOne, levelFour]), isNull);
    expect(isTypicallyRecommendedFor(levelOne, youngerBlueBelt), isFalse);
    expect(isTypicallyRecommendedFor(levelFour, youngerBlueBelt), isFalse);
  });

  test('unconfigured numbered classes are still not belt-eligible', () {
    final unconfiguredLevel = session(
      id: 'unconfigured-level',
      name: 'Level 1',
      type: 'level-1',
      hour: 16,
    );
    expect(recommend(child(10, belt: 'White'), [unconfiguredLevel]), isNull);
    expect(isTypicallyRecommendedFor(unconfiguredLevel, child(10, belt: 'White')),
        isFalse);
  });

  test('younger black belt may receive a rank-matched Black Belt class', () {
    final blackBelt = session(
      id: 'black-belt',
      name: 'Black Belt',
      type: 'teen-adult',
      hour: 17,
      belts: const ['Black'],
    );
    final teenBelt = session(
      id: 'teen-belt',
      name: 'Teen & Black Belt',
      type: 'teen-adult',
      hour: 16,
      belts: const ['Black'],
    );
    final profile = Student(
      id: 'younger-black-belt',
      name: 'Student',
      locationId: 'cheshire',
      belt: 'Black',
      dateOfBirth: DateTime(2016, 1, 1),
      stickerCount: 0,
      stickersRequired: 0,
      nextRank: 'Black',
    );

    expect(recommend(profile, [teenBelt, blackBelt]), same(blackBelt));
    expect(isTypicallyRecommendedFor(blackBelt, profile), isTrue);
    expect(isTypicallyRecommendedFor(teenBelt, profile), isFalse);
    expect(classGuidanceFor(blackBelt, profile), contains('Belt-based'));
  });

  test(
    'inactive and wrong-location classes cannot override eligibility or preference',
    () {
      final inactive = session(
        id: 'inactive',
        name: 'Adult',
        type: 'adult',
        hour: 16,
        belts: ['No Belt'],
        published: false,
      );
      final wrongLocation = session(
        id: 'wrong',
        name: 'Adult',
        type: 'adult',
        hour: 16,
        belts: ['No Belt'],
        location: 'other',
      );
      expect(
        recommend(beginner(preferred: ['adult-standard']), [
          inactive,
          wrongLocation,
        ]),
        isNull,
      );
    },
  );

  test('guidance explains age-first recommendations', () {
    expect(
      classGuidanceFor(level, student(older: true)),
      contains('generally recommended'),
    );
    expect(
      classGuidanceFor(teen, student(older: false)),
      contains('12-18'),
    );
  });

  test('exact class names produce distinct recurring preference groups', () {
    expect(
      preferredClassGroupIdForClassName('Little Tiger (Age 3-5)'),
      'little-tiger-standard',
    );
    expect(preferredClassGroupIdForClassName('Level 1'), 'level-1-standard');
    expect(preferredClassGroupIdForClassName('Level 2'), 'level-2-standard');
    expect(preferredClassGroupIdForClassName('Level 3'), 'level-3-standard');
    expect(preferredClassGroupIdForClassName('Level 4'), 'level-4-standard');
    expect(
      preferredClassGroupIdForClassName('Black Belt'),
      'black-belt-standard',
    );
    expect(
      preferredClassGroupIdForClassName('Teen & Black Belt'),
      'teen-black-belt-standard',
    );
    expect(preferredClassGroupIdForClassName('Adult'), 'adult-standard');
    expect(
      preferredClassGroupIdForClassName('Teen/Adult Sparring'),
      'teen-adult-sparring-standard',
    );
    expect(
      preferredClassGroupIdForClassName('Level 1 / Level 2 Sparring'),
      'level-1-2-sparring-standard',
    );
    expect(
      preferredClassGroupIdForClassName('Advanced Saturday Program'),
      'advanced-saturday-program-standard',
    );
  });

  test(
    'legacy teen-adult class documents resolve without guessing preference',
    () {
      final adult = session(
        id: 'adult',
        name: 'Adult',
        type: 'teen-adult',
        group: legacyAmbiguousTeenAdultGroupId,
        hour: 18,
      );
      final black = session(
        id: 'black',
        name: 'Black Belt',
        type: 'teen-adult',
        group: legacyAmbiguousTeenAdultGroupId,
        hour: 19,
      );
      final teenBlack = session(
        id: 'teen-black',
        name: 'Teen & Black Belt',
        type: 'teen-adult',
        group: legacyAmbiguousTeenAdultGroupId,
        hour: 20,
      );

      expect(adult.bulkGroupId, 'adult-standard');
      expect(black.bulkGroupId, 'black-belt-standard');
      expect(teenBlack.bulkGroupId, 'teen-black-belt-standard');
      expect(
        matchesResolvedPreferredClassGroup(const [
          'adult-standard',
        ], adult.bulkGroupId),
        isTrue,
      );
      expect(
        matchesResolvedPreferredClassGroup(const [
          'adult-standard',
        ], black.bulkGroupId),
        isFalse,
      );
      expect(
        matchesResolvedPreferredClassGroup(const [
          legacyAmbiguousTeenAdultGroupId,
        ], adult.bulkGroupId),
        isFalse,
      );
      expect(
        resolvedSavedPreferredClassGroupIds(const [
          legacyAmbiguousTeenAdultGroupId,
        ]),
        isEmpty,
      );
    },
  );
}
