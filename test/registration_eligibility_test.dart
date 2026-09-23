import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/services/registration_eligibility.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_authentication_service.dart';

void main() {
  const underageMessage =
      'Students under 16 cannot create accounts. A parent or guardian can '
      'create an account and add their student profile.';
  final today = DateTime(2026, 9, 22);

  test('parses only real calendar dates in MM/DD/YYYY form', () {
    expect(parseRegistrationDateOfBirth('09/22/2010'), DateTime(2010, 9, 22));
    expect(parseRegistrationDateOfBirth('2/29/2012'), DateTime(2012, 2, 29));
    expect(parseRegistrationDateOfBirth('02/29/2011'), isNull);
    expect(parseRegistrationDateOfBirth('2010-09-22'), isNull);
    expect(parseRegistrationDateOfBirth(''), isNull);
  });

  test('allows the sixteenth birthday and older applicants', () {
    expect(
      isEligibleForIndependentRegistration(DateTime(2010, 9, 22), today: today),
      isTrue,
    );
    expect(
      isEligibleForIndependentRegistration(DateTime(2000, 1, 1), today: today),
      isTrue,
    );
  });

  test('rejects an applicant one day short of sixteen', () {
    expect(
      isEligibleForIndependentRegistration(DateTime(2010, 9, 23), today: today),
      isFalse,
    );
    expect(
      registrationDateOfBirthError('09/23/2010', today: today),
      underageMessage,
    );
  });

  test('handles leap-day birthdays by calendar date', () {
    expect(
      isEligibleForIndependentRegistration(
        DateTime(2008, 2, 29),
        today: DateTime(2024, 2, 28),
      ),
      isFalse,
    );
    expect(
      isEligibleForIndependentRegistration(
        DateTime(2008, 2, 29),
        today: DateTime(2024, 2, 29),
      ),
      isTrue,
    );
  });

  test('rejects future and malformed dates', () {
    expect(
      registrationDateOfBirthError('09/23/2026', today: today),
      'Date of birth cannot be in the future.',
    );
    expect(
      registrationDateOfBirthError('not-a-date', today: today),
      'Enter date of birth as MM/DD/YYYY.',
    );
  });

  test('login rejects only newly provisioned provider identities', () {
    expect(
      shouldRejectNewProviderIdentity(
        isNewUser: true,
        allowAccountCreation: false,
      ),
      isTrue,
    );
    expect(
      shouldRejectNewProviderIdentity(
        isNewUser: false,
        allowAccountCreation: false,
      ),
      isFalse,
    );
    expect(
      shouldRejectNewProviderIdentity(
        isNewUser: true,
        allowAccountCreation: true,
      ),
      isFalse,
    );
  });
}
