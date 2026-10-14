import 'dart:async';

import 'package:flutter/foundation.dart';

/// Only explicitly approved labels and scalar timings can enter the viewer.
class PerformanceEvent {
  const PerformanceEvent({
    required this.stage,
    required this.journeyMilliseconds,
    this.createMilliseconds,
    this.durationMilliseconds,
    this.fromCache,
    this.documentCount,
  });

  final String stage;
  final int journeyMilliseconds;
  final int? createMilliseconds;
  final int? durationMilliseconds;
  final bool? fromCache;
  final int? documentCount;

  String get text =>
      '${createMilliseconds == null ? '' : '+$createMilliseconds ms  '}$stage'
      '  journey=$journeyMilliseconds ms'
      '${durationMilliseconds == null ? '' : '  duration=$durationMilliseconds ms'}'
      '${fromCache == null ? '' : '  source=${fromCache! ? 'cache' : 'server'}'}'
      '${documentCount == null ? '' : '  count=$documentCount'}';
}

class PerformanceEventBuffer {
  static const maximumEvents = 300;
  static const _labels = <String, String>{
    'flutter_start': 'flutter_start',
    'firebase_initialized': 'firebase_initialized',
    'auth_state_resolved': 'auth_state_resolved',
    'auth_user': 'authenticated_user_available',
    'claims_start': 'claims_started',
    'claims_end': 'claims_finished',
    'user_listener_started': 'user_listener_started',
    'create_profiles_pressed': 'create_profiles_pressed',
    'existing_user_validation_start': 'user_validation_started',
    'existing_user_validation_end': 'user_validation_finished',
    'location_validation_start': 'location_validation_started',
    'location_validation_end': 'location_validation_finished',
    'validation_wave_started': 'validation_wave_started',
    'validation_wave_finished': 'validation_wave_finished',
    'batch_commit_start': 'batch_commit_started',
    'batch_commit_end': 'batch_commit_finished',
    'batch_acknowledged': 'batch_acknowledged',
    'profiles_listener_started': 'profiles_listener_started',
    'profile_subscription_cancel_started':
        'profile_subscription_cancel_started',
    'profile_subscription_cancel_finished':
        'profile_subscription_cancel_finished',
    'location_subscription_cancel_started':
        'location_subscription_cancel_started',
    'location_subscription_cancel_finished':
        'location_subscription_cancel_finished',
    'profile_transition_resume_started': 'profile_transition_resume_started',
    'profile_transition_resume_finished': 'profile_transition_resume_finished',
    'member_transition_wait_started': 'member_transition_wait_started',
    'member_transition_wait_finished': 'member_transition_wait_finished',
    'post_create_wait_started': 'post_create_wait_started',
    'post_create_wait_finished': 'post_create_wait_finished',
    'user_first_snapshot': 'user_snapshot_received',
    'post_create_user_snapshot': 'user_snapshot_received',
    'post_create_profile_snapshot': 'profile_snapshot_received',
    'reconciliation_start': 'profile_reconciliation_started',
    'reconciliation_end': 'profile_reconciliation_finished',
    'recovery_grace_started': 'recovery_grace_started',
    'recovery_grace_finished': 'recovery_grace_finished',
    'server_recovery_started': 'server_recovery_started',
    'server_recovery_finished': 'server_recovery_finished',
    'location_access_listener_started': 'location_access_listener_started',
    'location_access_first_snapshot': 'location_snapshot_received',
    'location_access_ready': 'location_access_ready',
    'member': 'session_member_reached',
    'app_data_eligible': 'app_data_service_started',
    'schedule_listener_started': 'schedule_listener_started',
    'schedule_first_snapshot': 'schedule_first_snapshot',
    'schedule_callback': 'schedule_snapshot_received',
    'schedule_model_ready': 'schedule_model_ready',
    'schedule_model_parsed': 'schedule_model_parsed',
    'schedule_notified': 'schedule_notified',
    'dashboard_usable_frame': 'dashboard_frame_ready',
    'schedule_usable_frame': 'schedule_frame_ready',
    'create_profiles_pressed_to_member': 'TOTAL_create_profiles_to_member',
    'create_profiles_pressed_to_dashboard_usable_frame':
        'TOTAL_create_profiles_to_dashboard_usable',
  };

  final List<PerformanceEvent> _events = [];
  final ValueNotifier<int> revision = ValueNotifier(0);
  int? _createStart;
  bool _publishPending = false;

  List<PerformanceEvent> get events => List.unmodifiable(_events);
  String get exportText => _events.map((event) => event.text).join('\n');
  int? createElapsed(int journeyMilliseconds) =>
      _createStart == null ? null : journeyMilliseconds - _createStart!;

  void record(
    String stage,
    int journeyMilliseconds, {
    int? durationMilliseconds,
    bool? fromCache,
    int? count,
  }) {
    final label = _labels[stage];
    if (label == null) return;
    if (stage == 'create_profiles_pressed') {
      _events.clear();
      _createStart = journeyMilliseconds;
    }
    _events.add(
      PerformanceEvent(
        stage: label,
        journeyMilliseconds: journeyMilliseconds,
        createMilliseconds: createElapsed(journeyMilliseconds),
        durationMilliseconds: durationMilliseconds,
        fromCache: fromCache,
        documentCount: count,
      ),
    );
    if (_events.length > maximumEvents) _events.removeAt(0);
    _publish();
  }

  /// Clears viewer state only; never resets session/listener state.
  void clear() {
    _events.clear();
    _createStart = null;
    _publish();
  }

  void _publish() {
    if (_publishPending) return;
    _publishPending = true;
    // Stage collection can run inside Flutter build/post-frame callbacks.
    // Publish outside that synchronous callback without rebuilding the app.
    scheduleMicrotask(() {
      _publishPending = false;
      revision.value++;
    });
  }
}
