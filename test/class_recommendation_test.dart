import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/class_session.dart';
import 'package:ota_cheshire_management_platform/models/student.dart';
import 'package:ota_cheshire_management_platform/services/class_recommendation_service.dart';

void main() {
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

  test('younger and older students receive central recommendations', () {
    final schedule = {
      DateTime.monday: [level, teen],
    };
    expect(
      nextRecommendedClassFromSchedule(
        schedule,
        student(older: false),
        currentWeekday: DateTime.monday,
        currentMinutes: 0,
      ),
      same(level),
    );
    expect(
      nextRecommendedClassFromSchedule(
        schedule,
        student(older: true),
        currentWeekday: DateTime.monday,
        currentMinutes: 0,
      ),
      same(level),
    );
  });

  test('preferred class overrides age and belt recommendations', () {
    final younger = student(
      older: false,
      preferred: const ['teen-black-belt-standard'],
    );
    final older = student(older: true, preferred: const ['level-3-standard']);
    final schedule = {
      DateTime.monday: [level, teen],
    };
    expect(
      nextRecommendedClassFromSchedule(
        schedule,
        younger,
        currentWeekday: DateTime.monday,
        currentMinutes: 0,
      ),
      same(teen),
    );
    expect(
      nextRecommendedClassFromSchedule(
        schedule,
        older,
        currentWeekday: DateTime.monday,
        currentMinutes: 0,
      ),
      same(level),
    );
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
  ClassSession? recommend(Student profile, List<ClassSession> classes) =>
      nextRecommendedClassFromSchedule(
        {DateTime.monday: classes},
        profile,
        currentWeekday: DateTime.monday,
        currentMinutes: 0,
      );

  test(
    'older beginner never automatically gets an excluded black belt class',
    () {
      expect(recommend(beginner(), [teen]), isNull);
      expect(isTypicallyRecommendedFor(teen, beginner()), isFalse);
    },
  );
  test(
    'older beginner explicit black belt preference remains authoritative',
    () {
      expect(
        recommend(beginner(preferred: ['teen-black-belt-standard']), [teen]),
        same(teen),
      );
    },
  );
  test('eligible teen beginner and advanced classes are recommended', () {
    final adultBeginner = session(
      id: 'beginner',
      name: 'Adult',
      type: 'adult',
      hour: 19,
      belts: ['White'],
    );
    expect(
      recommend(beginner(belt: 'White'), [teen, adultBeginner]),
      same(adultBeginner),
    );
    expect(recommend(beginner(belt: 'Black'), [teen]), same(teen));
  });
  test('numbered belt match beats unspecified and excluded teen classes', () {
    final beginnerLevel = session(
      id: 'beginner',
      name: 'Level 1',
      type: 'level-1',
      hour: 19,
      belts: ['No Belt'],
    );
    final unspecified = session(
      id: 'unspecified',
      name: 'Adult',
      type: 'adult',
      hour: 15,
    );
    expect(
      recommend(beginner(), [unspecified, teen, beginnerLevel]),
      same(beginnerLevel),
    );
    expect(recommend(beginner(), [unspecified, teen]), same(unspecified));
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

  test('guidance is advisory for nontraditional class choices', () {
    expect(
      classGuidanceFor(level, student(older: true)),
      contains('may still choose'),
    );
    expect(
      classGuidanceFor(teen, student(older: false)),
      contains('usually attended'),
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
