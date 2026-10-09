# CCE Outpass — Comprehensive Project Onboarding Report

> **Prepared by:** Senior Software Engineering Advisor  
> **Workspace:** `College-app` (Christ College of Engineering, Irinjalakuda — Outpass System)  
> **Status:** MVP Core Loop Implemented with In-Memory Demo Mode & Full NestJS/PostgreSQL Backend

---

## 1. PROJECT OVERVIEW

### What the App Does & Who It's For
**CCE Outpass** is a digital campus egress and entry security system purpose-built for **Christ College of Engineering (CCE), Irinjalakuda**. It replaces physical paper pass books with a tamper-resistant, multi-tier approval workflow backed by cryptographically signed, rotating QR codes.

The system serves 4 distinct user groups:
1. **Students:** Apply for normal or emergency outpasses, track approvals in real time, view rotating cryptographic QR codes to present at physical campus gates, and cancel requests prior to exit.
2. **Faculty / Tutors:** Review and approve/reject outpass requests submitted by their assigned batch students (with mandatory rejection reasons).
3. **Department Heads (HODs):** Secondary institutional approval tier for department students; granting final approval activates the student's dynamic QR gate token.
4. **Campus Security Guards:** Gatekeepers stationed at physical checkpoints who scan student QR codes (or enter manual tokens as fallback) in either `EXIT` or `ENTRY` directions, receiving immediate visual color feedback (green allow / red deny), automatic double-use prevention, and 10-minute return dwell enforcement.

---

### Feature Completeness Analysis

| Feature Area | Status | Evidence in Codebase | Notes / Missing Items |
| :--- | :---: | :--- | :--- |
| **Student Outpass Creation** | ✅ Finished | `apps/mobile/lib/student_screen.dart` (`RequestFormScreen`), `apps/api/src/outpass/outpass.service.ts` | Start/end datetime pickers, purpose categories, emergency flag, validation against overlaps. |
| **Tutor & HOD Approvals** | ✅ Finished | `approver_screen.dart`, `approvals.controller.ts`, `outpass.service.ts` | Sequential state transitions (`PENDING_TUTOR` -> `PENDING_HOD` -> `APPROVED`), mandatory rejection comments. |
| **Rotating Dynamic QR Code** | ✅ Finished | `qr_token.dart`, `apps/api/src/gate/token-verify.ts` | ECDSA P-256 / SHA-256 signature generated on a 30s step with ±75s validity window. |
| **Guard Gate Verification** | ✅ Finished | `guard_screen.dart`, `apps/api/src/gate/gate.service.ts` | Camera scanning via `mobile_scanner`, manual entry fallback, single-use check, min 10-min dwell check. |
| **Audit Logging** | ✅ Finished | `apps/api/src/audit/audit.service.ts` | Append-only SHA-256 hash-chained audit ledger (`AuditLog` table). |
| **Expiry & Overdue Automation** | ✅ Finished | `apps/api/src/jobs/expiry.service.ts` | Background cron job runs every minute, marking unused passes `EXPIRED` and unreturned students `OVERDUE` (+15 min grace). |
| **In-Memory Demo / Mock Mode** | ✅ Finished | `apps/mobile/lib/mock_backend.dart` | Standalone UI runner without requiring PostgreSQL or Firebase SMS setup. |
| **Push Notifications (FCM / APNS)** | 🟡 Half-done / Stubbed | `apps/api/src/notifications/notifications.service.ts` | Inserts rows into the DB `Notification` table; actual Firebase Cloud Messaging push dispatch is deferred. |
| **SMS OTP Verification** | 🟡 Half-done | `login_screen.dart`, `firebase-auth.service.ts` | Uses Firebase Phone Auth SDK; mock mode uses bypass OTP `123456` or one-tap demo account buttons. |
| **Device Hardware Attestation** | 🔴 Missing / Cut | `docs/decisions.md` (Decision #3), `apps/mobile/lib/qr_token.dart` | Software keys generated via `pointycastle`; hardware Secure Enclave / Android Keystore & Play Integrity are deferred. |
| **Admin Dashboard** | 🔴 Missing / Deferred | PRD §Explicit MVP cuts | No UI for college admins to manage user imports, tutor assignments, or gate definitions. |
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
│   │   │   └── seed.ts            # Database seed script for tutor, HOD, guard & demo students
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
        UI_Login["Login Screen / Demo Chips"]
        UI_Student["Student Home & Request Form"]
        UI_QR["Rotating QR Screen (PointyCastle P-256)"]
        UI_Approver["Tutor / HOD Approval Screen"]
        UI_Guard["Guard Scanner (MobileScanner)"]
        AppState["AppState (ChangeNotifier)"]
        ApiClient["ApiClient (HTTP / Mock Toggle)"]
        MockDB["MockBackend (In-Memory Simulator)"]
    end

    subgraph Server ["NestJS API Server (apps/api)"]
        AuthController["Auth Controller (/v1/auth)"]
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
    UI_Student --> AppState
    UI_QR --> AppState
    UI_Approver --> AppState
    UI_Guard --> AppState

    AppState --> ApiClient
    ApiClient -.->|isDemoMode = true| MockDB
    ApiClient -->|isDemoMode = false| Server

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
| `apps/mobile/lib/mock_backend.dart` | 28 | `9074****` | Fake / dummy data | **Low** | Mock student account. Move seeded test fixtures into a dedicated mock data fixture file. |
| `apps/mobile/lib/mock_backend.dart` | 38, 48 | `9000****` | Fake / dummy data | **Low** | Mock student accounts (`Ananya S`, `Arjun R`). |
| `apps/mobile/lib/mock_backend.dart` | 58, 65 | `9000****` | Fake / dummy data | **Low** | Mock faculty accounts (`Dr. Anand Kumar`, `Dr. Priya Menon`). |
| `apps/mobile/lib/mock_backend.dart` | 72 | `9000****` | Fake / dummy data | **Low** | Mock security guard account (`Suresh`). |
| `apps/api/prisma/seed.ts` | 7, 18, 29 | `9000****` | Fake / dummy data | **Low** | Seed faculty and guard phone numbers in PostgreSQL database. |
| `apps/mobile/lib/login_screen.dart` | 59, 189 | `123456` | Auth shortcut / bypass | **Medium** | Hardcoded OTP bypass for demo mode. Ensure demo mode is explicitly disabled in release builds (`kReleaseMode`). |
| `apps/mobile/lib/login_screen.dart` | 243, 248, 253, 258 | `9074****`, `9000****` | Auth shortcuts / dummy data | **Low** | Quick demo login buttons. Should only be visible if `isDemoMode` is enabled. |
| `apps/mobile/lib/main.dart` | 38 | `Color(0xFF1B5E20)` | UI styling | **Low** | Hardcoded primary brand color. Move to a dedicated `AppTheme` / theme palette definition. |
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

### Path A: Instant Run (Flutter App in Demo Mode — Zero DB Setup)
This is the fastest way to test all screens immediately using the embedded mock backend:

```powershell
# Navigate to mobile app directory
cd "apps/mobile"

# Install Dart/Flutter packages
flutter pub get

# Launch app in Chrome with fixed port
flutter run -d chrome --web-port 8080
```
*Open http://localhost:8080 in your browser. You can click any role chip (Student, Tutor, HOD, Guard) or enter OTP `123456` to walk through the entire loop.*

---

### Path B: Full Stack Run (NestJS API + PostgreSQL + Flutter)

1. **Start PostgreSQL:**
   ```powershell
   # If using Docker:
   docker compose up -d db
   
   # Or using a local PostgreSQL 16 server:
   # Ensure a database named 'outpass' is available on port 5433 (or update .env)
   ```

2. **Initialize & Start API Backend:**
   ```powershell
   cd "apps/api"
   npm install
   
   # Generate Prisma client and migrate database
   npx prisma generate
   npx prisma migrate deploy
   
   # Seed test accounts (Dr. Anand, Dr. Priya, Suresh, students)
   npx prisma db seed
   
   # Run the development server
   npm run start:dev
   ```
   *The backend will be live at `http://localhost:3000/v1`.*

3. **Start Flutter App in Connected Mode:**
   ```powershell
   cd "apps/mobile"
   flutter run -d chrome --web-port 8080 --dart-define=IS_DEMO_MODE=false
   ```

---

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
