# July 15 MVP Deadline Plan

## Must be done before July 15

- Implement admin schedule Firestore writes for creating, editing, and deleting class sessions.
- Remove admin-facing Location ID fields from forms; derive location from admin context.
- Clean up announcement targeting so admins use belt, class group, student, or everyone audiences.
- Merge Critical priority into Important across admin and student UI.
- Simplify Admin Events filters to Draft, Published, and Past.
- Keep the student Events screen available and Firestore-backed.
- Keep the student Resources placeholder available from dashboard and bottom navigation.
- Add a student weekly schedule view.
- Keep Archive and Delete as separate admin actions.
- Clean up dashboard next-class text so it is not misleading.
- Keep the app compiling cleanly with format, analyze, and tests.

## Should be done if time allows

- Replace event date/time text fields with dedicated date and time pickers.
- Improve the Admin Events list into a richer calendar-like management view.
- Improve student class group profile handling beyond the current MVP preference fields.
- Polish Requires Action display and wording across admin and student UI.
- Apply small UI consistency fixes found during testing.

## Backlog after MVP

- Full admin calendar redesign.
- Full Firestore-backed Resources management.
- Firebase Auth.
- User approval workflow.
- Production Firestore rules.
- Push notifications.
- Attendance.
- Parent/student switching.
- Full schedule recurring and bulk editing system using `classTypeId`.
- Real role-based location management.
- Notification read/unread persistence.
- Manually migrate or delete old Firestore event documents with `eventType == "closure"`.
