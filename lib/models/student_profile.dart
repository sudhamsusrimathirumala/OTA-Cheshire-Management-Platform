import 'student.dart';

/// Backend-ready name for a training student profile.
///
/// The current UI still uses the existing [Student] model shape to avoid
/// unnecessary churn. A student profile is intentionally separate from a
/// login-capable user account.
typedef StudentProfile = Student;
