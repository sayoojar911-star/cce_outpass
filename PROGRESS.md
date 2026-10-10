# Project Progress Tracking (PROGRESS.md)

## Current Status: Repair Complete & All Checks Passing

### 1. Environment & Infrastructure
- [x] Embedded PostgreSQL running on `localhost:5433` (`.pgdata` cluster).
- [x] NestJS API daemon running on `http://localhost:3000/v1` and serving compiled Flutter web artifacts at `/`.
- [x] Database migrations deployed and database seeded with default users (Admin `8921578838`, HOD `8921578832`, Tutor `8921578833`, Student `8921578831`, Guard `8921578834`), departments, and gate.

### 2. Main Bug: Student Registration Without Tutor
- [x] Reproduced via curl against API with admin JWT (`tutorId` omitted and `tutorId: ""`).
- [x] Backend fix: empty string sanitized to `null`, atomic Prisma transaction for user and student profile creation, phone normalization to 10 digits globally, 409 conflict for duplicate mobile numbers, uniform JSON error responses.
- [x] Database checked for orphan rows (orphans verified at 0, sayanth test records purged).
- [x] Frontend fix: `_PersonFormDialog` explicitly sends `tutorId: null` when no tutor is selected, wraps request in 15-second timeout with `try/catch/finally` guaranteeing button re-enabling, closes dialog on success, shows success SnackBar, and refreshes list and tab counts.
- [x] Automated backend tests in `apps/api/src/admin/admin-student-registration.spec.ts` passing (student without tutor, student with tutor, duplicate phone, transaction rollback).
- [x] Automated Flutter widget test in `apps/mobile/test/admin_register_person_test.dart` passing.

### 3. Unified Async Handling & Timeout Protection
- [x] Created / enhanced `AsyncActionHelper.run` with 15-second timeout, error SnackBar, and guaranteed finally handler.
- [x] Applied across:
  - `apps/mobile/lib/login_screen.dart` (`_sendOtp`, `_verify`)
  - `apps/mobile/lib/student_screen.dart` (`_submit`, cancel outpass)
  - `apps/mobile/lib/approver_screen.dart` (`_decide`)
  - `apps/mobile/lib/guard_screen.dart` (`_submitScan`)
  - `apps/mobile/lib/admin_screen.dart` (`_showAssignTutorDialog`, `_deleteUser`, `_toggleDeactivate`, `_showDeptDialog`, `_showAddDivisionDialog`, `_deleteDivision`, `_deleteDepartment`, `_cancelPass`, `_save` settings, `_submit` bulk add).

### 4. Selection Bar Tab Persistence Fix
- [x] Added `onTap` callback and tab listener to clear selected student IDs when switching tabs.
- [x] Restricted bar visibility to `_tabController.index == 0 && _selectedStudentIds.isNotEmpty`.

### 5. Clean Build & Test Verification
- [x] `apps/api`: `npm run build` (PASS - 0 errors)
- [x] `apps/api`: `npm run lint` (PASS - 0 errors)
- [x] `apps/api`: `npm test` (PASS - 6 test suites, 51 tests passed)
- [x] `apps/mobile`: `flutter analyze` (PASS - 0 issues found)
- [x] `apps/mobile`: `flutter test` (PASS - 15 tests passed)
- [x] `apps/mobile`: `flutter build web` (PASS - compiled to `build/web` and deployed to `apps/api/public`)
