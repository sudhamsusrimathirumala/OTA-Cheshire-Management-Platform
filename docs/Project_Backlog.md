# OTA Cheshire Management Platform - Project Backlog

**Last Updated:** June 27, 2026

---

# High Priority

## Authentication & User System

### Account Creation
- [ ] Parent account creation workflow
- [ ] Adult (18+) self-registration workflow
- [ ] Parent-managed student accounts for minors
- [ ] User approval and role assignment system

### Authentication
- [ ] Login functionality
- [ ] Google Sign-In integration
- [ ] Password reset functionality

### Core Screens
- [x] Schedule page
    - Time-scaled class blocks based on duration
    - Support up to two overlapping classes
    - Google Calendar-inspired day timeline layout
- [x] Curriculum page
- [x] Notifications page
- [x] Profile page

### Data Models
- [x] User account model
- [x] Student profile model
- [x] Student model
- [x] Parent role represented by UserAccount
- [x] Location ID field on backend-relevant models
- [ ] Belt progression model
- [x] Class scheduling model
- [x] Notification model

---

# Medium Priority

## Family Dashboard

### Parent Dashboard
Create a dedicated family dashboard for parents who do not train.

Each child card should display:
- Student name
- Current belt
- Next class
- Sticker progress (if applicable)
- Unread notification count

Additional requirements:
- [ ] Child cards open student dashboard when tapped
- [ ] Dynamic display based on belt progression system

---

## Profile Switching

### Parent + Student Accounts
Support profile switching for users who are both parents and students.

Examples:
- Parent View
- Student View
- Child 1
- Child 2

Tasks:
- [ ] Profile selector in dashboard header
- [ ] Dynamic dashboard updates when switching profiles

---

## Dynamic Class Information

### Next Class Countdown

Example:

> Starts in 2 hours 15 minutes

Tasks:
- [ ] Calculate countdown automatically
- [ ] Update in real time as class approaches

---

---

# Technical Debt

## Schedule Screen Refactor

Current Status:
- schedule_screen.dart is currently a large monolithic file.

Future Improvements:
- [ ] Extract schedule widgets into lib/widgets/schedule/
- [x] Move mock schedule data into lib/data/
- [x] Move schedule models into lib/models/
- [ ] Reduce schedule_screen.dart size
- [ ] Preserve existing functionality and appearance
- [ ] Model age/audience-based class eligibility separately from belt eligibility before production personalization

Priority:
Low

Reason:
The current implementation is functional. Refactoring should occur after the major application screens and features have stabilized.

---

## Curriculum Screen Refactor

Current Status:
- curriculum_screen.dart is functional and still readable, but it is growing as curriculum sections are added.

Future Improvements:
- [ ] Extract curriculum section widgets into lib/widgets/curriculum/ if the screen grows further
- [ ] Keep mock curriculum data in lib/data/ until real data integration begins

Priority:
Low

Reason:
The current screen is stable. Extraction can wait until real curriculum content, videos, and belt-specific requirements are better defined.

---

## Pre-Backend Readiness

Future Improvements:
- [x] Add AppDataService interface between UI and mock data
- [x] Add MockAppDataService as the active data source
- [x] Keep UI personalization driven by the selected student profile
- [ ] Decide the production app launch flow before authentication is added
- [ ] Define parent/student profile switching behavior before Firebase integration
- [ ] Add a no-linked-student-profile UI state for newly approved accounts
- [ ] Replace MockAppDataService with FirebaseAppDataService when Firestore is introduced
- [ ] Centralize repeated card and surface styling tokens if UI duplication continues to grow
- [ ] Keep notification attachments, links, and deep-link targets as UI placeholders until backend models are designed

Priority:
Medium

Reason:
These decisions should happen before backend work so Firebase data shape and navigation behavior do not have to be reworked later.

---

# Low Priority

## Dashboard Improvements

### Belt Progress Card Refinement

Current Design:
- Current Belt
- Next Rank
- Sticker Progress

Future Improvements:
- [ ] Increase visual emphasis on progression
- [ ] Make progress bar the primary focus
- [ ] Improve readability

Example:

```text
Blue -> Blue-Red

######----

2 / 4 Stickers
```

---

### Academy Updates Enhancements

- [x] Support richer announcement cards
- [x] Highlight urgent announcements
- [x] Make announcements individually tappable
- [x] Open full announcement details
- [ ] Add attachments, links, and deep-link destinations

---

## Notification Priority System

- [ ] Notification priority is selected by an admin when creating a notification.
- [x] Priority should be stored as part of the notification data.
- [x] Suggested levels:
  - General
  - Important
  - Critical
- [x] User-facing notification cards should visually reflect priority.

---

### Header Personalization

Potential additions:
- Cheshire Location
- Next Belt Goal
- Student achievements
- Dynamic greetings

Examples:

- Blue - Cheshire Location
- Next Goal: Blue-Red

Tasks:
- [ ] Redesign student information section
- [ ] Add additional contextual information

---

## UI Polish

### Martial Arts Brush Stroke Backgrounds

Current Status:
- Welcome, Login, and Signup screens use smooth abstract shapes.

Future Improvement:
- [ ] Replace with SVG-based martial arts brush stroke graphics
- [ ] Use Stack + Positioned SVG assets
- [ ] Maintain OTA branding and visual consistency

Priority:
Low

Reason:
Purely visual enhancement that does not affect functionality.

---

# Completed

## Welcome Screen
- [x] OTA branding implemented
- [x] Login button
- [x] Sign Up button
- [x] Material 3 design
- [x] Responsive layout

## Authentication Screens
- [x] Login Screen UI
- [x] Signup Screen UI
- [x] Navigation between screens

## Student Dashboard (MVP)
- [x] Personalized greeting
- [x] Next class card
- [x] Belt progress card
- [x] Academy updates section
- [x] Quick actions grid
- [x] Bottom navigation bar

## Schedule Screen
- [x] Google Calendar-inspired day timeline
- [x] Date navigation and date picker
- [x] Current-time indicator
- [x] Time-scaled class blocks
- [x] Overlapping class support
- [x] Eligibility highlighting
- [x] Class detail bottom sheet

## Curriculum Screen
- [x] Belt selection dropdown
- [x] Belt-specific mock curriculum data
- [x] Forms section with video placeholder
- [x] One-step sparring section
- [x] Wood-breaking section
- [x] Physical challenge section

## Notifications Screen
- [x] Announcement list
- [x] Filter chips
- [x] Read/unread visual states
- [x] Priority badges
- [x] Notification detail navigation

## Notification Detail Screen
- [x] Full notification title, category, priority, timestamp, and body
- [x] Important and critical priority styling
- [x] Future-ready placeholder resource sections

## Profile Screen
- [x] Student identity header
- [x] Student information section
- [x] Belt and promotion rows
- [x] Family and account section
- [x] Settings-style action rows

---

# Future Features (Ideas)

## Communication
- Parent <-> OTA messaging
- Student <-> OTA messaging
- Announcement system

## Curriculum
- Belt-specific curriculum access
- Technique videos
- Testing requirements

## Scheduling
- Personalized schedule recommendations
- Class reminders
- Event registration

## Administration
- Student database access for masters
- Promotion tracking
- Attendance tracking
- Location management

## Long-Term
- Multi-location support
- Tournament management
- Digital testing records
- Achievement tracking
