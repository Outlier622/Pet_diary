# PetGrowth Diary (diary)

A Flutter-based pet daily-care diary app for tracking routines (food, health, hygiene) with a local SQLite timeline and optional reminders.

## Features

### Food
- Feed log (food/amount/note)
- Water log (amount/note)
- Allergy & preferences editor (free text)

### Health
- Weight log (kg)
- Medication log (name/dosage/schedule/note)
- Vet visit & vaccine log

### Hygiene
- Bath log
- Grooming & cleaning log
- Deworm log (internal / external)
- Clean reminders
  - One-time or weekly schedule
  - Enable/disable toggle
  - Local notifications

### Album
- Timeline-style photo album
- Pick images from gallery and copy into app documents directory
- Delete entry also deletes the image file (best-effort)

### SQLite Timeline (Read-only)
- Aggregated event timeline stored in SQLite
- Overview: total events + counts by type
- Range filter: all / last 30 days / last 7 days
- Event list preview with payload snippet

## Tech Stack
- Flutter / Dart
- SharedPreferences for local snapshots per module
- SQLite for aggregated timeline events
- Local Notifications for reminders (once/weekly)
- image_picker + path_provider for album file management

## Project Structure (high level)
- `lib/features/` - UI modals + stores (feed/health/hygiene/album)
- `lib/db/` - SQLite (`AppDb`, `schema`, `TimelineDao`, timeline read-only page)
- `lib/widgets/` - shared UI (e.g., CenterModal)

## Getting Started

### Prerequisites
- Flutter SDK (stable)
- iOS/Android emulator or a physical device

### Install & Run
```bash
flutter pub get
flutter run
