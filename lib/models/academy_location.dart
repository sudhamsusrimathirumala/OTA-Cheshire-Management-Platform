class AcademyLocation {
  const AcademyLocation({
    required this.id,
    required this.name,
    required this.timeZoneId,
    required this.isActive,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String timeZoneId;
  final bool isActive;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get formattedAddress {
    final region = [
      state,
      postalCode,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' ');
    final cityLine = [
      city,
      region,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');
    final lines = [
      addressLine1,
      addressLine2,
      cityLine,
      country,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();
    return lines.join('\n');
  }
}
