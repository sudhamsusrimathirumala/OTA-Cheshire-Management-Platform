import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/academy_event.dart';

void main() {
  final now = DateTime.utc(2026, 10, 22, 12);
  AcademyEvent event({DateTime? end, DateTime? deadline,
    bool published = true, bool archived = false, String? resource = 'registration'}) => AcademyEvent(
    id: 'event', title: 'Event', description: 'Details', locationId: 'cheshire',
    eventType: 'seminar', startDateTime: now.add(const Duration(hours: 1)),
    endDateTime: end ?? now.add(const Duration(hours: 2)),
    registrationDeadline: deadline, primaryRegistrationResourceId: resource,
    isPublished: published, isArchived: archived, createdAt: now, updatedAt: now,
  );

  test('registration closes when the event ends even without a deadline', () {
    expect(event().registrationOpenAt(now), isTrue);
    expect(event(end: now).registrationOpenAt(now), isFalse);
    expect(event(end: now.subtract(const Duration(days: 1))).registrationOpenAt(now), isFalse);
  });

  test('registration requires a resource and an active published event', () {
    expect(event(resource: null).registrationOpenAt(now), isFalse);
    expect(event(published: false).registrationOpenAt(now), isFalse);
    expect(event(archived: true).registrationOpenAt(now), isFalse);
    expect(event(deadline: now).registrationOpenAt(now), isFalse);
    expect(event(deadline: now.add(const Duration(minutes: 1))).registrationOpenAt(now), isTrue);
  });
}
