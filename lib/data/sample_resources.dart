import '../models/academy_resource.dart';
import 'sample_constants.dart';

final sampleAcademyResources = [
  AcademyResource(
    id: 'parent_night_out_registration',
    title: 'Parent Night Out Registration',
    description: 'Registration form for the next Parent Night Out event.',
    resourceSection: 'general',
    category: 'general',
    linkUrl: 'https://forms.gle/ota-parent-night-out',
    locationId: otaCheshireLocationId,
    isPublished: true,
    createdAt: DateTime(2026, 6, 20, 9),
    updatedAt: DateTime(2026, 6, 20, 9),
  ),
  AcademyResource(
    id: 'belt_testing_checklist',
    title: 'Belt Testing Checklist',
    description:
        'Family checklist for testing day arrival, uniform, and preparation.',
    resourceSection: 'general',
    category: 'testing',
    locationId: otaCheshireLocationId,
    isPublished: true,
    createdAt: DateTime(2026, 6, 24, 10),
    updatedAt: DateTime(2026, 6, 24, 10),
  ),
  AcademyResource(
    id: 'student_handbook',
    title: 'Student Handbook',
    description: 'Academy policies and family reference information.',
    resourceSection: 'general',
    category: 'general',
    locationId: otaCheshireLocationId,
    isPublished: false,
    createdAt: DateTime(2026, 6, 25, 12),
    updatedAt: DateTime(2026, 6, 25, 12),
  ),
];
