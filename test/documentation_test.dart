import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active schema contains no retired application collection', () {
    final schema = File('docs/firestore_schema.md').readAsStringSync();
    expect(schema, isNot(contains('membershipApplications')));
    expect(
      schema,
      contains('`isActive`: bool controlling account availability'),
    );
    expect(schema, contains('one matching\n  `locationId`'));
  });

  test('historical design remains clearly labeled inactive', () {
    for (final path in [
      'README.md',
      'docs/ARCHITECTURE.md',
      'docs/ONBOARDING_BACKEND.md',
    ]) {
      final contents = File(path).readAsStringSync();
      expect(
        contents,
        contains('Historical Design Decision: Membership Approval (Inactive)'),
        reason: path,
      );
      expect(
        contents.replaceAll(RegExp(r'\s+'), ' ').toLowerCase(),
        contains('not part of the current runtime, firestore schema'),
        reason: path,
      );
    }
  });
}
