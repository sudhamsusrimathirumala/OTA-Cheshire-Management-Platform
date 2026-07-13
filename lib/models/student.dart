class Student {
  const Student({
    required this.id,
    required this.name,
    required this.locationId,
    required this.belt,
    this.dateOfBirth,
    this.legacyAge,
    required this.stickerCount,
    required this.stickersRequired,
    required this.nextRank,
    this.guardianUserIds = const <String>[],
    this.selfUserId,
    String? linkedUserId,
    this.guardianEmail,
    this.approvalStatus = StudentApprovalStatus.approved,
    this.familyApplicationId,
    this.canonicalFirstName,
    this.canonicalLastName,
    this.canonicalBeltRank,
    this.preferredClassGroupIds = const <String>[],
    this.promotionHistory = const <String>[],
    this.testingNotes = const <String>[],
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  }) : linkedUserId = linkedUserId ?? selfUserId;

  final String id;
  final String name;
  final String locationId;
  final String belt;
  final DateTime? dateOfBirth;
  final int? legacyAge;
  final int stickerCount;
  final int stickersRequired;
  final String nextRank;
  final List<String> guardianUserIds;
  final String? guardianEmail;
  final String? selfUserId;
  final String? linkedUserId;
  final StudentApprovalStatus approvalStatus;
  final String? familyApplicationId;
  final String? canonicalFirstName;
  final String? canonicalLastName;
  final String? canonicalBeltRank;
  final List<String> preferredClassGroupIds;
  final List<String> promotionHistory;
  final List<String> testingNotes;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get firstName => canonicalFirstName ?? _nameParts.$1;
  String get lastName => canonicalLastName ?? _nameParts.$2;
  String get beltRank => canonicalBeltRank ?? belt;

  (String, String) get _nameParts {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return ('', '');
    if (parts.length == 1) return (parts.first, '');
    return (parts.first, parts.skip(1).join(' '));
  }

  int ageOn(DateTime academyLocalDate) {
    final birthDate = dateOfBirth;
    if (birthDate == null) {
      return legacyAge ?? 0;
    }
    var result = academyLocalDate.year - birthDate.year;
    if (academyLocalDate.month < birthDate.month ||
        (academyLocalDate.month == birthDate.month &&
            academyLocalDate.day < birthDate.day)) {
      result--;
    }
    return result;
  }

  int get age => ageOn(DateTime.now());

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

enum StudentApprovalStatus { incomplete, pending, approved, rejected, disabled }
