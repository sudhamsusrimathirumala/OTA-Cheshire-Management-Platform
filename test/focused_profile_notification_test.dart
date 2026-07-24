import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/class_session.dart';
import 'package:ota_cheshire_management_platform/models/notification_item.dart';
import 'package:ota_cheshire_management_platform/models/student_profile.dart';
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

  testWidgets(
    'notification detail marks unread and updates without reopening',
    (tester) async {
      final service = _ReactiveNotificationService();
      appDataService = service;
      addTearDown(initializeMockAppDataServiceForTests);
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationDetailScreen(
            notification: service.notifications.single,
          ),
        ),
      );
      expect(find.text('Mark as unread'), findsOneWidget);
      await tester.tap(find.text('Mark as unread'));
      await tester.pump();
      expect(find.text('Mark as read'), findsOneWidget);
      expect(service.unreadCalls, 1);
    },
  );

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
