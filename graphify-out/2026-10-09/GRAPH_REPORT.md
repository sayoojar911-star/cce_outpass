# Graph Report - College-app  (2026-10-09)

## Corpus Check
- 91 files · ~38,220 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 55 file(s) not represented in the graph (top: (none) 8, .xcconfig 8, .xml 7)

## Summary
- 898 nodes · 1373 edges · 52 communities (37 shown, 15 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 45 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `fc296adc`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- @nestjs/common
- OutpassService
- gate.service.ts
- GeneratedPluginRegistrant.swift
- demo_cycle.dart
- AuthService
- student_screen.dart
- e2e_live.dart
- my_application.cc
- gate.e2e-spec.ts
- api_client.dart
- app_state.dart
- mock_backend.dart
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
- PrismaService
- utils.cpp
- jest
- daemon.cjs
- windows/flutter/generated_plugin_registrant.cc
- nest-cli.json
- device_key_persistence_test.dart
- auth.module.ts
- MainActivity.kt
- CCE Outpass — MVP
- scripts
- CCE Outpass — PRD Summary (MVP scope)
- app.module.ts
- mock_discrepancies_test.dart
- cce_outpass
- LaunchImage.imageset/README.md
- decisions.md
- seed.ts

## God Nodes (most connected - your core abstractions)
1. `@nestjs/common` - 27 edges
2. `PrismaService` - 23 edges
3. `Win32Window` - 21 edges
4. `OutpassService` - 20 edges
5. `compilerOptions` - 18 edges
6. `Auth()` - 15 edges
7. `AuthUser` - 15 edges
8. `GateService` - 15 edges
9. `AuthService` - 14 edges
10. `AuditService` - 13 edges

## Surprising Connections (you probably didn't know these)
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  apps/mobile/windows/runner/main.cpp → apps/mobile/windows/runner/utils.cpp
- `GateController` --references--> `Auth()`  [EXTRACTED]
  apps/api/src/gate/gate.controller.ts → apps/api/src/common/auth.decorator.ts
- `NotificationsController` --references--> `Auth()`  [EXTRACTED]
  apps/api/src/notifications/notifications.controller.ts → apps/api/src/common/auth.decorator.ts
- `my_application_activate()` --calls--> `fl_register_plugins()`  [INFERRED]
  apps/mobile/linux/runner/my_application.cc → apps/mobile/linux/flutter/generated_plugin_registrant.cc
- `main()` --calls--> `my_application_new()`  [INFERRED]
  apps/mobile/linux/runner/main.cc → apps/mobile/linux/runner/my_application.cc

## Import Cycles
- None detected.

## Communities (52 total, 15 thin omitted)

### Community 0 - "@nestjs/common"
Cohesion: 0.16
Nodes (7): ROLES_KEY, JwtAuthGuard, RolesGuard, @nestjs/common, @nestjs/core, @nestjs/jwt, reflect-metadata

### Community 1 - "OutpassService"
Cohesion: 0.07
Nodes (10): Auth(), Roles(), AuthUser, ExpiryService, ApprovalsController, CancelDto, CreateOutpassDto, DecisionDto (+2 more)

### Community 2 - "gate.service.ts"
Cohesion: 0.08
Nodes (15): ScanDto, StartShiftDto, GateController, GateService, PENDING, RESULT_MESSAGE, ACCEPT_WINDOW_SECONDS, checkWindow() (+7 more)

### Community 3 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.06
Nodes (17): AppDelegate, SceneDelegate, RunnerTests, RegisterGeneratedPlugins(), AppDelegate, MainFlutterWindow, RunnerTests, Cocoa (+9 more)

### Community 4 - "demo_cycle.dart"
Cohesion: 0.05
Nodes (37): apiBase, approved, call, check, created, demoMobile, exited, exitRes (+29 more)

### Community 5 - "AuthService"
Cohesion: 0.12
Nodes (8): AuthController, AuthService, sha256(), FirebaseTokenDto, normalizeMobile(), RefreshDto, RegisterDeviceDto, class-validator

### Community 6 - "student_screen.dart"
Cohesion: 0.06
Nodes (29): build, _busy, _categories, createState, _destination, dispose, _emergency, _error (+21 more)

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
Cohesion: 0.07
Nodes (23): accessToken, ApiException, b, baseUrl, cancelOutpass, createOutpass, decide, _decode (+15 more)

### Community 11 - "app_state.dart"
Cohesion: 0.08
Nodes (21): ApiClient, api, AppState, AppStateScope, deviceKeys, isGuard, isHod, isStudent (+13 more)

### Community 12 - "mock_backend.dart"
Cohesion: 0.07
Nodes (26): _activeStatuses, cancelOutpass, createOutpass, currentUserId, decide, findUserByMobile, _gateEvents, guardScans (+18 more)

### Community 13 - "CCE Outpass — Comprehensive Project Onboarding Report"
Cohesion: 0.07
Nodes (28): 1. PROJECT OVERVIEW, 2. TECH STACK, 3. FOLDER STRUCTURE, 4. ARCHITECTURE AND DATA FLOW, 5. HARDCODING AUDIT, 6. HOW TO RUN IT, 7. OTHER PROBLEMS FOUND & RANKED BY PRIORITY, 8. NEXT STEPS & ROADMAP (+20 more)

### Community 14 - "login_screen.dart"
Cohesion: 0.10
Nodes (16): build, _busy, _code, _confirmationResult, createState, _error, _hasFirebase, _mobile (+8 more)

### Community 15 - "qr_token.dart"
Cohesion: 0.09
Nodes (15): _bigIntTo32Bytes, buildToken, _bytesToBigInt, currentStep, DeviceKeys, fromPrivateKeyPem, generate, kTokenStepSeconds (+7 more)

### Community 16 - "package.json"
Cohesion: 0.10
Nodes (20): name, prisma, seed, private, version, class-transformer, firebase-admin, jest (+12 more)

### Community 17 - "compilerOptions"
Cohesion: 0.11
Nodes (18): compilerOptions, allowSyntheticDefaultImports, baseUrl, declaration, emitDecoratorMetadata, esModuleInterop, experimentalDecorators, forceConsistentCasingInFileNames (+10 more)

### Community 18 - "win32_window.cpp"
Cohesion: 0.05
Nodes (20): FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), project_, EnableFullDpiSupportIfAvailable(), Point, x, y (+12 more)

### Community 19 - "guard_screen.dart"
Cohesion: 0.11
Nodes (15): build, _cameraOn, createState, _Dir, dispose, _gateId, _history, initState (+7 more)

### Community 21 - "main.dart"
Cohesion: 0.14
Nodes (7): apiKey, build, CceOutpassApp, _DemoRoleSwitcherButton, main, RootRouter, _ActiveCard

### Community 22 - "approver_screen.dart"
Cohesion: 0.12
Nodes (12): _askReason, build, createState, _decide, dispose, _error, initState, _loading (+4 more)

### Community 23 - "dependencies"
Cohesion: 0.14
Nodes (14): dependencies, class-transformer, class-validator, firebase-admin, @nestjs/common, @nestjs/config, @nestjs/core, @nestjs/jwt (+6 more)

### Community 24 - "State"
Cohesion: 0.20
Nodes (12): ApproverHome, _ApproverHomeState, GuardHome, _GuardHomeState, LoginScreen, _LoginScreenState, QrScreen, _QrScreenState (+4 more)

### Community 25 - "devDependencies"
Cohesion: 0.15
Nodes (13): devDependencies, jest, @nestjs/cli, @nestjs/testing, prisma, supertest, ts-jest, ts-node (+5 more)

### Community 26 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 27 - "PrismaService"
Cohesion: 0.22
Nodes (4): AuditService, ACTIVE_STATUSES, PrismaService, @prisma/client

### Community 28 - "utils.cpp"
Cohesion: 0.19
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
Cohesion: 0.14
Nodes (9): containsKey, _data, delete, main, noSuchMethod, read, throwOnRead, throwOnWrite (+1 more)

### Community 35 - "auth.module.ts"
Cohesion: 0.27
Nodes (3): AuthModule, FirebaseAuthService, @nestjs/config

### Community 37 - "CCE Outpass — MVP"
Cohesion: 0.25
Nodes (7): CCE Outpass — MVP, Layout, Phone sign-in setup, Quick start, Security posture (MVP), Seeded accounts, Tests

### Community 39 - "scripts"
Cohesion: 0.22
Nodes (9): scripts, build, prisma:deploy, prisma:generate, prisma:migrate, seed, start, start:dev (+1 more)

### Community 45 - "CCE Outpass — PRD Summary (MVP scope)"
Cohesion: 0.33
Nodes (5): CCE Outpass — PRD Summary (MVP scope), Explicit MVP cuts (each maps to a PRD ID for later phases), Lifecycle states implemented (PRD §5.1), MVP core loop, Requirements implemented in this MVP

### Community 46 - "app.module.ts"
Cohesion: 0.25
Nodes (4): GateModule, NotificationsModule, OutpassModule, @nestjs/schedule

## Knowledge Gaps
- **261 isolated node(s):** `@nestjs/platform-express`, `rxjs`, `@nestjs/cli`, `@types/express`, `@types/jest` (+256 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 528 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **15 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `win32_window.cpp` to `string`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **What connects `@nestjs/platform-express`, `rxjs`, `@nestjs/cli` to the rest of the system?**
  _261 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `OutpassService` be split into smaller, more focused modules?**
  _Cohesion score 0.0701344243132671 - nodes in this community are weakly interconnected._
- **Why does `@nestjs/common` connect `@nestjs/common` to `OutpassService`, `gate.service.ts`, `auth.module.ts`, `AuthService`, `gate.e2e-spec.ts`, `app.module.ts`, `package.json`, `NotificationsService`, `PrismaService`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **Should `gate.service.ts` be split into smaller, more focused modules?**
  _Cohesion score 0.0824524312896406 - nodes in this community are weakly interconnected._
- **Why does `FlutterWindow` connect `win32_window.cpp` to `string`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **Should `GeneratedPluginRegistrant.swift` be split into smaller, more focused modules?**
  _Cohesion score 0.05647840531561462 - nodes in this community are weakly interconnected._