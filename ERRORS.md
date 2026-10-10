# Error & Issue Tracking (ERRORS.md)

## Fixed

### 1. Main Bug: Student Registration Without Tutor Hangs / Fails
- **Symptom:** Admin Console > People > Register New Person: Creating a STUDENT without an assigned tutor ("None / Select Later", e.g. Sayanth, +91 9895061553, CE, 1st Year) hung on "Saving...".
- **Root Cause:** When "None / Select Later" was selected or tutorId was omitted, the mobile registration payload sent `tutorId` as omitted/empty, and the dialog lacked a strict catch-all resetting `_busy = false`; on the backend, empty string `tutorId` was not uniformly sanitized as `null`, and user/student creation lacked transaction rollback guarantees on failure.
- **Backend Fix:** 
  - `cleanTutorId` sanitizes empty string, whitespace, and undefined to `null`.
  - User and Student profile creation are wrapped within a single atomic database transaction (`this.prisma.$transaction`).
  - Phone numbers are normalized to 10 digits globally using `normalizeMobile`.
  - Duplicate phone numbers return `409 ConflictException` with `{ statusCode: 409, message: "A user with mobile <phone> already exists" }`.
- **Frontend Fix:**
  - `_PersonFormDialog` explicitly sets `tutorId: null` when no tutor is selected.
  - The submit handler wraps API calls with a 15-second timeout and `try/catch/finally` guaranteeing `_busy = false` is always restored.
  - On success, the dialog pops, a confirmation SnackBar is displayed, and the list and tab counts refresh immediately.
- **Verification:**
  - Automated backend tests in `apps/api/src/admin/admin-student-registration.spec.ts` pass (student without tutor, student with tutor, 409 conflict, and atomic transaction rollback).
  - Automated Flutter widget test in `apps/mobile/test/admin_register_person_test.dart` passes.

### 2. UI Selection Bar Persisted Across Tabs
- **Symptom:** The "N student(s) selected / Assign Tutor" bar remained visible when switching from the Students tab to other tabs (Tutors, HODs, Guards, Admins).
- **Fix:** Added `onTap` and listener to `_tabController` in `_AdminPeopleTabState` to immediately clear `_selectedStudentIds` whenever the user switches away from the Students tab, and conditioned the bar visibility strictly on `_tabController.index == 0 && _selectedStudentIds.isNotEmpty`.
- **Verification:** Verified in widget test `admin_register_person_test.dart: Bug 2: Selection bar appears on Students tab and clears when switching tabs` (PASS).

### 3. Unified Async Action Handling Across Flutter Screens
- **Symptom:** Several async dialogs, forms, and button actions across the app had disjointed error handling without unified timeouts or button re-enabling.
- **Fix:** Applied `AsyncActionHelper.run(context, ...)` across `login_screen.dart`, `student_screen.dart`, `approver_screen.dart`, `guard_screen.dart`, and `admin_screen.dart`.
- **Verification:** `flutter analyze` passed with 0 issues; `flutter test` passed all 15 tests.

### 4. Build & Static Analysis Cleanups
- **API:** Added `"lint": "tsc --noEmit"` to `apps/api/package.json`.
- **Mobile:** Removed unused imports and guarded `BuildContext` async gaps in `apps/mobile/lib/approver_screen.dart` and `apps/mobile/lib/admin_screen.dart`.

## Blocked
- None.

## Open / Deferred Features (Not MVP Bugs)
- Device Hardware Attestation (Deferred per architectural PRD decision log #3)
- Offline Gate Scanning (Requires connected backend)
