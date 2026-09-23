class ApplicationStartupFailure implements Exception {
  const ApplicationStartupFailure({
    required this.code,
    required this.userMessage,
  });

  final String code;
  final String userMessage;

  @override
  String toString() => code;
}
