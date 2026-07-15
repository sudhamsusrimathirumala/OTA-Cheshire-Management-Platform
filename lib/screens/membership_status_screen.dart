import 'package:flutter/material.dart';

import '../models/academy_location.dart';
import '../models/student.dart';
import '../routes.dart';
import '../services/firebase/firebase_session_controller.dart';
import '../services/firebase/profile_membership_service.dart';
import '../theme/ota_colors.dart';

class MembershipStatusScreen extends StatefulWidget {
  const MembershipStatusScreen({super.key});

  @override
  State<MembershipStatusScreen> createState() => _MembershipStatusScreenState();
}

class _MembershipStatusScreenState extends State<MembershipStatusScreen> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    firebaseSessionController.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    firebaseSessionController.removeListener(_sessionChanged);
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final locations = await firebaseSessionController.membership
          .loadActiveLocations();
      if (!mounted) return;
      final location = await showDialog<AcademyLocation>(
        context: context,
        builder: (context) => _LocationDialog(locations: locations),
      );
      if (location == null) return;
      await firebaseSessionController.membership.applyToLocation(
        profileId: firebaseSessionController.selectedProfile!.id,
        locationId: location.id,
      );
      firebaseSessionController.dismissCreatedConfirmation();
    } on MembershipServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _leave() async {
    final acknowledged = await showDialog<bool>(
      context: context,
      builder: (context) => const _LeaveLocationDialog(),
    );
    if (acknowledged != true) return;
    setState(() => _loading = true);
    try {
      await firebaseSessionController.membership.leaveLocation(
        firebaseSessionController.selectedProfile!.id,
      );
    } on MembershipServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = firebaseSessionController;
    final profile = session.selectedProfile!;
    final status = profile.approvalStatus;
    final created = session.justCreatedProfiles;
    return Scaffold(
      backgroundColor: OtaColors.blush,
      appBar: AppBar(
        title: Text(
          created ? 'Your profile has been created' : 'OTA membership',
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : session.signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      _statusIcon(status),
                      size: 56,
                      color: OtaColors.maroon,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      created
                          ? 'Your OTA account and student profiles are ready.'
                          : _statusTitle(status),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _statusMessage(
                        status,
                        session.selectedLocationName ?? profile.locationId,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    if (session.profiles.length > 1)
                      DropdownButtonFormField<String>(
                        initialValue: profile.id,
                        decoration: const InputDecoration(
                          labelText: 'Selected student',
                          border: OutlineInputBorder(),
                        ),
                        items: session.profiles
                            .map(
                              (student) => DropdownMenuItem(
                                value: student.id,
                                child: Text(
                                  '${student.name} — ${student.approvalStatus.name}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _loading
                            ? null
                            : (id) => session.selectProfile(id!),
                      ),
                    const SizedBox(height: 16),
                    _InfoRow(label: 'Student', value: profile.name),
                    _InfoRow(label: 'Belt rank', value: profile.beltRank),
                    _InfoRow(label: 'Membership', value: status.name),
                    if (profile.locationId.isNotEmpty)
                      _InfoRow(
                        label: 'Location',
                        value:
                            session.selectedLocationName ?? profile.locationId,
                      ),
                    if (status == StudentApprovalStatus.rejected &&
                        profile.rejectionReason != null)
                      _InfoRow(
                        label: 'Reason',
                        value: profile.rejectionReason!,
                      ),
                    const SizedBox(height: 20),
                    if (status == StudentApprovalStatus.incomplete ||
                        status == StudentApprovalStatus.rejected)
                      FilledButton.icon(
                        onPressed: _loading ? null : _apply,
                        icon: const Icon(Icons.add_location_alt_rounded),
                        label: const Text('Apply to an academy'),
                      ),
                    if (created)
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () {
                                session.dismissCreatedConfirmation();
                                Navigator.of(
                                  context,
                                ).pushReplacementNamed(OtaRoutes.profile);
                              },
                        child: const Text('Do this later'),
                      ),
                    if (!created)
                      TextButton.icon(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(
                                context,
                              ).pushReplacementNamed(OtaRoutes.profile),
                        icon: const Icon(Icons.person_outline_rounded),
                        label: const Text('Manage profile'),
                      ),
                    if (status == StudentApprovalStatus.pending)
                      OutlinedButton.icon(
                        onPressed: _loading ? null : session.retry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh'),
                      ),
                    if (profile.locationId.isNotEmpty &&
                        status != StudentApprovalStatus.disabled) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _leave,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Leave academy location'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: OtaColors.actionRed,
                        ),
                      ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: OtaColors.actionRed),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationDialog extends StatelessWidget {
  const _LocationDialog({required this.locations});
  final List<AcademyLocation> locations;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Apply to a location'),
    content: SizedBox(
      width: 520,
      child: locations.isEmpty
          ? const Text('No active academy locations are available.')
          : ListView.separated(
              shrinkWrap: true,
              itemCount: locations.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final location = locations[index];
                final subtitle = locationSelectionSubtitle(location);
                return ListTile(
                  title: Text(location.name),
                  subtitle: subtitle == null ? null : Text(subtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, location),
                );
              },
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}

class _LeaveLocationDialog extends StatefulWidget {
  const _LeaveLocationDialog();
  @override
  State<_LeaveLocationDialog> createState() => _LeaveLocationDialogState();
}

class _LeaveLocationDialogState extends State<_LeaveLocationDialog> {
  bool acknowledged = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Leave academy location?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This profile will immediately lose schedule, events, curriculum, resources, and academy notifications. The account and student profile will not be deleted, and the profile may apply again later.',
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: acknowledged,
          onChanged: (value) => setState(() => acknowledged = value ?? false),
          title: const Text(
            'I understand that this profile will lose academy access.',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Keep membership'),
      ),
      FilledButton(
        onPressed: acknowledged ? () => Navigator.pop(context, true) : null,
        style: FilledButton.styleFrom(backgroundColor: OtaColors.actionRed),
        child: const Text('Confirm and leave'),
      ),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: Flexible(
      child: Text(
        value,
        textAlign: TextAlign.right,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

String _statusTitle(StudentApprovalStatus status) => switch (status) {
  StudentApprovalStatus.incomplete => 'Join an academy location',
  StudentApprovalStatus.pending => 'Approval pending',
  StudentApprovalStatus.approved => 'Membership approved',
  StudentApprovalStatus.rejected => 'Application not approved',
  StudentApprovalStatus.disabled => 'Membership disabled',
};

String _statusMessage(
  StudentApprovalStatus status,
  String locationId,
) => switch (status) {
  StudentApprovalStatus.incomplete =>
    'Basic profile management is available. Apply to an active academy location to request academy access.',
  StudentApprovalStatus.pending =>
    'The application for $locationId is waiting for academy review. Academy content remains unavailable.',
  StudentApprovalStatus.approved => 'Academy access is active.',
  StudentApprovalStatus.rejected =>
    'You may apply to another active location or clear the current location.',
  StudentApprovalStatus.disabled =>
    'Access is disabled. Contact the academy for assistance.',
};

IconData _statusIcon(StudentApprovalStatus status) => switch (status) {
  StudentApprovalStatus.incomplete => Icons.add_location_alt_rounded,
  StudentApprovalStatus.pending => Icons.hourglass_top_rounded,
  StudentApprovalStatus.approved => Icons.verified_rounded,
  StudentApprovalStatus.rejected => Icons.info_outline_rounded,
  StudentApprovalStatus.disabled => Icons.block_rounded,
};

@visibleForTesting
String? locationSelectionSubtitle(AcademyLocation location) {
  final address = location.formattedAddress.trim();
  return address.isEmpty ? null : address;
}
