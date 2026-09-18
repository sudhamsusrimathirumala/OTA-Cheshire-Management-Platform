import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_admin_write_service.dart';
import 'package:ota_cheshire_management_platform/services/guest/guest_demo_app_data_service.dart';
import 'package:ota_cheshire_management_platform/services/guest/guest_experience_controller.dart';

void main() {
  late GuestExperienceController controller;
  late GuestDemoAppDataService service;

  setUp(() {
    controller = GuestExperienceController();
    service = GuestDemoAppDataService(controller: controller);
  });

  tearDown(() => service.dispose());

  test('one fictional dataset is shared across reviewer views', () async {
    controller.selectMode(GuestViewMode.admin);
    expect(
      service.adminStudentProfiles.map((item) => item.name),
      contains('Casey Rowan'),
    );

    await service.updateStudentProgress(
      const AdminStudentProgressWriteData(
        profileId: 'demo-casey',
        beltRank: 'Blue-Red',
        stickerCurrent: 1,
        stickerRequired: 4,
      ),
    );
    await service.saveAnnouncement(
      const AnnouncementWriteData(
        title: 'Casey demo update',
        summary: 'Visible in the fictional member experience.',
        body: 'This publication remains only in memory.',
        announcementType: 'general',
        priority: 'general',
        status: 'published',
        locationId: guestDemoLocationId,
        requiresAction: false,
        audienceType: 'everyone',
      ),
    );

    controller.selectMode(GuestViewMode.student);
    expect(service.selectedStudentProfile.name, 'Casey Rowan');
    expect(service.selectedStudentProfile.belt, 'Blue-Red');
    expect(
      service.notifications.map((item) => item.title),
      contains('Casey demo update'),
    );

    controller.selectMode(GuestViewMode.parent);
    expect(
      service.linkedStudentProfiles.map((item) => item.name),
      containsAll(['Casey Rowan', 'Riley Rowan']),
    );
    expect(service.selectedStudentProfile.belt, 'Blue-Red');
  });

  test('reset discards all session-local edits', () async {
    await service.deleteAnnouncement('demo-workshop-announcement');
    await service.selectProfile('demo-riley');
    expect(
      service.adminAnnouncements.map((item) => item.id),
      isNot(contains('demo-workshop-announcement')),
    );
    expect(service.selectedStudentProfile.id, 'demo-riley');

    service.reset();

    expect(
      service.adminAnnouncements.map((item) => item.id),
      contains('demo-workshop-announcement'),
    );
    expect(service.selectedStudentProfile.id, 'demo-casey');
  });

  test('student targeting follows the selected fictional student', () async {
    controller.selectMode(GuestViewMode.admin);
    await service.saveAnnouncement(
      const AnnouncementWriteData(
        title: 'Riley-only demo notice',
        summary: 'Targeted to one fictional student.',
        body: 'This remains session-local.',
        announcementType: 'general',
        priority: 'general',
        status: 'published',
        locationId: guestDemoLocationId,
        requiresAction: false,
        audienceType: 'students',
        targetStudentProfileIds: ['demo-riley'],
      ),
    );

    controller.selectMode(GuestViewMode.parent);
    expect(
      service.notifications.map((item) => item.title),
      isNot(contains('Riley-only demo notice')),
    );

    await service.selectProfile('demo-riley');
    expect(
      service.notifications.map((item) => item.title),
      contains('Riley-only demo notice'),
    );
  });
}
