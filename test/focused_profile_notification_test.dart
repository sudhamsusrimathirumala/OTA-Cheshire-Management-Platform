import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/class_session.dart';
import 'package:ota_cheshire_management_platform/models/notification_item.dart';
import 'package:ota_cheshire_management_platform/models/student_profile.dart';
import 'package:ota_cheshire_management_platform/screens/profile_screen.dart';
import 'package:ota_cheshire_management_platform/screens/student_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/services/location_time_service.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/screens/notification_detail_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_app_data_service.dart';
import 'package:ota_cheshire_management_platform/services/mock_app_data_service.dart';
import 'package:ota_cheshire_management_platform/widgets/profile/profile_edit_sheets.dart';

void main() {
  final baseProfile = StudentProfile(
    id: 'student-1',
    name: 'Student One',
    canonicalFirstName: 'Student',
    canonicalLastName: 'One',
    locationId: 'cheshire',
    belt: 'White',
    canonicalBeltRank: 'White',
    dateOfBirth: DateTime(2010, 1, 2),
    stickerCount: 1,
    stickersRequired: 5,
    nextRank: 'White-Yellow',
    preferredClassGroupIds: const ['adult-standard'],
    updatedAt: DateTime.utc(2026, 7, 16),
  );

  test('same-scope session data fingerprint tracks every member update', () {
    final account = UserAccount(
      id: 'uid',
      firstName: 'Parent',
      lastName: 'One',
      email: 'parent@example.com',
      role: UserAccountRole.parent,
      linkedStudentProfileIds: const ['student-1'],
      selectedStudentProfileId: 'student-1',
      locationId: 'cheshire',
      updatedAt: DateTime.utc(2026, 7, 16),
    );
    final original = firebaseSessionDataFingerprint(
      account: account,
      profiles: [baseProfile],
      selectedProfile: baseProfile,
    );
    final updatedProfile = StudentProfile(
      id: baseProfile.id,
      name: 'Updated Student',
      locationId: baseProfile.locationId,
      belt: 'Green',
      dateOfBirth: baseProfile.dateOfBirth,
      stickerCount: 3,
      stickersRequired: 6,
      nextRank: 'Green-Blue',
      preferredClassGroupIds: const ['black-belt-standard'],
      updatedAt: DateTime.utc(2026, 7, 16, 1),
    );
    final updated = firebaseSessionDataFingerprint(
      account: account,
      profiles: [updatedProfile],
      selectedProfile: updatedProfile,
    );

    expect(updated, isNot(original));
    expect(account.locationId, updatedProfile.locationId);
  });

  test('profile date-of-birth edit updates member fingerprint without updatedAt', () {
    final account = UserAccount(
      id: 'parent',
      firstName: 'Parent',
      lastName: 'Example',
      email: 'parent@example.com',
      role: UserAccountRole.parent,
      locationId: 'cheshire',
      linkedStudentProfileIds: const ['student-1'],
      selectedStudentProfileId: 'student-1',
      updatedAt: DateTime.utc(2026, 7, 16),
    );
    final before = firebaseSessionDataFingerprint(
      account: account,
      profiles: [baseProfile],
      selectedProfile: baseProfile,
    );
    final newBirthDate = StudentProfile(
      id: baseProfile.id,
      name: baseProfile.name,
      locationId: baseProfile.locationId,
      belt: baseProfile.belt,
      dateOfBirth: DateTime(2009, 3, 27),
      stickerCount: baseProfile.stickerCount,
      stickersRequired: baseProfile.stickersRequired,
      nextRank: baseProfile.nextRank,
      preferredClassGroupIds: baseProfile.preferredClassGroupIds,
      updatedAt: baseProfile.updatedAt, // Firebase Console leaves this unchanged.
    );
    final after = firebaseSessionDataFingerprint(
      account: account,
      profiles: [newBirthDate],
      selectedProfile: newBirthDate,
    );
    expect(after, isNot(before));
    expect(
      firebaseSessionDataFingerprint(
        account: account,
        profiles: [newBirthDate],
        selectedProfile: newBirthDate,
      ),
      after,
      reason: 'Identical snapshots should not trigger redundant redraws.',
    );
  });

  test('profile promotion and guardian edits refresh without updatedAt', () {
    String fingerprint(StudentProfile profile) => firebaseSessionDataFingerprint(
      account: null,
      profiles: [profile],
      selectedProfile: profile,
    );
    final previous = fingerprint(baseProfile);
    StudentProfile withEdits({
      String nextRank = 'White-Yellow',
      String? guardianEmail,
      List<String> history = const [],
      List<String> notes = const [],
      String locationId = 'cheshire',
    }) => StudentProfile(
      id: baseProfile.id,
      name: baseProfile.name,
      locationId: locationId,
      belt: baseProfile.belt,
      dateOfBirth: baseProfile.dateOfBirth,
      stickerCount: baseProfile.stickerCount,
      stickersRequired: baseProfile.stickersRequired,
      nextRank: nextRank,
      guardianEmail: guardianEmail,
      preferredClassGroupIds: baseProfile.preferredClassGroupIds,
      promotionHistory: history,
      testingNotes: notes,
      updatedAt: baseProfile.updatedAt,
    );
    expect(fingerprint(withEdits(nextRank: 'Yellow')), isNot(previous));
    expect(fingerprint(withEdits(guardianEmail: 'guardian@example.com')),
        isNot(previous));
    expect(fingerprint(withEdits(history: ['White 2026'])), isNot(previous));
    expect(fingerprint(withEdits(notes: ['Ready for test'])), isNot(previous));
    expect(fingerprint(withEdits(locationId: 'another-location')),
        isNot(previous));
  });

  test('account email and role changes refresh with unchanged updatedAt', () {
    UserAccount account({String email = 'old@example.com',
      UserAccountRole role = UserAccountRole.parent}) => UserAccount(
        id: 'parent',
        firstName: 'Parent',
        lastName: 'Example',
        email: email,
        role: role,
        linkedStudentProfileIds: const ['student-1'],
        selectedStudentProfileId: 'student-1',
        locationId: 'cheshire',
        updatedAt: DateTime.utc(2026, 7, 16),
      );
    String fingerprint(UserAccount value) => firebaseSessionDataFingerprint(
      account: value,
      profiles: [baseProfile],
      selectedProfile: baseProfile,
    );
    expect(fingerprint(account(email: 'new@example.com')),
        isNot(fingerprint(account())));
    expect(fingerprint(account(role: UserAccountRole.student)),
        isNot(fingerprint(account())));
  });

  testWidgets('Profile rebuilds after a profile birthday and belt change', (
    tester,
  ) async {
    final service = _RealtimeMemberFixture();
    appDataService = service;
    addTearDown(initializeMockAppDataServiceForTests);

    await tester.pumpWidget(const MaterialApp(
      home: ProfileScreen(
        managementAvailableOverride: false,
        accountDeletionAvailableOverride: false,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Example Student'), findsOneWidget);
    expect(find.text('White Belt • OTA Cheshire'), findsOneWidget);
    final originalAge = const LocationTimeService().ageForStudent(
      service.selectedStudentProfile,
    );
    expect(find.text('$originalAge'), findsOneWidget);

    service.updateProfile(belt: 'Red', dateOfBirth: DateTime(2009, 3, 27));
    await tester.pumpAndSettle();
    expect(find.text('Red Belt • OTA Cheshire'), findsOneWidget);
    expect(find.text('White Belt • OTA Cheshire'), findsNothing);
    final updatedAge = const LocationTimeService().ageForStudent(
      service.selectedStudentProfile,
    );
    expect(updatedAge, isNot(originalAge));
    expect(find.text('$updatedAge'), findsOneWidget);
  });

  testWidgets('Dashboard rebuilds after active profile belt changes', (
    tester,
  ) async {
    final service = _RealtimeMemberFixture();
    appDataService = service;
    addTearDown(initializeMockAppDataServiceForTests);

    await tester.pumpWidget(const MaterialApp(home: StudentDashboardScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Viewing Example Student • White Belt'), findsOneWidget);

    service.updateProfile(belt: 'Red', dateOfBirth: DateTime(2009, 3, 27));
    await tester.pumpAndSettle();
    expect(find.text('Viewing Example Student • Red Belt'), findsOneWidget);
    expect(find.text('Viewing Example Student • White Belt'), findsNothing);
  });

  test('preferred options deduplicate weekdays and keep exact groups', () {
    final schedule = <int, List<ClassSession>>{
      DateTime.monday: [
        session('adult-mon', 'Adult', 18),
        session('black', 'Black Belt', 19),
      ],
      DateTime.wednesday: [
        session('adult-wed', 'Adult', 18),
        session('teen-black', 'Teen & Black Belt', 20),
      ],
    };
    final options = preferredClassOptions(schedule, 'cheshire');
    expect(
      options.where((item) => item.session.className == 'Adult'),
      hasLength(1),
    );
    expect(
      options.map((item) => item.session.bulkGroupId),
      containsAll([
        'adult-standard',
        'black-belt-standard',
        'teen-black-belt-standard',
      ]),
    );
    expect(
      options
          .firstWhere((item) => item.session.className == 'Adult')
          .scheduleSummary,
      contains('Mon'),
    );
    expect(
      options
          .firstWhere((item) => item.session.className == 'Adult')
          .scheduleSummary,
      contains('Wed'),
    );
  });

  testWidgets('profile preferred class set replace and remove stay on editor', (
    tester,
  ) async {
    final changes = <String?>[];
    final schedule = <int, List<ClassSession>>{
      DateTime.monday: [
        session('adult', 'Adult', 18),
        session('black', 'Black Belt', 19),
      ],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: StudentProfileEditScreen(
          student: baseProfile,
          guardianEmailRequired: false,
          schedule: schedule,
          updatePreferredClass: (profile, selected) async {
            changes.add(selected?.bulkGroupId);
          },
          updateManagedProfile: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final replace = find
        .widgetWithText(TextButton, 'Replace preferred class')
        .first;
    await tester.ensureVisible(replace);
    await tester.tap(replace);
    await tester.pump();
    expect(changes, ['black-belt-standard']);
    expect(find.byType(StudentProfileEditScreen), findsOneWidget);

    final remove = find.text('Remove preferred class');
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pump();
    expect(changes, ['black-belt-standard', null]);
    expect(find.byType(StudentProfileEditScreen), findsOneWidget);

    final set = find.widgetWithText(TextButton, 'Set preferred class').first;
    await tester.tap(set);
    await tester.pump();
    expect(changes.last, isNotNull);
  });

  testWidgets('notification detail marks unread and returns to notifications', (
    tester,
  ) async {
    final service = _ReactiveNotificationService();
    final navigatorKey = GlobalKey<NavigatorState>();
    appDataService = service;
    addTearDown(initializeMockAppDataServiceForTests);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Center(child: Text('Notifications'))),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationDetailScreen(
          notification: service.notifications.single,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mark as unread'), findsOneWidget);
    await tester.tap(find.text('Mark as unread'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.byType(NotificationDetailScreen), findsNothing);
    expect(service.unreadCalls, 1);
  });

  test('mock notification state changes locally without Firestore', () async {
    final service = MockAppDataService();
    final notification = service.notifications.first;
    await service.markNotificationRead(notification.id);
    expect(
      service.notifications
          .firstWhere((item) => item.id == notification.id)
          .isRead,
      isTrue,
    );
    await service.markNotificationUnread(notification.id);
    expect(
      service.notifications
          .firstWhere((item) => item.id == notification.id)
          .isRead,
      isFalse,
    );
  });
}

class _RealtimeMemberFixture extends MockAppDataService {
  StudentProfile _profile = StudentProfile(
    id: 'member-profile',
    name: 'Example Student',
    locationId: 'ota-cheshire',
    belt: 'White',
    dateOfBirth: DateTime(2017, 8, 26),
    stickerCount: 0,
    stickersRequired: 0,
    nextRank: 'White-Yellow',
    updatedAt: DateTime.utc(2026, 10, 13),
  );

  @override
  StudentProfile get selectedStudentProfile => _profile;

  @override
  List<StudentProfile> get linkedStudentProfiles => [_profile];

  @override
  UserAccount get currentUserAccount => const UserAccount(
    id: 'member',
    firstName: 'Example',
    lastName: 'Parent',
    email: 'parent@example.com',
    role: UserAccountRole.parent,
    linkedStudentProfileIds: ['member-profile'],
    selectedStudentProfileId: 'member-profile',
    locationId: 'ota-cheshire',
  );

  void updateProfile({required String belt, required DateTime dateOfBirth}) {
    _profile = StudentProfile(
      id: _profile.id,
      name: _profile.name,
      locationId: _profile.locationId,
      belt: belt,
      dateOfBirth: dateOfBirth,
      stickerCount: _profile.stickerCount,
      stickersRequired: _profile.stickersRequired,
      nextRank: _profile.nextRank,
      updatedAt: _profile.updatedAt,
    );
    notifyListeners();
  }
}

ClassSession session(String id, String name, int hour) => ClassSession(
  id: id,
  className: name,
  classTypeId: 'teen-adult',
  locationId: 'cheshire',
  startTime: DateTime(2026, 7, 20, hour),
  endTime: DateTime(2026, 7, 20, hour + 1),
  eligibleBelts: const [],
  description: '',
);

class _ReactiveNotificationService extends ChangeNotifier
    implements MockAppDataService {
  int unreadCalls = 0;
  bool _read = true;

  @override
  List<NotificationItem> get notifications => [
    NotificationItem(
      id: 'notice',
      locationId: 'cheshire',
      title: 'Notice',
      summary: 'Summary',
      body: 'Body',
      timestamp: DateTime.utc(2026, 7, 16),
      isRead: _read,
      category: NotificationCategory.general,
    ),
  ];

  @override
  Future<void> markNotificationUnread(String announcementId) async {
    unreadCalls++;
    _read = false;
    notifyListeners();
  }

  @override
  Future<void> markNotificationRead(String announcementId) async {
    _read = true;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
