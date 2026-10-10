# Graph Report - College-app  (2026-10-10)

## Corpus Check
- 97 files · ~48,990 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 55 file(s) not represented in the graph (top: (none) 8, .xcconfig 8, .xml 7)

## Summary
- 1078 nodes · 1693 edges · 54 communities (37 shown, 17 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 60 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `9f70f8f0`
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
- main.dart
- approver_screen.dart
- dependencies
- State
- manifest.json
- @nestjs/common
- utils.cpp
- jest
- daemon.cjs
- windows/flutter/generated_plugin_registrant.cc
- nest-cli.json
- device_key_persistence_test.dart
- AdminController
- MainActivity.kt
- CCE Outpass — MVP
- scripts
- CCE Outpass — PRD Summary (MVP scope)
- .MessageHandler
- Win32Window
- cce_outpass
- LaunchImage.imageset/README.md
- decisions.md
- StatelessWidget
- .MessageHandler
- FlutterWindow
- Point
- main.ts
- ApiException

## God Nodes (most connected - your core abstractions)
1. `@nestjs/common` - 30 edges
2. `AdminController` - 28 edges
3. `PrismaService` - 27 edges
4. `Win32Window` - 21 edges
5. `OutpassService` - 20 edges
6. `AuthService` - 18 edges
7. `compilerOptions` - 18 edges
8. `AuditService` - 17 edges
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
- `GateController` --references--> `Auth()`  [EXTRACTED]
  apps/api/src/gate/gate.controller.ts → apps/api/src/common/auth.decorator.ts

## Import Cycles
- None detected.

## Communities (54 total, 17 thin omitted)

### Community 0 - "phone_normalization_and_router_test.dart"
Cohesion: 0.10
Nodes (12): adminGetAuditLog, adminGetDepartments, adminGetOutpasses, adminGetSettings, adminGetUsers, delete, guardScans, main (+4 more)

### Community 1 - "OutpassService"
Cohesion: 0.07
Nodes (8): AuthUser, ExpiryService, CancelDto, CreateOutpassDto, DecisionDto, OutpassController, OutpassService, class-transformer

### Community 2 - "GateService"
Cohesion: 0.08
Nodes (13): ScanDto, StartShiftDto, GateController, GateService, ACCEPT_WINDOW_SECONDS, checkWindow(), ParsedToken, parseQrToken() (+5 more)

### Community 3 - "AppDelegate"
Cohesion: 0.06
Nodes (15): AppDelegate, SceneDelegate, RunnerTests, RegisterGeneratedPlugins(), AppDelegate, MainFlutterWindow, RunnerTests, Cocoa (+7 more)

### Community 4 - "admin_screen.dart"
Cohesion: 0.03
Nodes (70): allUsers, _auditLogs, build, _buildRoleList, _busy, _cancelPass, _catCtrl, _collegeCtrl (+62 more)

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
Cohesion: 0.31
Nodes (9): T, login(), newKeyPair(), signToken(), useTestFirebaseAuth(), uuid(), T, @nestjs/testing (+1 more)

### Community 10 - "api_client.dart"
Cohesion: 0.04
Nodes (46): accessToken, adminAddDivision, adminAddOrUpdateDepartment, adminAddUser, adminAssignTutors, adminBulkAddUsers, adminCancelOutpass, adminDeleteDepartment (+38 more)

### Community 11 - "app_state.dart"
Cohesion: 0.05
Nodes (30): ApiClient, api, AppState, AppStateScope, deviceKeys, isAdmin, isGuard, isHod (+22 more)

### Community 12 - "app_theme.dart"
Cohesion: 0.04
Nodes (42): action, adminAccent, AppTheme, borderLight, build, cardBg, cardPadding, cardRadius (+34 more)

### Community 13 - "CCE Outpass — Comprehensive Project Onboarding Report"
Cohesion: 0.05
Nodes (43): 1. Academic Hierarchy in Database, 1. PROJECT OVERVIEW, 1. Start PostgreSQL with Docker, 2. Role-Specific Registration Rules, 2. Run Database Migrations and Seed Admin User, 2. TECH STACK, 3. FOLDER STRUCTURE, 3. Phone Number Normalization Standard (+35 more)

### Community 14 - "login_screen.dart"
Cohesion: 0.13
Nodes (13): build, _busy, _code, createState, _error, LoginScreen, _LoginScreenState, _mobile (+5 more)

### Community 15 - "qr_token.dart"
Cohesion: 0.08
Nodes (15): _bigIntTo32Bytes, buildToken, _bytesToBigInt, currentStep, DeviceKeys, fromPrivateKeyPem, generate, kTokenStepSeconds (+7 more)

### Community 16 - "package.json"
Cohesion: 0.10
Nodes (20): name, prisma, seed, private, version, embedded-postgres, firebase-admin, jest (+12 more)

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
Cohesion: 0.07
Nodes (28): dependencies, class-transformer, class-validator, firebase-admin, @nestjs/common, @nestjs/config, @nestjs/core, @nestjs/jwt (+20 more)

### Community 24 - "State"
Cohesion: 0.18
Nodes (12): AdminHome, _AdminHomeState, _AdminOutpassMonitorTab, _AdminOutpassMonitorTabState, _AdminPeopleTab, _AdminPeopleTabState, _AdminSettingsTab, _AdminSettingsTabState (+4 more)

### Community 26 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 27 - "@nestjs/common"
Cohesion: 0.05
Nodes (27): prisma, AdminModule, AuditService, AuthModule, FirebaseAuthService, TempAuthConfig, Auth(), Roles() (+19 more)

### Community 28 - "utils.cpp"
Cohesion: 0.12
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
Cohesion: 0.13
Nodes (9): containsKey, _data, delete, main, noSuchMethod, read, throwOnRead, throwOnWrite (+1 more)

### Community 37 - "CCE Outpass — MVP"
Cohesion: 0.25
Nodes (7): CCE Outpass — MVP, Initial Admin Account, Layout, Phone sign-in setup, Quick start, Security posture (MVP), Tests

### Community 39 - "scripts"
Cohesion: 0.20
Nodes (10): scripts, build, prisma:deploy, prisma:generate, prisma:migrate, seed, start, start:dev (+2 more)

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
- **343 isolated node(s):** `@nestjs/platform-express`, `rxjs`, `@nestjs/cli`, `@types/express`, `@types/jest` (+338 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 641 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `@nestjs/common` connect `@nestjs/common` to `package.json`, `main.ts`, `AuthService`, `gate.e2e-spec.ts`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **What connects `@nestjs/platform-express`, `rxjs`, `@nestjs/cli` to the rest of the system?**
  _343 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `phone_normalization_and_router_test.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.1 - nodes in this community are weakly interconnected._
- **Why does `normalizeMobile()` connect `AuthService` to `AdminController`, `@nestjs/common`, `CCE Outpass — Comprehensive Project Onboarding Report`?**
  _High betweenness centrality (0.023) - this node is a cross-community bridge._
- **Should `OutpassService` be split into smaller, more focused modules?**
  _Cohesion score 0.07329462989840348 - nodes in this community are weakly interconnected._
- **Why does `Auth()` connect `@nestjs/common` to `OutpassService`, `AdminController`, `GateService`, `AuthService`?**
  _High betweenness centrality (0.019) - this node is a cross-community bridge._
- **Should `GateService` be split into smaller, more focused modules?**
  _Cohesion score 0.07926829268292683 - nodes in this community are weakly interconnected._