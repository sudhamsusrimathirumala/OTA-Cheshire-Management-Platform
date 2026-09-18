import 'package:flutter/foundation.dart';

enum GuestViewMode { admin, student, parent }

class GuestExperienceController extends ChangeNotifier {
  GuestViewMode _mode = GuestViewMode.parent;

  GuestViewMode get mode => _mode;

  void selectMode(GuestViewMode value) {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
  }

  void reset() => selectMode(GuestViewMode.parent);
}

final guestExperienceController = GuestExperienceController();
