class Student {
  const Student({
    required this.id,
    required this.name,
    required this.belt,
    required this.age,
    required this.stickerCount,
    required this.stickersRequired,
    required this.nextRank,
  });

  final String id;
  final String name;
  final String belt;
  final int age;
  final int stickerCount;
  final int stickersRequired;
  final String nextRank;

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
