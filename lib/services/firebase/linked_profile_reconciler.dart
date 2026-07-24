import '../../models/student_profile.dart';

enum LinkedProfileResolutionStatus {
  complete,
  transitional,
  missing,
  unreadable,
}

class LinkedProfileResolution {
  const LinkedProfileResolution({
    required this.status,
    this.profiles = const [],
    this.missingIds = const [],
  });

  final LinkedProfileResolutionStatus status;
  final List<StudentProfile> profiles;
  final List<String> missingIds;
}

typedef MissingProfileLoader =
    Future<List<StudentProfile>> Function(List<String> profileIds);

/// Reconciles an account's linked IDs with the profile query snapshot.
///
/// Firestore can briefly publish a cache-backed query snapshot after the user
/// document has gained a new linked ID but before the matching profile is in
/// the local cache. Cache snapshots remain transitional. A server-backed
/// partial snapshot gets exactly one direct server confirmation.
Future<LinkedProfileResolution> reconcileLinkedProfiles({
  required List<String> expectedIds,
  required List<StudentProfile> snapshotProfiles,
  required bool isFromCache,
  required MissingProfileLoader loadMissingFromServer,
}) async {
  final profilesById = {
    for (final profile in snapshotProfiles) profile.id: profile,
  };
  var missingIds = expectedIds
      .where((id) => !profilesById.containsKey(id))
      .toList(growable: false);

  if (missingIds.isEmpty) {
    return LinkedProfileResolution(
      status: LinkedProfileResolutionStatus.complete,
      profiles: _orderedProfiles(expectedIds, profilesById),
    );
  }
  if (isFromCache) {
    return LinkedProfileResolution(
      status: LinkedProfileResolutionStatus.transitional,
      missingIds: missingIds,
    );
  }

  try {
    final recovered = await loadMissingFromServer(missingIds);
    for (final profile in recovered) {
      profilesById[profile.id] = profile;
    }
  } catch (_) {
    return LinkedProfileResolution(
      status: LinkedProfileResolutionStatus.unreadable,
      missingIds: missingIds,
    );
  }

  missingIds = expectedIds
      .where((id) => !profilesById.containsKey(id))
      .toList(growable: false);
  if (missingIds.isNotEmpty) {
    return LinkedProfileResolution(
      status: LinkedProfileResolutionStatus.missing,
      missingIds: missingIds,
    );
  }
  return LinkedProfileResolution(
    status: LinkedProfileResolutionStatus.complete,
    profiles: _orderedProfiles(expectedIds, profilesById),
  );
}

List<StudentProfile> _orderedProfiles(
  List<String> expectedIds,
  Map<String, StudentProfile> profilesById,
) => List.unmodifiable(expectedIds.map((id) => profilesById[id]!));
