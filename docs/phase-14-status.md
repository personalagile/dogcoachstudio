# Phase 14 – Local reminders

Status: implemented.

## Delivered

- Three independent opt-in settings under Data & Privacy:
  - session reminders one hour before the appointment;
  - dog birthday reminders at 09:00 on the next birthday;
  - reminders for sessions that still require evaluation one hour after their scheduled end.
- iOS authorization is requested only after a trainer enables a reminder category.
- Pending DogCoach Studio notifications are rebuilt locally at launch, after every domain mutation, and after settings changes.
- Cancelled sessions, evaluated sessions, archived dogs, past appointment reminders, and records without birthdays are excluded.
- Notification content contains only a session title or dog name. Contact data, intake, safety notes, trainer-private notes, and report content never enter notifications.
- Settings and notification strings are localized in German, Spanish, and French.

## Verification

- Swift Testing covers independent category switches, date planning, cancelled/evaluated exclusions, and a private-note canary.
- Swift 6 strict-concurrency compilation covers the UserNotifications bridge.

Final verification on 2026-08-13:

- Full iPhone 16 / iOS 18.6 suite: 100 tests (106 parameterized invocations), 0 failures.
- Generic iOS device build: passed and signed as `com.personalagile.dogcoach` by team `32ZWRSU45R` using automatic signing.
