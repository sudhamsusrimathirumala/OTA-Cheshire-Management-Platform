# OTA Cheshire Management Platform

A modern management and communication platform for Olympic Taekwondo Academy (OTA) designed to improve communication, scheduling, curriculum access, and organization for students, parents, instructors, and administrators.

---

## Project Overview

The OTA Cheshire Management Platform is a cross-platform mobile application being developed using Flutter. The goal of the project is to replace fragmented communication methods with a centralized platform that provides students, parents, and instructors with access to schedules, announcements, curriculum information, belt progression, events, and academy resources.

The application is being designed with scalability in mind, allowing support for multiple academy locations, role-based access control, targeted communications, and personalized user experiences.

---

## Motivation

Currently, many interactions between families and the academy occur through text messages, paper handouts, social media posts, and verbal announcements. Important information can be missed, communication can become fragmented, and academy resources are not always easily accessible.

This project aims to create a single platform where students, parents, instructors, and administrators can efficiently communicate and access the information relevant to them.

---

## Planned Features

### Student Features

- Personalized dashboard
- Belt progression tracking
- Curriculum access
- Class schedule access
- Event information
- Academy announcements
- Notification center

### Parent Features

- Family dashboard
- Multiple student profile management
- Student progress tracking
- Academy communication
- Event registration and updates

### Instructor & Administrator Features

- Student database access
- Academy-wide announcements
- Targeted notifications
- Schedule management
- Promotion tracking
- Administrative tools

---

## Technology Stack

- Flutter
- Dart
- Firebase Core, Firestore, and Auth packages configured
- Git
- GitHub

---

## Current Development Status

### Completed

- Welcome Screen
- Login Screen UI
- Signup Screen UI
- Student Dashboard UI
- Schedule/Calendar UI
- Curriculum UI
- Notifications UI
- Notification Detail UI
- Profile UI
- Reusable bottom navigation
- Navigation structure for primary app destinations
- Application Theme System
- OTA brand color system
- Basic app models
- User account and student profile data separation
- App data service abstraction with mock implementation
- Firebase app initialization and Android Firebase configuration
- Firestore collection constants and mock-data seed service
- Development-only Firestore seed entrypoints
- Firebase schedule data service behind a feature switch
- Stream-based Firestore schedule cache for `classSessions`
- Stream-based Firestore announcement cache for `announcements`
- Stream-based Firestore admin event cache for `events`
- Stream-based Firestore admin student directory cache for `studentProfiles`
- Mock student, schedule, curriculum, and notification data
- Cheshire OTA belt structure cleanup
- Admin control panel foundation
- Admin dashboard, schedule, announcements, students, and events pages
- Project Architecture Planning

### In Progress

- Application Documentation
- System Design
- Firebase read-path migration through `FirebaseAppDataService`

### Planned

- Authentication System
- Firestore security rules and production data validation
- Admin schedule writes, including bulk edit/delete actions
- Firebase-backed users, guardian name resolution, profile switching, and admin write flows
- Student/parent-facing events and resources
- Full Curriculum System
- Full Notification System
- Family Dashboard
- Administrative Tools
- Role-based user experiences
- Real data integration

---

## Project Structure

```text
assets/
`-- images/
    `-- ota_logo.png

lib/
|-- data/
|   |-- sample_curriculum.dart
|   |-- sample_events.dart
|   |-- sample_constants.dart
|   |-- sample_notifications.dart
|   |-- sample_schedule.dart
|   `-- sample_student.dart
|-- models/
|   |-- academy_event.dart
|   |-- class_session.dart
|   |-- curriculum_requirement.dart
|   |-- notification_item.dart
|   |-- student.dart
|   |-- student_profile.dart
|   `-- user_account.dart
|-- screens/
|   |-- admin/
|   |   |-- admin_announcements_screen.dart
|   |   |-- admin_dashboard_screen.dart
|   |   |-- admin_events_screen.dart
|   |   |-- admin_schedule_screen.dart
|   |   `-- admin_students_screen.dart
|   |-- curriculum_screen.dart
|   |-- login_screen.dart
|   |-- notification_detail_screen.dart
|   |-- notifications_screen.dart
|   |-- profile_screen.dart
|   |-- schedule_screen.dart
|   |-- signup_screen.dart
|   |-- student_dashboard_screen.dart
|   `-- welcome_screen.dart
|-- firebase_options.dart
|-- services/
|   |-- app_data_service.dart
|   |-- app_data_service_provider.dart
|   |-- firebase/
|   |   `-- firebase_app_data_service.dart
|   |-- firestore/
|   |   |-- firestore_collections.dart
|   |   `-- firestore_seed_service.dart
|   `-- mock_app_data_service.dart
|-- theme/
|   `-- ota_colors.dart
|-- utils/
|   `-- notification_formatters.dart
|-- widgets/
|   |-- admin/
|   |   `-- admin_bottom_nav_bar.dart
|   |-- notifications/
|   |   `-- notification_card.dart
|   |-- profile/
|   |   `-- profile_section.dart
|   |-- ota_action_button.dart
|   |-- ota_auth_switch_link.dart
|   |-- ota_auth_text_field.dart
|   |-- ota_bottom_nav_bar.dart
|   |-- ota_branded_scaffold.dart
|   `-- ota_logo_mark.dart
|-- main.dart
|-- seed_firestore_main.dart
`-- routes.dart

docs/
`-- Project_Backlog.md

test/
`-- widget_test.dart

tool/
`-- seed_firestore.dart
```

---

## Current Data Layer State

The app reads through `AppDataService`, which is selected in
`lib/services/app_data_service_provider.dart`.

The current development switch is `const bool useFirebase = true`, so
`FirebaseAppDataService` is active when Firebase is available. It keeps live
Firestore stream caches for:

- `classSessions` for student and admin schedule views
- `announcements` for student notifications, dashboard OTA updates, and admin announcements
- `events` for the admin events page
- `studentProfiles` for the admin student directory

The Firebase service uses `snapshots()`, handles empty or malformed documents
without crashing, and notifies listening screens when Firestore data changes.
If Firebase is unavailable during local tests, the service falls back to
`MockAppDataService` data.

The following areas still intentionally use mock/delegated behavior:

- Firebase Auth and real user identity
- Linked student profile ownership and profile switching
- Guardian/user account name resolution
- Curriculum and resources
- Student/parent-facing events and resources pages
- Admin writes for schedule, announcements, events, and student profiles

---

## Screenshots

Screenshots and progress updates will be added as development continues.

---

## Author

Sudhamsu Srimathirumala

Independent software development project focused on applying software engineering, UI/UX design, database design, and system architecture concepts to solve real-world organizational and communication challenges within a community organization.
