import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_admin_write_service.dart';
import 'package:ota_cheshire_management_platform/services/firestore/firestore_audit_service.dart';

void main() {
  group('pure Firestore cleanup helpers', () {
    test('normalizes known and canonical resource categories', () {
      expect(normalizeResourceCategory('beltTesting'), 'testing');
      expect(normalizeResourceCategory('belt-testing'), 'testing');
      expect(normalizeResourceCategory('event'), 'events');
      expect(normalizeResourceCategory('form'), 'forms');
      expect(
        normalizeResourceCategory('academyInformation'),
        'academy-information',
      );
      expect(normalizeResourceCategory('registration'), 'registration');
    });

    test('detects repeated bulk group suffixes', () {
      expect(hasRepeatedStandardSuffix('level-1-standard'), isFalse);
      expect(hasRepeatedStandardSuffix('level-1-standard-standard'), isTrue);
      expect(
        hasRepeatedStandardSuffix('level-1-standard-standard-standard'),
        isTrue,
      );
    });

    test('validates canonical minute range', () {
      expect(isValidMinute(0), isTrue);
      expect(isValidMinute(1439), isTrue);
      expect(isValidMinute(-1), isFalse);
      expect(isValidMinute(1440), isFalse);
      expect(isValidMinute('30'), isFalse);
    });

    test('class session semantic keys include weekday', () {
      final monday = classSessionSemanticKey(<String, Object?>{
        'locationId': 'ota-cheshire',
        'weekday': 1,
        'startMinutes': 600,
        'classTypeId': 'level-1',
      });
      final tuesday = classSessionSemanticKey(<String, Object?>{
        'locationId': 'ota-cheshire',
        'weekday': 2,
        'startMinutes': 600,
        'classTypeId': 'level-1',
      });
      expect(monday, 'ota-cheshire|1|600|level-1');
      expect(tuesday, isNot(monday));
    });

    test('placeholder URL detection is conservative', () {
      expect(isPlaceholderUrl('https://example.com/register'), isTrue);
      expect(isPlaceholderUrl('https://forms.gle/ota-registration'), isTrue);
      expect(isPlaceholderUrl('https://forms.gle/real-id-123'), isFalse);
      expect(isPlaceholderUrl('https://ota-cheshire.com/forms'), isFalse);
    });

    test('placeholder description detection is conservative', () {
      expect(isPlaceholderDescription('Placeholder description'), isTrue);
      expect(isPlaceholderDescription('TBD'), isTrue);
      expect(
        isPlaceholderDescription('Bring sparring gear and water.'),
        isFalse,
      );
    });
  });

  group('cross-collection audit validation', () {
    test('event-resource validation uses in-memory maps', () {
      final issues = validateEventResourceReferences(
        'event-1',
        <String, Object?>{
          'locationId': 'ota-cheshire',
          'isPublished': true,
          'linkedResourceIds': <String>['draft', 'missing'],
          'primaryRegistrationResourceId': 'primary',
        },
        <String, Map<String, Object?>>{
          'draft': <String, Object?>{
            'locationId': 'ota-cheshire',
            'resourceSection': 'general',
            'isPublished': false,
            'isArchived': false,
          },
          'primary': <String, Object?>{
            'locationId': 'ota-cheshire',
            'resourceSection': 'general',
            'isPublished': true,
            'isArchived': false,
          },
        },
      );
      expect(
        issues.map((issue) => issue.issueCode),
        containsAll(<String>{
          'event.published_with_draft_resource',
          'event.linked_resource_missing',
          'event.primary_not_linked',
        }),
      );
    });

    test('user-student bidirectional validation finds both directions', () {
      final issues = validateUserStudentBidirectionalRelationships(
        <String, Map<String, Object?>>{
          'guardian-1': <String, Object?>{
            'linkedStudentProfileIds': <String>[],
          },
          'guardian-2': <String, Object?>{
            'linkedStudentProfileIds': <String>['student-1'],
          },
        },
        <String, Map<String, Object?>>{
          'student-1': <String, Object?>{
            'guardianUserIds': <String>['guardian-1'],
          },
        },
      );
      expect(
        issues.map((issue) => issue.issueCode),
        containsAll(<String>{
          'student_profile.user_missing_backlink',
          'user.student_profile_missing_backlink',
        }),
      );
    });

    test('announcement publication state issues are detected', () {
      final report = auditFirestoreDocuments(
        <String, Map<String, Map<String, Object?>>>{
          'announcements': <String, Map<String, Object?>>{
            'draft-1': _announcement(
              status: 'draft',
              publishedAt: DateTime.utc(2026, 1, 1),
            ),
            'published-1': _announcement(status: 'published'),
          },
        },
        generatedAt: DateTime.utc(2026, 7, 11),
      );
      final codes = report.collections
          .firstWhere((item) => item.collection == 'announcements')
          .issues
          .map((issue) => issue.issueCode);
      expect(codes, contains('announcement.draft_has_published_at'));
      expect(codes, contains('announcement.published_missing_published_at'));
    });

    test('audit report JSON contains structured issue data', () {
      final report = FirestoreAuditReport(
        generatedAt: DateTime.utc(2026, 7, 11),
        collections: const <CollectionAuditReport>[
          CollectionAuditReport(
            collection: 'resources',
            documentCount: 1,
            issues: <FirestoreAuditIssue>[
              FirestoreAuditIssue(
                collection: 'resources',
                documentId: 'resource-1',
                issueCode: 'resource.legacy_url',
                severity: FirestoreAuditSeverity.info,
                message: 'Legacy url field is present.',
                recommendedAction: 'Review later.',
              ),
            ],
          ),
        ],
      );
      final json = report.toJson();
      expect(json['readOnly'], isTrue);
      expect(json['totalIssueCount'], 1);
      expect(
        ((json['collections']! as List).single as Map)['issues'],
        hasLength(1),
      );
    });
  });

  group('canonical write fields', () {
    final createdAt = DateTime.utc(2026, 6, 1);
    final now = DateTime.utc(2026, 7, 11);

    test('write helpers preserve createdAt', () {
      final fields = resourceWriteFields(
        ResourceWriteData(
          title: 'Resource',
          description: 'Description',
          resourceType: 'form',
          category: 'forms',
          locationId: 'ota-cheshire',
          isPublished: true,
          createdAt: createdAt,
        ),
        now: now,
      );
      expect((fields['createdAt']! as Timestamp).toDate().toUtc(), createdAt);
    });

    test('event writes preserve archive state', () {
      final fields = eventWriteFields(
        EventWriteData(
          title: 'Event',
          description: 'Description',
          locationId: 'ota-cheshire',
          eventType: 'event',
          startDateTime: now,
          endDateTime: now.add(const Duration(hours: 1)),
          isPublished: true,
          isArchived: true,
          createdAt: createdAt,
        ),
        now: now,
      );
      expect(fields['isArchived'], isTrue);
      expect((fields['createdAt']! as Timestamp).toDate().toUtc(), createdAt);
    });

    test('class-session writes omit legacy timestamps and null optionals', () {
      final fields = classSessionWriteFields(
        ClassSessionWriteData(
          className: 'Level 1',
          classTypeId: 'level-1',
          locationId: 'ota-cheshire',
          weekday: 1,
          startMinutes: 600,
          endMinutes: 660,
          eligibleBelts: const <String>[],
          description: 'Class',
          isActive: true,
          isPreferred: false,
          createdAt: createdAt,
        ),
        now: now,
      );
      expect(fields, isNot(contains('startTime')));
      expect(fields, isNot(contains('endTime')));
      expect(fields, isNot(contains('eligibilityNote')));
      expect(fields, isNot(contains('resumesOn')));
      expect((fields['createdAt']! as Timestamp).toDate().toUtc(), createdAt);
    });

    test('resource writes use linkUrl and never url', () {
      final fields = resourceWriteFields(
        ResourceWriteData(
          title: 'Registration',
          description: 'Registration form',
          resourceType: 'form',
          category: 'beltTesting',
          linkUrl: 'https://ota-cheshire.com/register',
          locationId: 'ota-cheshire',
          isPublished: true,
        ),
        now: now,
      );
      expect(fields['linkUrl'], 'https://ota-cheshire.com/register');
      expect(fields, isNot(contains('url')));
      expect(fields['category'], 'testing');
      expect(fields['resourceSection'], 'general');
    });

    test('resource writes reject an empty resourceType', () {
      expect(
        () => resourceWriteFields(
          const ResourceWriteData(
            title: 'Resource',
            description: 'Description',
            resourceType: ' ',
            category: 'general',
            locationId: 'ota-cheshire',
            isPublished: false,
          ),
          now: now,
        ),
        throwsArgumentError,
      );
    });

    test('draft announcement writes do not assign publishedAt', () {
      final fields = announcementWriteFields(
        const AnnouncementWriteData(
          title: 'Draft',
          summary: 'Summary',
          body: 'Body',
          announcementType: 'general',
          priority: 'normal',
          status: 'draft',
          locationId: 'ota-cheshire',
          requiresAction: false,
        ),
        now: now,
      );
      expect(fields, isNot(contains('publishedAt')));
    });

    test('published announcement edit preserves publication and creation', () {
      final publishedAt = DateTime.utc(2026, 6, 2);
      final fields = announcementWriteFields(
        AnnouncementWriteData(
          title: 'Published',
          summary: 'Summary',
          body: 'Body',
          announcementType: 'general',
          priority: 'critical',
          status: 'published',
          locationId: 'ota-cheshire',
          requiresAction: false,
          publishedAt: publishedAt,
          createdAt: createdAt,
        ),
        now: now,
      );
      expect(
        (fields['publishedAt']! as Timestamp).toDate().toUtc(),
        publishedAt,
      );
      expect((fields['createdAt']! as Timestamp).toDate().toUtc(), createdAt);
      expect(fields['priority'], 'important');
    });
  });
}

Map<String, Object?> _announcement({
  required String status,
  DateTime? publishedAt,
}) {
  return <String, Object?>{
    'status': status,
    'priority': 'normal',
    'requiresAction': false,
    'audienceType': 'everyone',
    'locationId': 'ota-cheshire',
    'targetBelts': <String>[],
    'targetClassTypeIds': <String>[],
    'targetStudentProfileIds': <String>[],
    'targetUserIds': <String>[],
    'publishedAt': ?publishedAt,
  };
}
