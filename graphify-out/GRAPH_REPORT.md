# Graph Report - College-app  (2026-10-10)

## Corpus Check
- 101 files · ~51,671 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 55 file(s) not represented in the graph (top: (none) 8, .xcconfig 8, .xml 7)

## Summary
- 1123 nodes · 1771 edges · 64 communities (45 shown, 19 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 60 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e67671e8`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- phone_normalization_and_router_test.dart
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
- Auth
- main.dart
- approver_screen.dart
- dependencies
- State
- admin_register_person_test.dart
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
- FlutterWindow
- Win32Window
- cce_outpass
- LaunchImage.imageset/README.md
- decisions.md
- devDependencies
- StatelessWidget
- .MessageHandler
- app.module.ts
- Point
- api-audit.spec.ts
- ApiException
- package:flutter/material.dart
- AppState
- seed.ts
- ApiClient
- prisma

## God Nodes (most connected - your core abstractions)
1. `@nestjs/common` - 32 edges
2. `AdminController` - 29 edges
3. `PrismaService` - 28 edges
4. `Win32Window` - 21 edges
5. `OutpassService` - 20 edges
6. `AuthService` - 19 edges
7. `AuditService` - 18 edges
8. `compilerOptions` - 18 edges
9. `Auth()` - 17 edges
10. `AuthUser` - 15 edges

## Surprising Connections (you probably didn't know these)
- `3. Phone Number Normalization Standard` --references--> `normalizeMobile()`  [INFERRED]
  ONBOARDING.md → apps/api/src/auth/dto.ts
- `Feature Completeness Analysis` --references--> `normalizeMobile()`  [INFERRED]
  ONBOARDING.md → apps/api/src/auth/dto.ts
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  apps/mobile/windows/runner/main.cpp → apps/mobile/windows/runner/utils.cpp
- `AdminController` --references--> `Auth()`  [EXTRACTED]
  apps/api/src/admin/admin.controller.ts → apps/api/src/common/auth.decorator.ts
- `bootstrap()` --calls--> `AllExceptionsFilter`  [EXTRACTED]
  apps/api/src/main.ts → apps/api/src/common/all-exceptions.filter.ts

## Import Cycles
- None detected.

## Communities (64 total, 19 thin omitted)

### Community 0 - "phone_normalization_and_router_test.dart"
Cohesion: 0.11
Nodes (12): adminGetAuditLog, adminGetDepartments, adminGetOutpasses, adminGetSettings, adminGetUsers, delete, guardScans, main (+4 more)

### Community 1 - "OutpassService"
Cohesion: 0.07
Nodes (9): AuthUser, ExpiryService, ApprovalsController, CancelDto, CreateOutpassDto, DecisionDto, OutpassController, OutpassService (+1 more)

### Community 2 - "GateService"
Cohesion: 0.08
Nodes (13): ScanDto, StartShiftDto, GateController, GateService, ACCEPT_WINDOW_SECONDS, checkWindow(), ParsedToken, parseQrToken() (+5 more)

### Community 3 - "AppDelegate"
Cohesion: 0.06
Nodes (15): AppDelegate, SceneDelegate, RunnerTests, RegisterGeneratedPlugins(), AppDelegate, MainFlutterWindow, RunnerTests, Cocoa (+7 more)

### Community 4 - "admin_screen.dart"
Cohesion: 0.03
Nodes (71): allUsers, _auditLogs, build, _buildRoleList, _busy, _cancelPass, _catCtrl, _collegeCtrl (+63 more)

### Community 5 - "AuthService"
Cohesion: 0.11
Nodes (10): AuthController, AuthService, sha256(), FirebaseTokenDto, normalizeMobile(), RefreshDto, RegisterDeviceDto, SendOtpDto (+2 more)

### Community 6 - "student_screen.dart"
Cohesion: 0.06
Nodes (33): build, _buildCurrentPassView, _buildHistoryView, _busy, createState, _destination, dispose, _error (+25 more)

### Community 7 - "e2e_live.dart"
Cohesion: 0.05
Nodes (40): admin, adminTok, apiBase, auditLogs, call, cancelId, cancelRes, check (+32 more)

### Community 8 - "my_application.cc"
Cohesion: 0.08
Nodes (14): fl_register_plugins(), main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line() (+6 more)

### Community 9 - "gate.e2e-spec.ts"
Cohesion: 0.24
Nodes (11): test, AppModule, T, login(), newKeyPair(), signToken(), useTestFirebaseAuth(), uuid() (+3 more)

### Community 10 - "api_client.dart"
Cohesion: 0.04
Nodes (46): accessToken, adminAddDivision, adminAddOrUpdateDepartment, adminAddUser, adminAssignTutors, adminBulkAddUsers, adminCancelOutpass, adminDeleteDepartment (+38 more)

### Community 11 - "app_state.dart"
Cohesion: 0.06
Nodes (25): api, deviceKeys, isAdmin, isGuard, isHod, isStudent, isTutor, _loadOrCreateDeviceKeys (+17 more)

### Community 12 - "app_theme.dart"
Cohesion: 0.04
Nodes (42): action, adminAccent, AppTheme, borderLight, build, cardBg, cardPadding, cardRadius (+34 more)

### Community 13 - "CCE Outpass — Comprehensive Project Onboarding Report"
Cohesion: 0.05
Nodes (43): 1. Academic Hierarchy in Database, 1. PROJECT OVERVIEW, 1. Start PostgreSQL with Docker, 2. Role-Specific Registration Rules, 2. Run Database Migrations and Seed Admin User, 2. TECH STACK, 3. FOLDER STRUCTURE, 3. Phone Number Normalization Standard (+35 more)

### Community 14 - "login_screen.dart"
Cohesion: 0.12
Nodes (17): build, _busy, _code, createState, dispose, _error, LoginScreen, _LoginScreenState (+9 more)

### Community 15 - "qr_token.dart"
Cohesion: 0.08
Nodes (15): _bigIntTo32Bytes, buildToken, _bytesToBigInt, currentStep, DeviceKeys, fromPrivateKeyPem, generate, kTokenStepSeconds (+7 more)

### Community 16 - "package.json"
Cohesion: 0.09
Nodes (22): name, private, version, embedded-postgres, firebase-admin, jest, @nestjs/cli, @nestjs/passport (+14 more)

### Community 17 - "compilerOptions"
Cohesion: 0.11
Nodes (18): compilerOptions, allowSyntheticDefaultImports, baseUrl, declaration, emitDecoratorMetadata, esModuleInterop, experimentalDecorators, forceConsistentCasingInFileNames (+10 more)

### Community 18 - "win32_window.cpp"
Cohesion: 0.18
Nodes (5): Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, instance_

### Community 19 - "guard_screen.dart"
Cohesion: 0.11
Nodes (18): build, _cameraOn, createState, _Dir, dispose, _gateId, GuardHome, _GuardHomeState (+10 more)

### Community 20 - "Auth"
Cohesion: 0.15
Nodes (4): Auth(), Roles(), NotificationsController, NotificationsService

### Community 22 - "approver_screen.dart"
Cohesion: 0.13
Nodes (12): _askReason, build, createState, _decide, dispose, _error, initState, _loading (+4 more)

### Community 23 - "dependencies"
Cohesion: 0.12
Nodes (17): dependencies, class-transformer, class-validator, firebase-admin, @nestjs/common, @nestjs/config, @nestjs/core, @nestjs/jwt (+9 more)

### Community 24 - "State"
Cohesion: 0.16
Nodes (14): AdminHome, _AdminHomeState, _AdminOutpassMonitorTab, _AdminOutpassMonitorTabState, _AdminPeopleTab, _AdminPeopleTabState, _AdminSettingsTab, _AdminSettingsTabState (+6 more)

### Community 25 - "admin_register_person_test.dart"
Cohesion: 0.12
Nodes (12): adminAddUser, adminGetAuditLog, adminGetDepartments, adminGetOutpasses, adminGetSettings, adminGetUsers, createTestApp, departments (+4 more)

### Community 26 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 27 - "@nestjs/common"
Cohesion: 0.21
Nodes (7): AuditService, PENDING, RESULT_MESSAGE, ACTIVE_STATUSES, PrismaService, @nestjs/common, @prisma/client

### Community 28 - "utils.cpp"
Cohesion: 0.19
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 29 - "jest"
Cohesion: 0.22
Nodes (9): jest, collectCoverageFrom, coverageDirectory, moduleFileExtensions, rootDir, testEnvironment, testRegex, transform (+1 more)

### Community 30 - "daemon.cjs"
Cohesion: 0.17
Nodes (6): child, fs, out, path, { spawn }, path

### Community 32 - "nest-cli.json"
Cohesion: 0.33
Nodes (5): collection, compilerOptions, deleteOutDir, $schema, sourceRoot

### Community 33 - "device_key_persistence_test.dart"
Cohesion: 0.12
Nodes (10): containsKey, _data, delete, FakeSecureStorage, main, noSuchMethod, read, throwOnRead (+2 more)

### Community 35 - "auth.service.ts"
Cohesion: 0.19
Nodes (3): FirebaseAuthService, TempAuthConfig, @nestjs/config

### Community 37 - "CCE Outpass — MVP"
Cohesion: 0.25
Nodes (7): CCE Outpass — MVP, Initial Admin Account, Layout, Phone sign-in setup, Quick start, Security posture (MVP), Tests

### Community 39 - "scripts"
Cohesion: 0.22
Nodes (9): scripts, build, prisma:deploy, prisma:generate, prisma:migrate, seed, start, start:dev (+1 more)

### Community 45 - "CCE Outpass — PRD Summary (MVP scope)"
Cohesion: 0.33
Nodes (5): CCE Outpass — PRD Summary (MVP scope), Explicit MVP cuts (each maps to a PRD ID for later phases), Lifecycle states implemented (PRD §5.1), MVP core loop, Requirements implemented in this MVP

### Community 46 - "FlutterWindow"
Cohesion: 0.11
Nodes (4): FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), project_

### Community 47 - "Win32Window"
Cohesion: 0.24
Nodes (4): Win32Window, child_content_, quit_on_close_, window_handle_

### Community 51 - "devDependencies"
Cohesion: 0.14
Nodes (14): devDependencies, embedded-postgres, jest, @nestjs/cli, @nestjs/testing, prisma, supertest, ts-jest (+6 more)

### Community 52 - "StatelessWidget"
Cohesion: 0.20
Nodes (9): _AdminAuditTab, _AdminDashboardTab, _AdminDepartmentsTab, _OutpassDetailSheet, _StatCard, CceOutpassApp, RootRouter, EmptyState (+1 more)

### Community 54 - "app.module.ts"
Cohesion: 0.17
Nodes (6): AdminModule, AuthModule, GateModule, NotificationsModule, OutpassModule, @nestjs/schedule

### Community 55 - "Point"
Cohesion: 0.21
Nodes (6): Point, x, y, Size, height, width

### Community 57 - "api-audit.spec.ts"
Cohesion: 0.16
Nodes (7): AllExceptionsFilter, ROLES_KEY, JwtAuthGuard, RolesGuard, bootstrap(), @nestjs/core, @nestjs/jwt

### Community 59 - "package:flutter/material.dart"
Cohesion: 0.20
Nodes (4): AsyncActionHelper, extractErrorMessage, run, timeoutDuration

### Community 62 - "ApiClient"
Cohesion: 0.67
Nodes (3): ApiClient, MockAdminApiClient, MockTestApiClient

## Knowledge Gaps
- **377 isolated node(s):** `@nestjs/passport`, `@nestjs/platform-express`, `passport`, `passport-jwt`, `rxjs` (+372 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 676 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **19 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `@nestjs/common` connect `@nestjs/common` to `auth.service.ts`, `AuthService`, `gate.e2e-spec.ts`, `package.json`, `Auth`, `app.module.ts`, `api-audit.spec.ts`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **What connects `@nestjs/passport`, `@nestjs/platform-express`, `passport` to the rest of the system?**
  _377 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `phone_normalization_and_router_test.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.1111111111111111 - nodes in this community are weakly interconnected._
- **Why does `Win32Window` connect `Win32Window` to `FlutterWindow`, `win32_window.cpp`, `.MessageHandler`, `Point`, `string`?**
  _High betweenness centrality (0.022) - this node is a cross-community bridge._
- **Should `OutpassService` be split into smaller, more focused modules?**
  _Cohesion score 0.0707070707070707 - nodes in this community are weakly interconnected._
- **Why does `normalizeMobile()` connect `AuthService` to `auth.service.ts`, `AdminController`, `@nestjs/common`, `CCE Outpass — Comprehensive Project Onboarding Report`?**
  _High betweenness centrality (0.021) - this node is a cross-community bridge._
- **Should `GateService` be split into smaller, more focused modules?**
  _Cohesion score 0.08076923076923077 - nodes in this community are weakly interconnected._