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
- Firebase (planned)
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
- Curriculum UI planning
- Notifications UI
- Profile placeholder screen
- Reusable bottom navigation
- Navigation structure for primary app destinations
- Application Theme System
- OTA brand color system
- Basic app models
- Mock student, schedule, and notification data
- Cheshire OTA belt structure cleanup
- Project Architecture Planning

### In Progress

- Application Documentation
- System Design
- Profile UI planning

### Planned

- Authentication System
- Database Integration
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
└── images/
    └── ota_logo.png

lib/
├── data/
│   ├── sample_notifications.dart
│   ├── sample_schedule.dart
│   ├── sample_student.dart
│   └── sample_curriculum.dart
├── models/
│   ├── class_session.dart
│   ├── curriculum_requirement.dart
│   ├── notification_item.dart
│   ├── parent.dart
│   └── student.dart
├── screens/
│   ├── curriculum_screen.dart
│   ├── login_screen.dart
│   ├── notification_detail_screen.dart
│   ├── notifications_screen.dart
│   ├── profile_screen.dart
│   ├── schedule_screen.dart
│   ├── signup_screen.dart
│   ├── student_dashboard_screen.dart
│   └── welcome_screen.dart
├── theme/
│   └── ota_colors.dart
├── widgets/
│   ├── notifications/
│   │   └── notification_card.dart
│   ├── ota_action_button.dart
│   ├── ota_auth_switch_link.dart
│   ├── ota_auth_text_field.dart
│   ├── ota_bottom_nav_bar.dart
│   ├── ota_branded_scaffold.dart
│   └── ota_logo_mark.dart
├── main.dart
└── routes.dart

docs/
└── Project_Backlog.md

test/
└── widget_test.dart
```

---

## Screenshots

Screenshots and progress updates will be added as development continues.

---

## Author

Sudhamsu Srimathirumala

Independent software development project focused on applying software engineering, UI/UX design, database design, and system architecture concepts to solve real-world organizational and communication challenges within a community organization.
