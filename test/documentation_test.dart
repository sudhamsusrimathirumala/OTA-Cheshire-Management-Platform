import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readNormalized(String path) {
  return File(path)
      .readAsStringSync()
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'[`*~]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();
}

bool _statesThatMembershipApprovalIsInactive(String text) {
  return [
    RegExp(
      r'(does not use|has no|there is no)[^.]{0,100}'
      r'(approval|membership-review)',
    ),
    RegExp(
      r'(approval|membership-review)[^.]{0,100}'
      r'(removed|retired|inactive|not part of the current)',
    ),
  ].any((pattern) => pattern.hasMatch(text));
}

void main() {
  test('authoritative documentation files exist', () {
    expect(File('README.md').existsSync(), isTrue);
    expect(File('docs/CODEBASE_GUIDE.md').existsSync(), isTrue);
  });

  test('README describes the current product and documentation structure', () {
    final readme = _readNormalized('README.md');

    for (final role in ['parent', 'student', 'admin', 'super admin']) {
      expect(readme, contains(role), reason: 'Missing current role: $role');
    }

    expect(_statesThatMembershipApprovalIsInactive(readme), isTrue);
    expect(readme, contains('targeted'));
    expect(readme, contains('announcementdeliveries'));
    expect(readme, contains('account deletion'));
    expect(readme, contains('development and production environments'));
    expect(readme, contains('docs/codebase_guide.md'));
  });

  test('codebase guide covers the major implementation areas', () {
    final guide = _readNormalized('docs/CODEBASE_GUIDE.md');

    for (final topic in [
      'firebaseappdataservice',
      'firestoreprofileservice',
      'accountdeletionservice',
      'firebaseadminwriteservice',
      'firestore.rules',
      'functions/src/index.ts',
      'android',
      'ios',
      'test map',
    ]) {
      expect(guide, contains(topic), reason: 'Missing guide topic: $topic');
    }
  });

  test('retired membership approval is not described as current behavior', () {
    final currentDocs = [
      _readNormalized('README.md'),
      _readNormalized('docs/CODEBASE_GUIDE.md'),
    ].join(' ');

    for (final activeClaim in [
      'current membership approval workflow',
      'active membership approval workflow',
      'accounts require administrator approval',
      'users wait for academy approval',
    ]) {
      expect(currentDocs, isNot(contains(activeClaim)), reason: activeClaim);
    }

    expect(currentDocs, contains('earlier approval model'));
    expect(_statesThatMembershipApprovalIsInactive(currentDocs), isTrue);
  });
}
