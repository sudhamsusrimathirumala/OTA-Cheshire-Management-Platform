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
- Mock student, schedule, curriculum, and notification data
- Cheshire OTA belt structure cleanup
- Admin control panel foundation
- Project Architecture Planning

### In Progress

- Application Documentation
- System Design
- Firebase data migration, starting with read-only schedule data

### Planned

- Authentication System
- Firestore security rules and production data validation
- Admin schedule writes, including bulk edit/delete actions
- Firebase-backed users, student profiles, announcements, events, and resources
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
|   |-- sample_constants.dart
|   |-- sample_notifications.dart
|   |-- sample_schedule.dart
|   `-- sample_student.dart
|-- models/
|   |-- class_session.dart
|   |-- curriculum_requirement.dart
|   |-- notification_item.dart
|   |-- student.dart
|   |-- student_profile.dart
|   `-- user_account.dart
|-- screens/
|   |-- curriculum_screen.dart
|   |-- login_screen.dart
|   |-- notification_detail_screen.dart
|   |-- notifications_screen.dart
|   |-- profile_screen.dart
|   |-- schedule_screen.dart
|   |-- signup_screen.dart
|   |-- student_dashboard_screen.dart
|   `-- welcome_screen.dart
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

The production app still defaults to `MockAppDataService` through
`lib/services/app_data_service_provider.dart`.

`FirebaseAppDataService` exists behind `const bool useFirebase = false`. When
enabled later, it listens to the Firestore `classSessions` collection with
`snapshots()`, keeps an internal schedule cache, and notifies the student and
admin schedule screens when Firestore schedule data changes.

All non-schedule data still delegates to `MockAppDataService`. Authentication,
Firestore writes, admin schedule persistence, announcements, events, resources,
users, and student profiles remain future work.

---

## Screenshots

Screenshots and progress updates will be added as development continues.

---

## Author

Sudhamsu Srimathirumala

Independent software development project focused on applying software engineering, UI/UX design, database design, and system architecture concepts to solve real-world organizational and communication challenges within a community organization.
