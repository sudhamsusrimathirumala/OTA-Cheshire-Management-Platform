import 'package:flutter/material.dart';

import 'push_navigation_coordinator.dart';
import 'push_notification_service.dart';

final GlobalKey<NavigatorState> otaNavigatorKey = GlobalKey<NavigatorState>();
PushNotificationService? pushNotificationService;
PushNavigationCoordinator? pushNavigationCoordinator;
