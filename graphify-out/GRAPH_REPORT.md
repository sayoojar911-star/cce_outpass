# Graph Report - College-app  (2026-10-09)

## Corpus Check
- 93 files · ~43,906 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 55 file(s) not represented in the graph (top: (none) 8, .xcconfig 8, .xml 7)

## Summary
- 1022 nodes · 1602 edges · 60 communities (39 shown, 21 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 56 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `cf3ce8db`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- auth.decorator.ts
- OutpassService
- GateService
- AppDelegate
- admin_screen.dart
- AuthService
- student_screen.dart
- e2e_live.dart
- my_application.cc
- gate.e2e-spec.ts
- api_client.dart
- app_state.dart
- app_theme.dart
- CCE Outpass — Comprehensive Project Onboarding Report
- login_screen.dart
- qr_token.dart
- package.json
- compilerOptions
- win32_window.cpp
- guard_screen.dart
- NotificationsService
- main.dart
- approver_screen.dart
- dependencies
- State
- devDependencies
- manifest.json
- @nestjs/common
- utils.cpp
- jest
- daemon.cjs
- windows/flutter/generated_plugin_registrant.cc
- nest-cli.json
- device_key_persistence_test.dart
- AdminController
- auth.service.ts
- MainActivity.kt
- CCE Outpass — MVP
- scripts
- CCE Outpass — PRD Summary (MVP scope)
- .MessageHandler
- Win32Window
- cce_outpass
- LaunchImage.imageset/README.md
- decisions.md
- @prisma/client
- StatelessWidget
- .MessageHandler
- FlutterWindow
- Point
- AppState
- main.ts
- ApiException
- FakeSecureStorage

## God Nodes (most connected - your core abstractions)
1. `@nestjs/common` - 29 edges
2. `PrismaService` - 26 edges
3. `AdminController` - 22 edges
4. `Win32Window` - 21 edges
5. `OutpassService` - 20 edges
6. `compilerOptions` - 18 edges
7. `AuthService` - 17 edges
8. `Auth()` - 17 edges
9. `AuditService` - 16 edges
10. `AuthUser` - 15 edges

## Surprising Connections (you probably didn't know these)
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  apps/mobile/windows/runner/main.cpp → apps/mobile/windows/runner/utils.cpp
- `AdminController` --references--> `Auth()`  [EXTRACTED]
  apps/api/src/admin/admin.controller.ts → apps/api/src/common/auth.decorator.ts
- `GateController` --references--> `Auth()`  [EXTRACTED]
  apps/api/src/gate/gate.controller.ts → apps/api/src/common/auth.decorator.ts
- `NotificationsController` --references--> `Auth()`  [EXTRACTED]
  apps/api/src/notifications/notifications.controller.ts → apps/api/src/common/auth.decorator.ts
- `my_application_activate()` --calls--> `fl_register_plugins()`  [INFERRED]
  apps/mobile/linux/runner/my_application.cc → apps/mobile/linux/flutter/generated_plugin_registrant.cc

## Import Cycles
- None detected.

## Communities (60 total, 21 thin omitted)

### Community 0 - "auth.decorator.ts"
Cohesion: 0.18
Nodes (6): Roles(), ROLES_KEY, JwtAuthGuard, RolesGuard, @nestjs/core, @nestjs/jwt

### Community 1 - "OutpassService"
Cohesion: 0.07
Nodes (9): Auth(), AuthUser, ExpiryService, ApprovalsController, CancelDto, CreateOutpassDto, DecisionDto, OutpassController (+1 more)

### Community 2 - "GateService"
Cohesion: 0.08
Nodes (13): ScanDto, StartShiftDto, GateController, GateService, ACCEPT_WINDOW_SECONDS, checkWindow(), ParsedToken, parseQrToken() (+5 more)

### Community 3 - "AppDelegate"
Cohesion: 0.06
Nodes (15): AppDelegate, SceneDelegate, RunnerTests, RegisterGeneratedPlugins(), AppDelegate, MainFlutterWindow, RunnerTests, Cocoa (+7 more)

### Community 4 - "admin_screen.dart"
Cohesion: 0.03
Nodes (61): allUsers, _auditLogs, build, _buildRoleList, _busy, _cancelPass, _catCtrl, _collegeCtrl (+53 more)

### Community 5 - "AuthService"
Cohesion: 0.11
Nodes (10): AuthController, AuthService, sha256(), FirebaseTokenDto, normalizeMobile(), RefreshDto, RegisterDeviceDto, SendOtpDto (+2 more)

### Community 6 - "student_screen.dart"
Cohesion: 0.06
Nodes (33): build, _buildCurrentPassView, _buildHistoryView, _busy, createState, _destination, dispose, _error (+25 more)

### Community 7 - "e2e_live.dart"
Cohesion: 0.06
Nodes (30): apiBase, call, check, created, exitRes, guard, guardTok, hod (+22 more)

### Community 8 - "my_application.cc"
Cohesion: 0.08
Nodes (14): fl_register_plugins(), main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line() (+6 more)

### Community 9 - "gate.e2e-spec.ts"
Cohesion: 0.24
Nodes (11): test, AppModule, T, login(), newKeyPair(), signToken(), useTestFirebaseAuth(), uuid() (+3 more)

### Community 10 - "api_client.dart"
Cohesion: 0.05
Nodes (41): accessToken, adminAddOrUpdateDepartment, adminAddUser, adminAssignTutors, adminBulkAddUsers, adminCancelOutpass, adminDeleteDepartment, adminDeleteUser (+33 more)

### Community 11 - "app_state.dart"
Cohesion: 0.07
Nodes (24): ApiClient, api, deviceKeys, isAdmin, isGuard, isHod, isStudent, isTutor (+16 more)

### Community 12 - "app_theme.dart"
Cohesion: 0.04
Nodes (40): action, adminAccent, AppTheme, borderLight, build, cardBg, cardPadding, guardAccent (+32 more)

### Community 13 - "CCE Outpass — Comprehensive Project Onboarding Report"
Cohesion: 0.05
Nodes (38): 1. PROJECT OVERVIEW, 1. Start PostgreSQL with Docker, 2. Run Database Migrations and Seed Admin User, 2. TECH STACK, 3. FOLDER STRUCTURE, 3. Start the NestJS API, 4. ARCHITECTURE AND DATA FLOW, 4. Start the Flutter Mobile / Web App (+30 more)

### Community 14 - "login_screen.dart"
Cohesion: 0.13
Nodes (13): build, _busy, _code, createState, _error, LoginScreen, _LoginScreenState, _mobile (+5 more)

### Community 15 - "qr_token.dart"
Cohesion: 0.08
Nodes (15): _bigIntTo32Bytes, buildToken, _bytesToBigInt, currentStep, DeviceKeys, fromPrivateKeyPem, generate, kTokenStepSeconds (+7 more)

### Community 16 - "package.json"
Cohesion: 0.10
Nodes (20): name, prisma, seed, private, version, class-transformer, firebase-admin, jest (+12 more)

### Community 17 - "compilerOptions"
Cohesion: 0.11
Nodes (18): compilerOptions, allowSyntheticDefaultImports, baseUrl, declaration, emitDecoratorMetadata, esModuleInterop, experimentalDecorators, forceConsistentCasingInFileNames (+10 more)

### Community 18 - "win32_window.cpp"
Cohesion: 0.18
Nodes (5): Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, instance_

### Community 19 - "guard_screen.dart"
Cohesion: 0.11
Nodes (18): build, _cameraOn, createState, _Dir, dispose, _gateId, GuardHome, _GuardHomeState (+10 more)

### Community 22 - "approver_screen.dart"
Cohesion: 0.12
Nodes (14): ApproverHome, _ApproverHomeState, _askReason, build, createState, _decide, dispose, _error (+6 more)

### Community 23 - "dependencies"
Cohesion: 0.14
Nodes (14): dependencies, class-transformer, class-validator, firebase-admin, @nestjs/common, @nestjs/config, @nestjs/core, @nestjs/jwt (+6 more)

### Community 24 - "State"
Cohesion: 0.18
Nodes (12): AdminHome, _AdminHomeState, _AdminOutpassMonitorTab, _AdminOutpassMonitorTabState, _AdminPeopleTab, _AdminPeopleTabState, _AdminSettingsTab, _AdminSettingsTabState (+4 more)

### Community 25 - "devDependencies"
Cohesion: 0.15
Nodes (13): devDependencies, jest, @nestjs/cli, @nestjs/testing, prisma, supertest, ts-jest, ts-node (+5 more)

### Community 26 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 27 - "@nestjs/common"
Cohesion: 0.16
Nodes (11): AdminModule, AuditService, GateModule, PENDING, RESULT_MESSAGE, NotificationsModule, OutpassModule, ACTIVE_STATUSES (+3 more)

### Community 28 - "utils.cpp"
Cohesion: 0.12
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 29 - "jest"
Cohesion: 0.22
Nodes (9): jest, collectCoverageFrom, coverageDirectory, moduleFileExtensions, rootDir, testEnvironment, testRegex, transform (+1 more)

### Community 30 - "daemon.cjs"
Cohesion: 0.22
Nodes (5): child, fs, out, path, { spawn }

### Community 32 - "nest-cli.json"
Cohesion: 0.33
Nodes (5): collection, compilerOptions, deleteOutDir, $schema, sourceRoot

### Community 33 - "device_key_persistence_test.dart"
Cohesion: 0.13
Nodes (9): containsKey, _data, delete, main, noSuchMethod, read, throwOnRead, throwOnWrite (+1 more)

### Community 35 - "auth.service.ts"
Cohesion: 0.16
Nodes (4): AuthModule, FirebaseAuthService, TempAuthConfig, @nestjs/config

### Community 37 - "CCE Outpass — MVP"
Cohesion: 0.25
Nodes (7): CCE Outpass — MVP, Initial Admin Account, Layout, Phone sign-in setup, Quick start, Security posture (MVP), Tests

### Community 39 - "scripts"
Cohesion: 0.22
Nodes (9): scripts, build, prisma:deploy, prisma:generate, prisma:migrate, seed, start, start:dev (+1 more)

### Community 45 - "CCE Outpass — PRD Summary (MVP scope)"
Cohesion: 0.33
Nodes (5): CCE Outpass — PRD Summary (MVP scope), Explicit MVP cuts (each maps to a PRD ID for later phases), Lifecycle states implemented (PRD §5.1), MVP core loop, Requirements implemented in this MVP

### Community 47 - "Win32Window"
Cohesion: 0.24
Nodes (4): Win32Window, child_content_, quit_on_close_, window_handle_

### Community 52 - "StatelessWidget"
Cohesion: 0.20
Nodes (9): _AdminAuditTab, _AdminDashboardTab, _AdminDepartmentsTab, _OutpassDetailSheet, _StatCard, CceOutpassApp, RootRouter, EmptyState (+1 more)

### Community 54 - "FlutterWindow"
Cohesion: 0.25
Nodes (3): FlutterWindow, flutter_controller_, project_

### Community 55 - "Point"
Cohesion: 0.21
Nodes (6): Point, x, y, Size, height, width

## Knowledge Gaps
- **312 isolated node(s):** `@nestjs/platform-express`, `rxjs`, `@nestjs/cli`, `@types/express`, `@types/jest` (+307 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 602 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **21 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `@nestjs/common` connect `@nestjs/common` to `auth.decorator.ts`, `OutpassService`, `GateService`, `auth.service.ts`, `AuthService`, `gate.e2e-spec.ts`, `package.json`, `NotificationsService`, `main.ts`?**
  _High betweenness centrality (0.036) - this node is a cross-community bridge._
- **What connects `@nestjs/platform-express`, `rxjs`, `@nestjs/cli` to the rest of the system?**
  _312 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `OutpassService` be split into smaller, more focused modules?**
  _Cohesion score 0.07456140350877193 - nodes in this community are weakly interconnected._
- **Why does `AdminController` connect `AdminController` to `OutpassService`, `@nestjs/common`?**
  _High betweenness centrality (0.023) - this node is a cross-community bridge._
- **Should `GateService` be split into smaller, more focused modules?**
  _Cohesion score 0.08130081300813008 - nodes in this community are weakly interconnected._
- **Why does `Win32Window` connect `Win32Window` to `win32_window.cpp`, `.MessageHandler`, `FlutterWindow`, `Point`, `utils.cpp`?**
  _High betweenness centrality (0.022) - this node is a cross-community bridge._
- **Should `AppDelegate` be split into smaller, more focused modules?**
  _Cohesion score 0.05975609756097561 - nodes in this community are weakly interconnected._