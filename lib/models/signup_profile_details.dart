/// Applicant details carried in memory from signup to profile setup.
/// Provider authentication does not supply a date of birth.
class SignupProfileDetails {
  const SignupProfileDetails({this.fullName, this.dateOfBirth});

  final String? fullName;
  final DateTime? dateOfBirth;
}
