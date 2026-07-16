import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/academy_resource.dart';
import 'package:ota_cheshire_management_platform/models/student.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_admin_write_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_identity_contract.dart';
import 'package:ota_cheshire_management_platform/services/firestore/firestore_migration_service.dart';

void main() {
  final now = DateTime.utc(2026, 7, 13);

  group('Firebase identity and user contract', () {
    test('Firebase UID, not email, is the user document identity', () {
      final account = userAccountFromFirestoreData('firebase-uid-123', {
        'firstName': ' Ada ',
        'lastName': ' Lovelace ',
        'email': ' ADA@Example.COM ',
        'role': 'parent',
        'isActive': true,
        'locationId': 'ota-cheshire',
        'linkedStudentProfileIds': <String>[],
        'googleAccountId': 'google-provider-456',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(account.id, 'firebase-uid-123');
      expect(account.id, isNot(account.email));
      expect(account.email, 'ada@example.com');
      expect(account.googleAccountId, 'google-provider-456');
      expect(account.locationId, 'ota-cheshire');
      expect(account.isActive, isTrue);
    });

    test('all canonical roles parse', () {
      expect(
        ['student', 'parent', 'admin', 'superAdmin'].map(parseUserAccountRole),
        UserAccountRole.values,
      );
    });

    test('invalid roles and malformed active access are rejected', () {
      expect(() => parseUserAccountRole('instructor'), throwsFormatException);
      expect(
        () => userAccountFromFirestoreData('uid', {
          'firstName': 'Ada',
          'lastName': 'Lovelace',
          'email': 'ada@example.com',
          'role': 'parent',
          'isActive': 'yes',
          'locationId': 'ota-cheshire',
          'linkedStudentProfileIds': <String>[],
          'createdAt': now,
          'updatedAt': now,
        }),
        throwsFormatException,
      );
    });

    test('phone normalization omits blanks and trims values', () {
      expect(normalizeOptionalPhoneNumber('  '), isNull);
      expect(normalizeOptionalPhoneNumber(' 203-555-0100 '), '203-555-0100');

      final fields = userAccountWriteFields(
        UserAccount(
          id: 'firebase-uid',
          firstName: 'Ada',
          lastName: 'Lovelace',
          email: ' ADA@example.com ',
          role: UserAccountRole.parent,
          isActive: true,
          locationId: 'ota-cheshire',
          linkedStudentProfileIds: const [],
          phoneNumber: ' ',
        ),
        now: now,
        isCreate: true,
      );
      expect(fields['email'], 'ada@example.com');
      expect(fields, isNot(contains('phoneNumber')));
    });

    test('canonical student defaults are parsed', () {
      final defaults = studentProfileDefaultsFromUserData({
        'studentProfileDefaults': {
          'dateOfBirth': Timestamp.fromDate(DateTime(1990, 2, 3)),
          'beltRank': 'Green',
          'guardianEmail': ' Contact@Example.com ',
          'stickerProgress': {
            'current': 4,
            'required': 7,
            'nextRank': 'Green-Blue',
          },
        },
      });
      expect(defaults!.dateOfBirth, DateTime(1990, 2, 3));
      expect(defaults.beltRank, 'Green');
      expect(defaults.guardianEmail, 'contact@example.com');
      expect(defaults.stickerCurrent, 4);
      expect(defaults.stickerRequired, 7);
      expect(defaults.nextRank, 'Green-Blue');
    });

    test('legacy defaults are read without overriding canonical values', () {
      final defaults = studentProfileDefaultsFromUserData({
        'studentProfileDefaults': {
          'dateOfBirth': DateTime(1991, 4, 5),
          'beltRank': 'Blue',
          'stickerProgress': {
            'current': 2,
            'required': 8,
            'nextRank': 'Blue-Red',
          },
        },
        'applicantDateOfBirth': DateTime(1980),
        'applicantBeltRank': 'White',
        'guardianEmail': 'legacy@example.com',
        'stickerProgress': {'current': 99, 'required': 99},
      });
      expect(defaults!.dateOfBirth, DateTime(1991, 4, 5));
      expect(defaults.beltRank, 'Blue');
      expect(defaults.guardianEmail, 'legacy@example.com');
      expect(defaults.stickerCurrent, 2);
      expect(defaults.stickerRequired, 8);
    });

    test('supported top-level legacy defaults are parsed', () {
      final defaults = studentProfileDefaultsFromUserData({
        'birthDate': DateTime(1985, 6, 7),
        'beltRank': 'Red',
        'guardianEmail': 'legacy@example.com',
        'stickerProgress': {
          'current': 1,
          'required': 3,
          'nextRank': 'Red-Black',
        },
      });
      expect(defaults!.dateOfBirth, DateTime(1985, 6, 7));
      expect(defaults.beltRank, 'Red');
      expect(defaults.guardianEmail, 'legacy@example.com');
    });

    test('Google provider UID is used and never derived from email', () {
      final google = providerIdentityFromValues(
        firebaseUid: 'firebase-uid',
        email: 'person@example.com',
        providers: const [
          ProviderIdentityValue(
            providerId: firebaseGoogleProviderId,
            providerUid: 'google-uid',
          ),
        ],
      );
      final passwordOnly = providerIdentityFromValues(
        firebaseUid: 'firebase-uid',
        email: 'person@example.com',
        providers: const [
          ProviderIdentityValue(
            providerId: 'password',
            providerUid: 'person@example.com',
          ),
        ],
      );
      expect(google.firebaseUid, 'firebase-uid');
      expect(google.googleAccountId, 'google-uid');
      expect(passwordOnly.googleAccountId, isNull);
    });

    test('user migration preserves valid contacts and is idempotent', () {
      final original = <String, dynamic>{
        'firstName': 'Ada',
        'lastName': 'Lovelace',
        'email': 'ada@example.com',
        'phoneNumber': '203-555-0100',
        'googleAccountId': 'google-uid',
        'linkedStudentProfileIds': <String>[],
        'createdAt': now,
      };
      expect(migrationUserBackfill(original), isEmpty);
      expect(migrationUserBackfill(original)['googleAccountId'], isNull);

      final legacy = <String, dynamic>{
        'displayName': 'Ada Lovelace',
        'email': ' ADA@Example.com ',
        'phoneNumber': ' 203-555-0100 ',
        'googleAccountId': ' google-uid ',
      };
      final updates = migrationUserBackfill(legacy);
      expect(updates['firstName'], 'Ada');
      expect(updates['lastName'], 'Lovelace');
      expect(updates['email'], 'ada@example.com');
      expect(updates['phoneNumber'], '203-555-0100');
      expect(updates['googleAccountId'], 'google-uid');
    });
  });

  group('student profile contract and guardian migration', () {
    test(
      'guardian email is normalized and distinct from guardian user IDs',
      () {
        final profile = studentProfileFromCanonicalData('student-1', {
          'firstName': 'Grace',
          'lastName': 'Hopper',
          'dateOfBirth': Timestamp.fromDate(DateTime.utc(2010, 1, 2)),
          'beltRank': 'Blue',
          'locationId': 'ota-cheshire',
          'guardianEmail': ' FAMILY@Example.com ',
          'guardianUserIds': ['parent-uid'],
          'isActive': true,
          'createdAt': now,
          'updatedAt': now,
        });
        expect(profile.guardianEmail, 'family@example.com');
        expect(profile.guardianUserIds, ['parent-uid']);
        expect(profile.locationId, 'ota-cheshire');
        expect(profile.isActive, isTrue);
      },
    );

    test('missing or malformed profile access data fails closed', () {
      expect(
        () => studentProfileFromCanonicalData('student-1', {
          'firstName': 'Grace',
          'lastName': 'Hopper',
          'dateOfBirth': Timestamp.fromDate(DateTime.utc(2010, 1, 2)),
          'beltRank': 'Blue',
          'guardianEmail': 'family@example.com',
          'guardianUserIds': ['parent-uid'],
          'isActive': 'yes',
          'createdAt': now,
          'updatedAt': now,
        }),
        throwsFormatException,
      );
    });

    test('existing guardian email is preserved', () {
      expect(
        deriveGuardianEmail('student-1', {
          'guardianEmail': ' Existing@Example.com ',
          'guardianUserIds': <String>[],
        }, const {}),
        'existing@example.com',
      );
    });

    test('self-managed profile writer permits missing guardian email', () {
      final fields = studentProfileWriteFields(
        Student(
          id: 'self-profile',
          name: 'Self Managed',
          canonicalFirstName: 'Self',
          canonicalLastName: 'Managed',
          locationId: 'ota-cheshire',
          belt: 'Blue',
          dateOfBirth: DateTime.utc(2000, 1, 2),
          stickerCount: 0,
          stickersRequired: 0,
          nextRank: 'Blue-Red',
          linkedUserId: 'self-uid',
        ),
        now: now,
        isCreate: true,
      );

      expect(fields, isNot(contains('guardianEmail')));
      expect(fields['linkedUserId'], 'self-uid');
      expect(fields['guardianUserIds'], isEmpty);
    });

    test('guardian email derives only from one linked parent', () {
      final users = <String, Map<String, dynamic>>{
        'parent-1': {
          'role': 'parent',
          'email': ' Parent@Example.com ',
          'linkedStudentProfileIds': ['student-1'],
        },
      };
      expect(
        deriveGuardianEmail('student-1', {
          'guardianUserIds': ['parent-1'],
        }, users),
        'parent@example.com',
      );
    });

    test('ambiguous or missing relationships do not invent an email', () {
      final users = <String, Map<String, dynamic>>{
        'parent-1': {
          'role': 'parent',
          'email': 'one@example.com',
          'linkedStudentProfileIds': ['student-1'],
        },
        'parent-2': {
          'role': 'parent',
          'email': 'two@example.com',
          'linkedStudentProfileIds': ['student-1'],
        },
      };
      expect(deriveGuardianEmail('student-1', const {}, users), isNull);
      expect(deriveGuardianEmail('student-2', const {}, users), isNull);
    });
  });

  group('location contract and migration', () {
    test('parses and formats an address with optional line two', () {
      final location = academyLocationFromFirestoreData('location-1', {
        'name': 'Academy',
        'addressLine1': '1 Main Street',
        'addressLine2': 'Suite 2',
        'city': 'Cheshire',
        'state': 'CT',
        'postalCode': '06410',
        'country': 'US',
        'timeZoneId': 'America/New_York',
        'isActive': true,
        'createdAt': now,
        'updatedAt': now,
      });
      expect(location.formattedAddress, contains('Suite 2'));
      final fields = academyLocationWriteFields(
        location,
        now: now,
        isCreate: true,
      );
      expect(fields['addressLine1'], '1 Main Street');
      expect(fields['addressLine2'], 'Suite 2');
      expect(fields['createdAt'], isA<Timestamp>());
      expect(
        missingRequiredLocationAddressFields({
          'addressLine1': '1 Main Street',
          'city': 'Cheshire',
          'state': 'CT',
          'postalCode': '06410',
          'country': 'US',
        }),
        isEmpty,
      );
    });

    test('missing address reporting and backfill are idempotent', () {
      final original = <String, dynamic>{
        'name': 'Existing name',
        'addressLine1': 'Preserved',
        'timeZoneId': 'America/New_York',
        'isActive': true,
        'createdAt': now,
        'updatedAt': now,
      };
      expect(missingLocationAddressFields(original), {
        'city',
        'state',
        'postalCode',
        'country',
      });
      expect(migrationLocationBackfill(original), isEmpty);
    });
  });

  group('General Resources contract and migration', () {
    test('only four categories are canonical', () {
      expect(canonicalResourceCategories, {
        'testing',
        'registration',
        'academy-information',
        'general',
      });
    });

    test('forms and events normalize to general', () {
      expect(normalizeLegacyResourceCategory('forms'), 'general');
      expect(normalizeLegacyResourceCategory('events'), 'general');
    });

    test('canonical writes omit resourceType', () {
      final fields = resourceWriteFields(
        const ResourceWriteData(
          title: 'Handbook',
          description: 'Policies',
          category: 'academy-information',
          locationId: 'ota-cheshire',
          isPublished: true,
        ),
        now: now,
      );
      expect(fields, isNot(contains('resourceType')));
    });

    test(
      'legacy resourceType is ignored and legacy documents remain readable',
      () {
        final resource = academyResourceFromFirestoreData('resource-1', {
          'title': 'Legacy form',
          'description': 'Still readable',
          'resourceSection': 'general',
          'resourceType': 'document',
          'category': 'forms',
          'locationId': 'ota-cheshire',
          'isPublished': true,
          'isArchived': false,
          'createdAt': now,
          'updatedAt': now,
        });
        expect(resource, isNotNull);
        expect(resource!.category, 'general');
      },
    );

    test('resource migration deletes type and is idempotent', () {
      final original = <String, dynamic>{
        'resourceSection': 'general',
        'category': 'events',
        'resourceType': 'document',
        'isArchived': false,
      };
      final first = migrationResourcePlan(original);
      expect(first.normalizesLegacyCategory, isTrue);
      expect(first.deleteResourceType, isTrue);

      final migrated = <String, dynamic>{...original, ...first.updates}
        ..remove('resourceType');
      final second = migrationResourcePlan(migrated);
      expect(second.updates, isEmpty);
      expect(second.deleteResourceType, isFalse);
    });
  });

  test('migration result reports the new counters accurately', () {
    const result = FirestoreMigrationResult(
      studentProfilesUpdated: 1,
      studentProfilesGivenGuardianEmail: 2,
      studentProfilesMissingGuardianEmail: 3,
      usersNormalizedOrBackfilled: 4,
      usersMissingRequiredEmail: 5,
      userPhoneNumbersPreserved: 6,
      googleAccountIdsPreservedOrNormalized: 7,
      classTypeIdsNormalized: 8,
      bulkGroupIdsAdded: 9,
      bulkGroupIdsRepaired: 10,
      announcementsUpdated: 11,
      eventsUpdated: 12,
      resourcesUpdated: 13,
      legacyResourceCategoriesNormalized: 14,
      resourceTypeFieldsRemoved: 15,
      resourceTypeFieldsLeftAsLegacy: 0,
      locationsUpdated: 16,
      locationsMissingRequiredAddressData: 17,
      starterResourcesCreated: 18,
    );
    expect(result.displaySummary, contains('guardianEmail: 2'));
    expect(result.displaySummary, contains('required email: 5'));
    expect(result.displaySummary, contains('categories normalized: 14'));
    expect(result.displaySummary, contains('fields removed: 15'));
    expect(result.displaySummary, contains('address data: 17'));
  });
}
