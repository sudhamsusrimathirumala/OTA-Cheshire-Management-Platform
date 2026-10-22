enum AnnouncementSource { everyone, targeted }

/// Both authorized feeds must finish before an absent item is unavailable.
class AnnouncementLoadState {
  final _resolved = <AnnouncementSource>{};
  final _errors = <AnnouncementSource, String>{};

  bool get isLoading => _resolved.length < AnnouncementSource.values.length;
  String? get errorMessage => _errors.values.firstOrNull;

  void resolve(AnnouncementSource source, {String? error}) {
    _resolved.add(source);
    if (error == null) {
      _errors.remove(source);
    } else {
      _errors[source] = error;
    }
  }

  void reset() {
    _resolved.clear();
    _errors.clear();
  }
}
