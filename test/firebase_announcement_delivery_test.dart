import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/notification_item.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_app_data_service.dart';

void main() {
  test(
    'authorized announcement sources merge, sort, deduplicate, and limit',
    () {
      final everyone = List.generate(
        30,
        (index) => notification('everyone-$index', index),
      );
      final targeted = [
        notification('targeted', 100),
        notification('everyone-29', 101, title: 'Authorized replacement'),
      ];

      final merged = mergeAuthorizedAnnouncementItems(
        everyone: everyone,
        targeted: targeted,
      );

      expect(merged, hasLength(FirebaseAppDataService.memberAnnouncementLimit));
      expect(merged.first.id, 'everyone-29');
      expect(merged.first.title, 'Authorized replacement');
      expect(merged[1].id, 'targeted');
      expect(merged.map((item) => item.id).toSet(), hasLength(merged.length));
      expect(
        merged.map((item) => item.timestamp).toList(),
        orderedEquals(
          (merged.map((item) => item.timestamp).toList()
            ..sort((a, b) => b.compareTo(a))),
        ),
      );
    },
  );
}

NotificationItem notification(String id, int minute, {String? title}) =>
    NotificationItem(
      id: id,
      locationId: 'cheshire',
      title: title ?? id,
      summary: 'Summary',
      body: 'Body',
      timestamp: DateTime.utc(2026, 8, 1, 0, minute),
      isRead: false,
      category: NotificationCategory.general,
    );
