import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_collections.dart';

const approvedEventIds = <String>[
  'fall_tournament',
  'parent_night_out',
  'summer_belt_testing',
];

const approvedStudentBirthDates = <String, (int, int, int)>{
  'student_aarav': (2019, 1, 1),
  'student_maya': (2016, 1, 1),
  'student_elena': (2013, 1, 1),
  'student_sudhamsu': (2009, 1, 1),
  'student_daniel': (2005, 1, 1),
};

Map<String, Object?> approvedTeenAdultSparringUpdate() => const {
  'classTypeId': 'teen-adult-sparring',
  'bulkGroupId': 'teen-adult-sparring-standard',
};

Map<String, Object?> approvedEventLegacyFieldRemoval() => {
  'registrationUrl': FieldValue.delete(),
  'showInResources': FieldValue.delete(),
};

Map<String, Object?> approvedStudentDateOfBirthUpdate(
  (int, int, int) birthDate,
) => {
  'dateOfBirth': Timestamp.fromDate(
    DateTime.utc(birthDate.$1, birthDate.$2, birthDate.$3),
  ),
  'age': FieldValue.delete(),
};

class ApprovedSchemaUpdateOperation {
  const ApprovedSchemaUpdateOperation({
    required this.collection,
    required this.documentId,
    required this.fields,
  });

  final String collection;
  final String documentId;
  final Map<String, Object?> fields;
}

List<ApprovedSchemaUpdateOperation> approvedSchemaUpdateOperations() => [
  ApprovedSchemaUpdateOperation(
    collection: FirestoreCollections.classSessions,
    documentId: 'fri_teen_adult_sparring',
    fields: approvedTeenAdultSparringUpdate(),
  ),
  for (final eventId in approvedEventIds)
    ApprovedSchemaUpdateOperation(
      collection: FirestoreCollections.events,
      documentId: eventId,
      fields: approvedEventLegacyFieldRemoval(),
    ),
  for (final entry in approvedStudentBirthDates.entries)
    ApprovedSchemaUpdateOperation(
      collection: FirestoreCollections.studentProfiles,
      documentId: entry.key,
      fields: approvedStudentDateOfBirthUpdate(entry.value),
    ),
];

class FirestoreSchemaUpdateService {
  FirestoreSchemaUpdateService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<int> applyApprovedUpdates() async {
    final batch = _firestore.batch();
    final operations = approvedSchemaUpdateOperations();
    for (final operation in operations) {
      batch.update(
        _firestore.collection(operation.collection).doc(operation.documentId),
        operation.fields,
      );
    }

    await batch.commit();
    return operations.length;
  }
}
