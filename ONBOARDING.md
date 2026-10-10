# CCE Outpass — Comprehensive Project Onboarding Report

> **Prepared by:** Senior Software Engineering Advisor  
> **Workspace:** `College-app` (Christ College of Engineering, Irinjalakuda — Outpass System)  
> **Status:** MVP Core Loop Implemented with In-Memory Demo Mode & Full NestJS/PostgreSQL Backend

---

## 1. PROJECT OVERVIEW

### What the App Does & Who It's For
**CCE Outpass** is a digital campus egress and entry security system purpose-built for **Christ College of Engineering (CCE), Irinjalakuda**. It replaces physical paper pass books with a tamper-resistant, multi-tier approval workflow backed by cryptographically signed, rotating QR codes.

The system serves 5 distinct user groups:
1. **Students:** Apply for normal or emergency outpasses, track approvals in real time, view rotating cryptographic QR codes to present at physical campus gates, and cancel requests prior to exit.
2. **Faculty / Tutors:** Review and approve/reject outpass requests submitted by their assigned batch students (with mandatory rejection reasons).
3. **Department Heads (HODs):** Secondary institutional approval tier for department students; granting final approval activates the student's dynamic QR gate token.
4. **Campus Security Guards:** Gatekeepers stationed at physical checkpoints who scan student QR codes (or enter manual tokens as fallback) in either `EXIT` or `ENTRY` directions, receiving immediate visual color feedback (green allow / red deny), automatic double-use prevention, and 10-minute return dwell enforcement.
5. **System Administrators (ADMIN):** Manage campus population (Students, Tutors, HODs, Guards), add single persons or bulk import via CSV, manage college departments and HOD assignments, monitor active outpasses with filters/search, and configure college dwell time and outpass categories.

---

### Feature Completeness Analysis

| Feature Area | Status | Evidence in Codebase | Notes / Missing Items |
| :--- | :---: | :--- | :--- |
| **Temporary Auth Config** | ✅ Finished | `apps/mobile/lib/config/temp_auth_config.dart`, `apps/api/src/auth/temp-auth.config.ts` | Single source of truth: `ADMIN_PHONE = 8921578838`, `TEMP_OTP = 123456`. |
| **Academic Structure & Seed** | ✅ Finished | `schema.prisma`, `seed.ts`, `apps/api/src/admin/admin.controller.ts` | Departments (CSE, CSDS, CSBS, EC, EEE, ME, CE, VLSI), Divisions model per department, Years 1-4. Idempotent seed. |
| **Role-Specific Registration** | ✅ Finished | `apps/mobile/lib/admin_screen.dart`, `apps/api/src/admin/admin.controller.ts` | Dynamic forms per role (Student, Tutor, HOD, Guard, Admin), dependent dropdowns, 1 HOD per dept with replace option, backend mirror validation. |
| **Phone Number Normalization** | ✅ Finished | `api_client.dart` (`normalizeMobilePhone`), `auth/dto.ts` (`normalizeMobile`) | Single standard: 10 digits across all screens, registration, editing, duplicate checks, and login. Strips `+91`, `91`, dashes, spaces. |
| **Admin Role & Management UI** | ✅ Finished | `apps/mobile/lib/admin_screen.dart`, `apps/api/src/admin/admin.controller.ts` | Dashboard metrics, People tabs (CRUD + role-specific forms + 15s timeout), Departments & Divisions manager, Outpass Monitor, Settings. |
| **Unified UI Design System** | ✅ Finished | `apps/mobile/lib/theme/app_theme.dart` | Clean typography, role color accents, semantic status chips, empty states, hero QR countdown ring. |
| **Student Outpass Creation** | ✅ Finished | `apps/mobile/lib/student_screen.dart` (`RequestFormScreen`), `apps/api/src/outpass/outpass.service.ts` | Start/end datetime pickers, purpose categories, emergency flag, validation against overlaps. |
| **Tutor & HOD Approvals** | ✅ Finished | `approver_screen.dart`, `approvals.controller.ts`, `outpass.service.ts` | Department/year/division scoping for tutors; department scoping for HODs. Sequential state transitions (`PENDING_TUTOR` -> `PENDING_HOD` -> `APPROVED`). |
| **Rotating Dynamic QR Code** | ✅ Finished | `qr_token.dart`, `apps/api/src/gate/token-verify.ts`, `student_screen.dart` | ECDSA P-256 dynamic token with animated countdown ring and copy button for guards. |
| **Guard Gate Verification** | ✅ Finished | `guard_screen.dart`, `apps/api/src/gate/gate.service.ts` | Camera scanning via `mobile_scanner`, manual entry fallback, single-use check, min 10-min dwell check. |
| **Audit Logging** | ✅ Finished | `apps/api/src/audit/audit.service.ts` | Append-only SHA-256 hash-chained audit ledger (`AuditLog` table). |
| **Expiry & Overdue Automation** | ✅ Finished | `apps/api/src/jobs/expiry.service.ts` | Background cron job runs every minute, marking unused passes `EXPIRED` and unreturned students `OVERDUE` (+15 min grace). |
| **Real Production API Connection** | ✅ Finished | `apps/api` via Prisma / PostgreSQL | Zero mock backend. Flutter app connects exclusively to live NestJS API. |
| **Push Notifications (FCM / APNS)** | 🟡 Half-done / Stubbed | `apps/api/src/notifications/notifications.service.ts` | Inserts rows into the DB `Notification` table; actual Firebase Cloud Messaging push dispatch is deferred. |
| **SMS OTP Verification** | 🟡 Half-done | `login_screen.dart`, `firebase-auth.service.ts`, `temp_auth_config.dart` | Temporary OTP `123456` enabled for development; gated by admin registry check. |
| **Device Hardware Attestation** | 🔴 Missing / Cut | `docs/decisions.md` (Decision #3), `apps/mobile/lib/qr_token.dart` | Software keys generated via `pointycastle`; hardware Secure Enclave / Android Keystore & Play Integrity are deferred. |
| **Hostel Warden Approval Tier** | 🔴 Missing / Deferred | PRD §Explicit MVP cuts | `PENDING_WARDEN` state is mentioned in the PRD but deferred to subsequent phases. |
| **Offline Gate Scanning** | 🔴 Missing / Deferred | PRD §7.6 | Guard scanner currently requires network connectivity to verify or simulate state. |
| **Localization (Malayalam)** | 🔴 Missing / Deferred | PRD FR-STU-15 | UI is strictly English-only at present. |

---

## 2. TECH STACK

### Frontend (`apps/mobile`)
- **Framework:** Flutter 3.x (Dart SDK `^3.12.2`)
- **Target Platforms:** Currently configured and tested on **Flutter Web** and **Windows Desktop**; portable to Android/iOS.
- **State Management:** Provider pattern via `InheritedNotifier` / `ChangeNotifier` (`AppState` in `apps/mobile/lib/app_state.dart`).
- **Cryptographic Engine:** `pointycastle: ^4.0.0` (Fortuna PRNG, ECDSA P-256 / SHA-256 signing) and `asn1lib: ^1.6.5` (SPKI DER encoding).
- **QR Generation & Scanning:** `qr_flutter: ^4.1.0` (rendering student QR) and `mobile_scanner: ^7.4.2` (camera scanner).
- **Authentication:** `firebase_auth: ^6.1.2`, `firebase_core: ^4.2.1`.
- **HTTP Client:** `http: ^1.6.0`.

### Backend (`apps/api`)
- **Framework:** NestJS 10.4.15 on Node.js (TypeScript 5.7.2).
- **ORM & Database:** Prisma ORM 6.2.1 targeting PostgreSQL 16 (Alpine).
- **Token Security & Auth:** `@nestjs/jwt: ^10.2.0`, Node.js native `crypto` module (for ECDSA DER signature verification and SHA-256 audit chaining), `firebase-admin: ^13.4.0`.
- **Scheduled Workers:** `@nestjs/schedule: ^4.1.2` (cron engine for pass expiry and overdue tracking).
- **Validation:** `class-validator: ^0.14.1`, `class-transformer: ^0.5.1`.
- **Static Hosting:** `@nestjs/serve-static: ^4.0.2` (configured to serve the compiled Flutter web artifacts from `/public`).

---

## 3. FOLDER STRUCTURE

```
College-app/
├── README.md                      # Primary project overview, run instructions & seeded user table
├── ONBOARDING.md                  # Comprehensive senior engineering onboarding manual (this file)
├── docker-compose.yml             # PostgreSQL 16 container definition on host port 5433
├── docs/                          # Product specification & architectural decision logs
│   ├── PRD.md                     # Product Requirements Document summary (CCE MVP requirements & trace IDs)
│   └── decisions.md               # 12 core engineering architectural decisions (crypto, ports, transitions)
├── apps/
│   ├── api/                       # NestJS REST backend service & static asset host
│   │   ├── .env.example           # Environment template (PostgreSQL, JWT, Firebase Admin credentials)
│   │   ├── nest-cli.json          # Nest CLI build configuration
│   │   ├── package.json           # Node.js dependencies, build & test scripts
│   │   ├── tsconfig.json          # TypeScript compiler options
│   │   ├── prisma/
│   │   │   ├── schema.prisma      # Prisma schema (User, Student, OutpassRequest, Approval, GateEvent, AuditLog)
│   │   │   └── seed.ts            # Database seed script for system administrator, default gate & settings
│   │   ├── scripts/
│   │   │   └── daemon.cjs         # Background daemon runner script for Node.js API process
│   │   ├── src/
│   │   │   ├── main.ts            # Backend application bootstrap entrypoint (port 3000, /v1 prefix)
│   │   │   ├── app.module.ts      # Root NestJS module wiring modules, config, and static web provider
│   │   │   ├── prisma.service.ts  # Prisma database client lifecycle manager
│   │   │   ├── audit/             # Tamper-evident hash-chained audit logging service
│   │   │   ├── auth/              # JWT issuance, Firebase ID token verification, and device registration
│   │   │   ├── common/            # Shared auth decorators, JWT guards, and RBAC role guards
│   │   │   ├── gate/              # Gate scan processing, idempotency, and ECDSA QR verification
│   │   │   ├── jobs/              # Minute-interval cron worker handling outpass expiration & overdue states
│   │   │   ├── notifications/     # In-app notification creation and query service
│   │   │   └── outpass/           # Core outpass lifecycle, approval transitions, and student queries
│   │   └── test/                  # End-to-end Jest test suites covering race conditions and gate scans
│   └── mobile/                    # Flutter cross-platform client application
│       ├── pubspec.yaml           # Flutter package manifest and dependency versions
│       ├── analysis_options.yaml  # Dart analyzer lint configuration
│       ├── web/                   # Web platform entrypoint (index.html, manifest.json)
│       ├── windows/               # Windows desktop native C++ runner and build scripts
│       ├── android/               # Android native Gradle project configuration
│       ├── ios/                   # iOS native Xcode project configuration
│       ├── lib/
│       │   ├── main.dart          # Flutter UI entry point (`main()`), role router & demo switcher widget
│       │   ├── app_state.dart     # Global session state, auth lifecycle, and key generator holder
│       │   ├── api_client.dart    # HTTP client talking to /v1 endpoints with mock backend toggling
│       │   ├── mock_backend.dart  # In-memory mock server simulating DB and rules for instant demo
│       │   ├── qr_token.dart      # PointyCastle ECDSA P-256 keygen and DER token generator
│       │   ├── login_screen.dart  # Phone authentication screen with 1-click demo role chips
│       │   ├── student_screen.dart# Student request form, active status card, history, and rotating QR dialog
│       │   ├── approver_screen.dart# Tutor / HOD pending approval queue and rejection reason dialog
│       │   └── guard_screen.dart  # Gate scanner screen with camera viewfinder, shift log & color alert dialogs
│       └── test/
│           ├── mock_lifecycle_test.dart # Full unit test asserting the student->tutor->HOD->guard loop in mock mode
│           ├── demo_cycle.dart          # Real-time polling live integration tester
│           └── e2e_live.dart            # Live integration test verifying Dart crypto against live NestJS server
```

### Entry Points
- **Backend Entry Point:** [`apps/api/src/main.ts`](file:///c:/Users/SAYOOJ%20A%20R/Desktop/College-app/apps/api/src/main.ts) initializes NestJS, sets global `/v1` prefix, applies validation pipes, enables CORS, and listens on port 3000.
- **Frontend Entry Point:** [`apps/mobile/lib/main.dart`](file:///c:/Users/SAYOOJ%20A%20R/Desktop/College-app/apps/mobile/lib/main.dart) reads compile-time Firebase definitions, initializes `AppState`, and evaluates `RootRouter` based on user authentication state.

---

## 4. ARCHITECTURE AND DATA FLOW

### Screen, Logic & Data Connectivity
1. **Authentication:** The user logs in via Phone + OTP (or 1-click demo button).
2. **Device Registration:** Upon authentication, the client generates an in-memory ECDSA P-256 keypair (`DeviceKeys.generate()`) and uploads the public key PEM to `POST /v1/auth/device/register`.
3. **Outpass Lifecycle:**
   - Student creates an outpass request (`POST /v1/outpasses`).
   - Request enters `PENDING_TUTOR`.
   - Assigned Tutor reviews and approves (`POST /v1/approvals/:id/decision`). Status moves to `PENDING_HOD`.
   - Department HOD reviews and approves. Status moves to `APPROVED`, setting valid time windows (`validFrom` / `validUntil`).
4. **QR Generation & Presentation:**
   - The student opens `QrScreen`. Every second, the app checks if `DeviceKeys.currentStep()` (30s window) has changed.
   - It signs `v1.<outpassId>.<ts>` using its private key and encodes the DER signature into `v1.<outpassId>.<ts>.<signature>`.
5. **Gate Verification:**
   - Security Guard at `GuardHome` points camera or pastes token into `POST /v1/gate/scans`.
   - NestJS verifies signature against student's registered public key, ensures timestamp is within ±75s, verifies atomic status, and checks 10-minute minimum dwell time before return entry.

### Architecture Diagram (Mermaid)

```mermaid
graph TD
    subgraph Client ["Flutter Mobile / Web App (apps/mobile)"]
        UI_Login["Login Screen (Phone + Server OTP)"]
        UI_Admin["Admin Console (CRUD, Depts, Monitor, Settings)"]
        UI_Student["Student Home & Request Form"]
        UI_QR["Rotating QR Screen (PointyCastle P-256)"]
        UI_Approver["Tutor / HOD Approval Screen"]
        UI_Guard["Guard Scanner (MobileScanner)"]
        AppState["AppState (ChangeNotifier)"]
        ApiClient["ApiClient (HTTP client)"]
    end

    subgraph Server ["NestJS API Server (apps/api)"]
        AuthController["Auth Controller (/v1/auth)"]
        AdminController["Admin Controller (/v1/admin)"]
        OutpassController["Outpass Controller (/v1/outpasses)"]
        ApprovalController["Approvals Controller (/v1/approvals)"]
        GateController["Gate Controller (/v1/gate)"]
        TokenVerifier["ECDSA Token Verifier (crypto.verify)"]
        ExpiryJob["Expiry & Overdue Cron (Every 1m)"]
        AuditService["Hash-Chained Audit Service"]
    end

    subgraph Storage ["Database & External Services"]
        PG[(PostgreSQL 16 - Port 5433)]
        Firebase["Firebase Auth (Phone Provider)"]
    end

    %% Connections
    UI_Login --> AppState
    UI_Admin --> AppState
    UI_Student --> AppState
    UI_QR --> AppState
    UI_Approver --> AppState
    UI_Guard --> AppState

    AppState --> ApiClient
    ApiClient -->|REST API calls| Server

    AuthController -->|Verify ID Token| Firebase
    AuthController --> PG
    OutpassController --> PG
    ApprovalController --> PG
    GateController --> TokenVerifier
    GateController --> PG
    GateController --> AuditService
    ExpiryJob --> PG
    AuditService --> PG
```

---

## 5. HARDCODING AUDIT

Below is the comprehensive audit across configuration, source, seed, and test files:

| File Path | Line # | Hardcoded Value | Category | Risk Level | Recommended Fix |
| :--- | :---: | :--- | :--- | :---: | :--- |
| `apps/api/.env.example` | 1 | `post****` (password `outpass`) | Secrets & credentials | **Medium** | Ensure real production connection strings are loaded via vault or deployment environment variables. |
| `apps/api/.env.example` | 2 | `chan****` (`change-me`) | Secrets & credentials | **High** | Default JWT secret in example file; enforce minimum entropy check on startup in production. |
| `apps/api/test/env.js` | 3 | `post****` (`outpass:outpass`) | Secrets & credentials | **Low** | Test DB connection string; isolate to test configuration. |
| `apps/api/test/env.js` | 5 | `test****` (`test-secret`) | Secrets & credentials | **Low** | Test JWT secret. Fallback should be strictly scoped to test runner. |
| `apps/mobile/lib/api_client.dart` | 22 | `http://localhost:3000/v1` | URLs & endpoints | **Medium** | Extract default API base URL to a compile-time `--dart-define=API_BASE_URL` or configuration class. |
| `apps/mobile/test/demo_cycle.dart` | 63 | `http://localhost:3000/v1` | URLs & endpoints | **Low** | CLI argument or `Platform.environment['API_BASE_URL']`. |
| `apps/mobile/test/e2e_live.dart` | 51 | `http://localhost:3000/v1` | URLs & endpoints | **Low** | Move to environment variable. |
| `apps/api/src/main.ts` | 11 | `3000` | URLs & endpoints | **Low** | Defaults port to 3000; already configurable via `process.env.PORT`. |
| `apps/api/scripts/daemon.cjs` | 7 | `/tmp/api.log` | File paths / OS-specific | **Medium** | Linux/macOS specific path. Fails or writes inappropriately on Windows environments. Use `path.join(os.tmpdir(), 'api.log')`. |
| `apps/mobile/lib/mock_backend.dart` | Deleted | - | Removed | **Resolved** | Mock backend completely deleted. Client connects solely to real NestJS API. |
| `apps/mobile/lib/login_screen.dart` | Refactored | `TEMP_OTP_ENABLED` | Auth config | **Resolved** | Demo buttons removed. Login always requires phone and server-verified OTP. |
| `apps/mobile/lib/main.dart` | Refactored | Unified AppTheme | UI styling | **Resolved** | Styled via unified `AppTheme` design tokens. |
| `apps/mobile/lib/login_screen.dart` | 170 | `'Christ College of Engineering, Irinjalakuda'` | College-specific value | **Low** | Hardcoded institution name. Move to app configuration / branding constant. |
| `apps/mobile/lib/student_screen.dart` | 258 | `['Medical', 'Family', 'Official', 'Home visit', 'Other']` | Business logic values | **Medium** | Fixed list of outpass categories. Move to database or configurable backend dictionary. |
| `apps/api/src/gate/gate.service.ts` | 9 | `10 * 60 * 1000` (10 mins) | Business logic values | **Medium** | Minimum dwell time between exit and return. Extract to a configurable policy setting. |
| `apps/api/src/jobs/expiry.service.ts` | 6 | `15 * 60 * 1000` (15 mins) | Business logic values | **Medium** | Grace period before an overdue pass is flagged. Extract to configuration. |
| `apps/api/src/gate/token-verify.ts` | 3 | `75` (seconds) | Business logic values | **Low** | QR acceptance window (2.5 time steps). Recommended to keep in sync with client step via constants. |
| `apps/mobile/lib/guard_screen.dart` | 21 | `'main-gate'` | College-specific value | **Low** | Default gate ID. Move to a dropdown populated by `GET /v1/gates`. |

---

### Refactoring Plan for Hardcoded Values

1. **Environment Variables (`.env`):**
   - Backend database connection string (`DATABASE_URL`).
   - JWT secret and expiration durations (`JWT_SECRET`, `JWT_EXPIRES_IN`).
   - Firebase Admin service account key & project ID.
   - Flutter backend endpoint base URL (`API_BASE_URL`).
2. **App Configuration (`app_config.dart` / NestJS Config):**
   - College branding strings (`College Name`, `Campus Gates`, `Default Fallback Gate`).
   - Business parameters: Minimum return dwell time (`DWELL_TIME_MINUTES`), overdue grace duration (`OVERDUE_GRACE_MINUTES`), token rotation frequency (`TOKEN_STEP_SECONDS`).
3. **UI Theme System (`theme.dart`):**
   - Institutional colors (`Color(0xFF1B5E20)`), status badges colors, card radii, and fonts.
4. **Database-Driven Entities:**
   - Outpass categories (currently hardcoded as `Medical`, `Family`, etc.) should be manageable via an admin table.
   - Active gate names and locations.

### Suggested `.env.example` Files

#### `apps/api/.env.example`
```bash
# Server Configuration
PORT=3000
NODE_ENV=development

# Database Connection
DATABASE_URL=postgresql://outpass:outpass@localhost:5433/outpass?schema=public

# Security Tokens
JWT_SECRET=
JWT_EXPIRES_IN=15m

# Business Logic Policy
MIN_DWELL_MINUTES=10
OVERDUE_GRACE_MINUTES=15
QR_ACCEPT_WINDOW_SECONDS=75

# Firebase Service Account (Phone Authentication)
FIREBASE_PROJECT_ID=
FIREBASE_SERVICE_ACCOUNT_JSON=
```

#### `apps/mobile/.env.example`
```bash
# Backend Target
API_BASE_URL=http://localhost:3000/v1
IS_DEMO_MODE=false

# Firebase Web / Mobile Client Credentials
FIREBASE_API_KEY=
FIREBASE_APP_ID=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_PROJECT_ID=
FIREBASE_AUTH_DOMAIN=
```

### Git History Secret Check
- **Scan Result:** Checked git history (`fc296ad Initial import of CCE Outpass app`).
- **Findings:** No live production credentials or private keys were committed. The `.env.example` file contains placeholder `change-me` strings and dummy private key mock structures.
- **Action Required:** When creating your production Firebase service account, ensure `FIREBASE_SERVICE_ACCOUNT_JSON` is **never committed** to git and remains in `.gitignore`.

---

## 6. HOW TO RUN IT

### Prerequisites
1. **Flutter SDK:** Version 3.29.x / 3.30+ installed and on `PATH`.
2. **Node.js:** v18+ or v20+ and `npm`.
3. **Chrome:** For running Flutter Web.
4. **PostgreSQL 16:** (Optional if running in in-memory demo mode; required for live backend).

---

### Running the Real Application Stack

The application has zero mock backend and connects exclusively to the real NestJS API with PostgreSQL via Prisma.

#### 1. Start PostgreSQL with Docker
From the project root:
```powershell
docker compose up -d db
```
*(PostgreSQL 16 starts on host port `5433` with database `outpass`, user `outpass`, password `outpass`)*

#### 2. Run Database Migrations and Seed Admin User
```powershell
cd "apps/api"
npm install

# Run database migrations
npx prisma migrate deploy

# Seed initial database (creates ONLY the admin user, default gate, and default settings)
npx prisma db seed
```
*(Default admin phone is `8921578838`, or whatever is specified in `ADMIN_PHONE` environment variable).*

#### 3. Start the NestJS API
```powershell
# From apps/api:
npm run start:dev
```
*(API will be running at `http://localhost:3000/v1` with CORS enabled for Flutter web clients).*

#### 4. Start the Flutter Mobile / Web App
In a separate terminal:
```powershell
cd "apps/mobile"
flutter pub get

# Run on Chrome Web:
flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3000/v1

# Or run as Windows desktop application:
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000/v1
```

---

### Academic Structure & Role Registration Architecture

#### 1. Academic Hierarchy in Database
- **Departments:** Stored in the `Department` model (`CSE`, `CSDS`, `CSBS`, `EC`, `EEE`, `ME`, `CE`, `VLSI`).
- **Divisions:** Dynamic per-department model (`Division` with `departmentId`, `code`, `name`). CSE is initialized with divisions `A`, `B`, `C`, `D`. Other departments initially have no divisions. Divisions can be added or deleted by the Admin from the **Departments** tab.
- **Years:** Stored as integers `1` to `4` (displayed as `1st Year`, `2nd Year`, `3rd Year`, `4th Year`).
- **Idempotency:** `prisma/seed.ts` creates departments, divisions, and default admin without duplicating existing records.
- **Integrity Constraints:**
  - Deleting a department that has associated people is strictly blocked (HTTP 400).
  - Deleting a division assigned to active students or tutors is strictly blocked (HTTP 400).

#### 2. Role-Specific Registration Rules
- **STUDENT:** Name, Phone (10 digits), Department, Year (1-4), Division (visible and required ONLY if the department has divisions), Assigned Tutor (filtered to tutors of the exact same Department, Year, and Division).
- **TUTOR:** Name, Phone (10 digits), Department, Year (1-4), Division (only if the department has divisions).
- **HOD:** Name, Phone (10 digits), Department only. Strictly one active HOD per department. If an active HOD exists, the admin is warned (`"<Dept> already has a HOD: <Name>"`) and given the option to replace them.
- **SECURITY GUARD:** Name, Phone (10 digits) only.
- **ADMIN:** Name, Phone (10 digits) only.
- **Editing Persons:** All fields are editable, including role. Changing roles automatically clears inapplicable fields.
- **Dependent Dropdowns:** Changing Department resets Division and Tutor; Division dropdown displays only divisions belonging to that department.
- **Button State:** "Register Person" / "Save Changes" is disabled until all required fields for the selected role are valid.

#### 3. Phone Number Normalization Standard
- **Format:** Strict 10-digit numeric string across all screens and services.
- **Rule:** Strips leading `+91`, `91`, parentheses, dashes, and whitespace (`normalizeMobilePhone` in Flutter, `normalizeMobile` in NestJS).
- **Uniqueness:** Phone numbers must be globally unique across all roles in the system.
- **Login Compatibility:** Any phone registered by the Admin logs in with `TEMP_OTP = 123456` and routes directly to the correct role dashboard without fallback to Student.

#### 4. Root Cause of Earlier "Saving..." Bug & Resolution
- **Root Cause:**
  1. The `_save()` async method in `_PersonFormDialog` lacked a `finally` block to reset `_busy = false`, leaving the button in a permanent loading spinner whenever the server returned an error.
  2. HTTP requests did not have a timeout, so dropped connections or network lag caused the modal to freeze indefinitely.
  3. The dialog was not dismissed prior to triggering the parent list reload, causing race conditions in UI state.
  4. Stateful widgets (`AdminHome` and `GuardHome`) invoked async InheritedWidget methods directly inside `initState()` before the element was mounted, triggering Flutter framework assertion errors.
- **Resolution:**
  - Added a 15-second timeout (`.timeout(const Duration(seconds: 15))`) with proper `try / catch / finally` resetting `_busy = false`.
  - Caught errors and surfaced the backend's explicit error message in a SnackBar.
  - Closed the dialog immediately on success (`Navigator.of(context).pop(true)`) and refreshed the list in the parent widget.
  - Deferred initial API calls in `initState()` via `WidgetsBinding.instance.addPostFrameCallback`.

---

### Step-by-Step Testing Guide: Role Allotment & Full Lifecycle

The app always begins at the Login screen. No auto-login or role switching without signing in.

#### Step 1: Admin Setup & Academic Management
1. Open the app (`http://localhost:8080`).
2. Log in with the seeded administrator phone:
   - Mobile: `8921578838`
   - Enter OTP: `123456`
   - Click **Verify & Sign In** -> Admin Console opens.
3. In the **Departments** tab:
   - Verify seeded departments: `CSE`, `CSDS`, `CSBS`, `EC`, `EEE`, `ME`, `CE`, `VLSI`.
   - Verify CSE displays divisions `A`, `B`, `C`, `D`.
   - Test adding a new division (e.g. click `+ Add Division` on `EC` and add `A`).
4. In the **People** tab:
   - Click **Add Person** to create a **Tutor**:
     * Name: `Dr. Anand Kumar`, Phone: `9000000001`, Role: `Tutor`, Dept: `CSE`, Year: `3rd Year`, Division: `A`.
   - Click **Add Person** to create an **HOD**:
     * Name: `Dr. Priya Menon`, Phone: `9000000002`, Role: `HOD`, Dept: `CSE`.
   - Click **Add Person** to create a **Security Guard**:
     * Name: `Suresh Guard`, Phone: `9000000090`, Role: `Security Guard`.
   - Click **Add Person** to create a **Student**:
     * Name: `Ananya S`, Phone: `9074121510`, Role: `Student`, Dept: `CSE`, Year: `3rd Year`, Division: `A`, Assigned Tutor: `Dr. Anand Kumar`.
5. *(HOD Uniqueness Test)* Try registering a second HOD for `CSE` -> System warns that `CSE already has a HOD: Dr. Priya Menon`.
6. Click the logout icon in the top right to sign out.

#### Step 2: Student Creates an Outpass Request
1. Enter Student mobile: `9074121510`, OTP: `123456`.
2. Student Dashboard opens automatically.
3. Click **+ Request Outpass**:
   - Destination: `Medical Clinic`
   - Purpose Category: `Medical`
   - Reason: `Dentist appointment`
   - Set Exit time and Expected return time.
4. Click **Submit Outpass Request**.
5. Status displays as **Pending Tutor Approval**.
6. Log out.

#### Step 3: Tutor Approves Request
1. Enter Tutor mobile: `9000000001`, OTP: `123456`.
2. Faculty Approvals dashboard opens showing Ananya's pending request.
3. Tap the request card and click **Approve Request**.
4. Request advances to **Pending HOD Approval**.
5. Log out.

#### Step 4: HOD Approves Request
1. Enter HOD mobile: `9000000002`, OTP: `123456`.
2. HOD Approvals dashboard opens showing the request.
3. Tap the request card and click **Approve Request**.
4. Status becomes **Approved**.
5. Log out.

#### Step 5: Student Views Hero QR Code
1. Log in as Student (`9074121510`, OTP `123456`).
2. The approved outpass now displays the dynamic rotating QR Code with animated countdown ring (refreshes every 15 seconds) and token string.
3. Keep the token or click copy icon for guard check.
4. Log out.

#### Step 6: Security Guard Scans Exit & Entry
1. Enter Guard mobile: `9000000090`, OTP: `123456`.
2. Security Gate Console opens.
3. Select **Exit Scan** -> Scan camera QR or paste token into fallback field -> Click **Verify Token**.
4. Gate grants **ALLOW EXIT (Green)**. Pass status becomes **EXITED**.
5. For return scan: select **Entry Scan** -> verify token after minimum dwell period -> Gate grants **ALLOW ENTRY (Green)**. Pass status becomes **RETURNED**.
6. In Admin Console (**Monitor** tab), view the full status and gate events.

## 7. OTHER PROBLEMS FOUND & RANKED BY PRIORITY

| Priority | Issue Description | Location | Details & Impact |
| :---: | :--- | :--- | :--- |
| **P1 (High)** | **Software-only Device Keys** | `apps/mobile/lib/qr_token.dart` | Keypairs are generated in volatile memory via PointyCastle. Logging out or clearing browser storage regenerates keys, requiring re-registration. In production mobile apps, this must use Android Keystore / iOS Secure Enclave. |
| **P1 (High)** | **Windows / OS Incompatibility in Scripts** | `apps/api/scripts/daemon.cjs` | Uses `/tmp/api.log` hardcoded Unix path. Fails on native Windows unless run in WSL/Git Bash. |
| **P2 (Medium)** | **HTTP Polling Instead of WebSockets/Push** | `student_screen.dart`, `approver_screen.dart` | Screens use `Timer.periodic(const Duration(seconds: 4))` to poll the server for state updates. High network overhead and battery consumption on mobile. |
| **P2 (Medium)** | **Missing Rollback on Partial Device Key Failure** | `apps/mobile/lib/app_state.dart` | `loginDemoMobile` swallows exceptions on `registerDevice` (`catch (_) {}`). If the device registration fails, QR scans at the gate will fail cryptographically without clear warning to the user. |
| **P2 (Medium)** | **No Admin / Configuration UI** | Global | Tutors, HODs, student mappings, and gate names cannot be created or reassigned dynamically without direct SQL/Prisma operations. |
| **P3 (Low)** | **Noto Font Missing Glyphs Warning on Web** | Web canvas rendering | Flutter Web produces console warnings regarding Noto fonts for symbols/emojis. Needs Google Fonts or local font assets in `pubspec.yaml`. |
| **P3 (Low)** | **Missing Lint Cleanups** | `apps/mobile` | `analysis_options.yaml` has some unused import or pedantic warnings pending resolution. |

---

## 8. NEXT STEPS & ROADMAP

### Immediate Tasks (Week 1)
1. **Extract Configurations & Clear Hardcoded Values:**
   - Create an `AppConfig` class in Flutter to hold `apiBaseUrl`, `collegeName`, and feature flags.
   - Remove demo OTP bypass from release compilation targets (`assert(!kReleaseMode)`).
2. **Add Native Secure Storage for Device Keys:**
   - Integrate `flutter_secure_storage` so private keys persist across app launches rather than regenerating on every login.
3. **Fix Cross-Platform Daemon & Setup Scripts:**
   - Update `scripts/daemon.cjs` to resolve log paths dynamically via `os.tmpdir()`.

### Medium-Term Tasks (Weeks 2–3)
4. **Implement Real-time Updates (Push / WebSockets):**
   - Replace the 4-second HTTP polling loop with Server-Sent Events (SSE) or WebSockets in NestJS for instant approval notifications.
   - Configure Firebase Cloud Messaging (FCM) background handler for mobile notification trays.
5. **Build Administrative Management Interface:**
   - Create an Admin module in NestJS to manage students, assign tutors to specific classes, and view real-time gate pass logs.

### Long-Term Tasks (Production Readiness)
6. **Hardware Key Attestation:**
   - Connect hardware-backed security keys with Android Play Integrity / Apple App Attest before campus-wide production rollout.
7. **Offline Guard Sync:**
   - Add local SQLite / IndexedDB cache to the guard app with signed public key bundles to permit gate verification during Wi-Fi outages.

---

## QUESTIONS FOR YOU
To help tailor our upcoming development steps, please let me know:
1. **Deployment Target:** Are you prioritizing deploying this as a **PWA / Web app** for college phones, or do you plan to build and publish **native Android APKs / iOS apps**?
2. **SMS Gateway:** Do you have a live Firebase project with Blaze/SMS billing enabled, or should we continue enhancing the local mock backend for your immediate demonstrations?
3. **Database Setup:** Would you like help setting up a local Docker/PostgreSQL instance on your machine, or do you prefer using a hosted PostgreSQL provider (like Supabase or Neon)?
