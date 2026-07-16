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
      same(teen),
    );
  });

  test('preferred class overrides age and belt recommendations', () {
    final younger = student(
      older: false,
      preferred: const ['teen-adult-standard'],
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
}
