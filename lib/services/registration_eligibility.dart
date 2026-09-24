const minimumIndependentRegistrationAge = 16;

DateTime? parseRegistrationDateOfBirth(String? value) {
  final match = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{4})$',
  ).firstMatch(value?.trim() ?? '');
  if (match == null) return null;
  final month = int.parse(match.group(1)!);
  final day = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final candidate = DateTime(year, month, day);
  return candidate.year == year &&
          candidate.month == month &&
          candidate.day == day
      ? candidate
      : null;
}

bool isEligibleForIndependentRegistration(
  DateTime dateOfBirth, {
  DateTime? today,
}) {
  final reference = today ?? DateTime.now();
  final birthDate = DateTime(
    dateOfBirth.year,
    dateOfBirth.month,
    dateOfBirth.day,
  );
  final cutoff = DateTime(
    reference.year - minimumIndependentRegistrationAge,
    reference.month,
    reference.day,
  );
  return !birthDate.isAfter(cutoff);
}

String? registrationDateOfBirthError(String? value, {DateTime? today}) {
  final dateOfBirth = parseRegistrationDateOfBirth(value);
  if (dateOfBirth == null) return 'Enter date of birth as MM/DD/YYYY.';
  final reference = today ?? DateTime.now();
  if (dateOfBirth.isAfter(
    DateTime(reference.year, reference.month, reference.day),
  )) {
    return 'Date of birth cannot be in the future.';
  }
  if (!isEligibleForIndependentRegistration(dateOfBirth, today: reference)) {
    return 'Students under 16 cannot create accounts. A parent or guardian '
        'can create an account and add their student profile.';
  }
  return null;
}
