# Graph Report - College-app  (2026-10-11)

## Corpus Check
- 138 files · ~86,752 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 55 file(s) not represented in the graph (top: (none) 8, .xcconfig 8, .xml 7)

## Summary
- 1590 nodes · 2442 edges · 84 communities (60 shown, 24 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 99 edges (avg confidence: 0.88)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b2b817ea`
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
- ticket_outpass.dart
- main.dart
- approver_screen.dart
- dependencies
- State
- admin_register_person_test.dart
- manifest.json
- outpass.service.ts
- utils.cpp
- jest
- daemon.cjs
- windows/flutter/generated_plugin_registrant.cc
- nest-cli.json
- device_key_persistence_test.dart
- AdminController
- auth.decorator.ts
- MainActivity.kt
- CCE Outpass — MVP
- NotificationsService
- CCE Outpass — PRD Summary (MVP scope)
- .MessageHandler
- Win32Window
- cce_outpass
- LaunchImage.imageset/README.md
- decisions.md
- devDependencies
- StatelessWidget
- .MessageHandler
- PrismaService
- Point
- @prisma/client
- ticket_html_generator.dart
- ApiException
- async_action_helper.dart
- app.module.ts
- auth.controller.ts
- ApiClient
- ticket_outpass_widget_test.dart
- admin_roles_workflows.dart
- ConfigService
- platform_print_web.dart
- platform_print.dart
- Technology Stack
- Codebase Structure
- platform_print_stub.dart
- role_service.dart
- app_constants.dart
- OutpassStatus
- AllExceptionsFilter
- migrate-to-dynamic.cjs
- AppState
- FlutterWindow
- FirebaseAuthService
- printed_receipt_reveal.dart
- verify-gate-return-flow.cjs
- prisma
- SteppedThermalPrinterCurve

## God Nodes (most connected - your core abstractions)
1. `AdminController` - 38 edges
2. `@nestjs/common` - 37 edges
3. `PrismaService` - 37 edges
4. `OutpassService` - 22 edges
5. `AuditService` - 21 edges
6. `AuthService` - 21 edges
7. `GateService` - 21 edges
8. `Win32Window` - 21 edges
9. `compilerOptions` - 18 edges
10. `@prisma/client` - 15 edges

## Surprising Connections (you probably didn't know these)
- `3. Phone Number Normalization Standard` --references--> `normalizeMobile()`  [INFERRED]
  ONBOARDING.md → apps/api/src/auth/dto.ts
- `Feature Completeness Analysis` --references--> `normalizeMobile()`  [INFERRED]
  ONBOARDING.md → apps/api/src/auth/dto.ts
- `Architectural Constraints` --references--> `normalizeMobile()`  [INFERRED]
  .planning/codebase/ARCHITECTURE.md → apps/api/src/auth/dto.ts
- `Layers` --references--> `PrismaService`  [INFERRED]
  .planning/codebase/ARCHITECTURE.md → apps/api/src/prisma.service.ts
- `Component Responsibilities` --references--> `AdminController`  [INFERRED]
  .planning/codebase/ARCHITECTURE.md → apps/api/src/admin/admin.controller.ts

## Import Cycles
- None detected.

## Communities (84 total, 24 thin omitted)

### Community 0 - "phone_normalization_and_router_test.dart"
Cohesion: 0.12
Nodes (12): adminGetAuditLog, adminGetDepartments, adminGetOutpasses, adminGetSettings, adminGetUsers, delete, guardScans, main (+4 more)

### Community 1 - "OutpassService"
Cohesion: 0.06
Nodes (11): ExpiryService, OutpassController, OutpassService, 1. Environment & Infrastructure, 2. Main Bug: Student Registration Without Tutor, 3. Unified Async Handling & Timeout Protection, 4. Selection Bar Tab Persistence Fix, 5. Clean Build & Test Verification (+3 more)

### Community 2 - "GateService"
Cohesion: 0.10
Nodes (13): AuthUser, ManualEntryDto, ScanDto, StartShiftDto, GateController, formatISTDateTime(), formatISTTime(), GateService (+5 more)

### Community 3 - "AppDelegate"
Cohesion: 0.06
Nodes (15): AppDelegate, SceneDelegate, RunnerTests, RegisterGeneratedPlugins(), AppDelegate, MainFlutterWindow, RunnerTests, Cocoa (+7 more)

### Community 4 - "admin_screen.dart"
Cohesion: 0.02
Nodes (80): allUsers, _auditLogs, build, _buildRoleList, _busy, _cancelPass, _categories, _collegeCtrl (+72 more)

### Community 5 - "AuthService"
Cohesion: 0.10
Nodes (12): AuthController, AuthService, sha256(), normalizeMobile(), 1. Main Bug: Student Registration Without Tutor Hangs / Fails, 2. UI Selection Bar Persisted Across Tabs, 3. Unified Async Action Handling Across Flutter Screens, 4. Build & Static Analysis Cleanups (+4 more)

### Community 6 - "student_screen.dart"
Cohesion: 0.05
Nodes (38): build, _buildCurrentPassView, _buildHistoryView, _busy, createState, _destination, didChangeDependencies, dispose (+30 more)

### Community 7 - "e2e_live.dart"
Cohesion: 0.05
Nodes (40): admin, adminTok, apiBase, auditLogs, call, cancelId, cancelRes, check (+32 more)

### Community 8 - "my_application.cc"
Cohesion: 0.08
Nodes (14): fl_register_plugins(), main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line() (+6 more)

### Community 9 - "gate.e2e-spec.ts"
Cohesion: 0.09
Nodes (27): scripts, build, lint, prisma:deploy, prisma:generate, prisma:migrate, seed, start (+19 more)

### Community 10 - "api_client.dart"
Cohesion: 0.03
Nodes (58): accessToken, adminAddDivision, adminAddOrUpdateDepartment, adminAddUser, adminAssignTutors, adminBulkAddUsers, adminCancelOutpass, adminDeleteDepartment (+50 more)

### Community 11 - "app_state.dart"
Cohesion: 0.04
Nodes (48): api, canAccessAdmin, canApproveOutpass, canCreateOutpass, canManageRoles, canManageUsers, canScanGate, departments (+40 more)

### Community 12 - "app_theme.dart"
Cohesion: 0.04
Nodes (42): action, adminAccent, AppTheme, borderLight, build, cardBg, cardPadding, cardRadius (+34 more)

### Community 13 - "CCE Outpass — Comprehensive Project Onboarding Report"
Cohesion: 0.05
Nodes (43): 1. Academic Hierarchy in Database, 1. PROJECT OVERVIEW, 1. Start PostgreSQL with Docker, 2. Role-Specific Registration Rules, 2. Run Database Migrations and Seed Admin User, 2. TECH STACK, 3. FOLDER STRUCTURE, 3. Phone Number Normalization Standard (+35 more)

### Community 14 - "login_screen.dart"
Cohesion: 0.11
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
Cohesion: 0.06
Nodes (32): build, _cameraOn, createState, day, _Dir, dispose, dt, formatToIST (+24 more)

### Community 20 - "ticket_outpass.dart"
Cohesion: 0.05
Nodes (32): animatePrint, build, _buildActionButtons, _buildApprovalProgressCard, _buildDestinationAndPurpose, _buildQrAndPassCodeSection, _buildReceiptHeader, _buildStatusBadge (+24 more)

### Community 21 - "main.dart"
Cohesion: 0.11
Nodes (10): _appState, build, CceOutpassApp, _CceOutpassAppState, _checkStatus, createState, main, PendingApprovalScreen (+2 more)

### Community 22 - "approver_screen.dart"
Cohesion: 0.10
Nodes (17): ApproverHome, _ApproverHomeState, _askReason, build, createState, _decide, dispose, _error (+9 more)

### Community 23 - "dependencies"
Cohesion: 0.12
Nodes (17): dependencies, class-transformer, class-validator, firebase-admin, @nestjs/common, @nestjs/config, @nestjs/core, @nestjs/jwt (+9 more)

### Community 24 - "State"
Cohesion: 0.13
Nodes (20): AdminWorkflowsTab, _AdminWorkflowsTabState, CategoryFormDialog, _CategoryFormDialogState, AdminHome, _AdminHomeState, _AdminOutpassMonitorTab, _AdminOutpassMonitorTabState (+12 more)

### Community 25 - "admin_register_person_test.dart"
Cohesion: 0.13
Nodes (12): adminAddUser, adminGetAuditLog, adminGetDepartments, adminGetOutpasses, adminGetSettings, adminGetUsers, createTestApp, departments (+4 more)

### Community 26 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 27 - "outpass.service.ts"
Cohesion: 0.22
Nodes (7): RequirePermissions(), ApprovalsController, CancelDto, CreateOutpassDto, DecisionDto, ACTIVE_STATUSES, class-transformer

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
Cohesion: 0.13
Nodes (10): containsKey, _data, delete, FakeSecureStorage, main, noSuchMethod, read, throwOnRead (+2 more)

### Community 35 - "auth.decorator.ts"
Cohesion: 0.11
Nodes (7): JwtAuthGuard, PERMISSIONS_KEY, PermissionsGuard, ROLES_KEY, RolesGuard, Authentication & Identity, @nestjs/core

### Community 37 - "CCE Outpass — MVP"
Cohesion: 0.25
Nodes (7): CCE Outpass — MVP, Initial Admin Account, Layout, Phone sign-in setup, Quick start, Security posture (MVP), Tests

### Community 39 - "NotificationsService"
Cohesion: 0.14
Nodes (4): Auth(), NotificationsController, NotificationsService, @nestjs/schedule

### Community 45 - "CCE Outpass — PRD Summary (MVP scope)"
Cohesion: 0.33
Nodes (5): CCE Outpass — PRD Summary (MVP scope), Explicit MVP cuts (each maps to a PRD ID for later phases), Lifecycle states implemented (PRD §5.1), MVP core loop, Requirements implemented in this MVP

### Community 47 - "Win32Window"
Cohesion: 0.24
Nodes (4): Win32Window, child_content_, quit_on_close_, window_handle_

### Community 51 - "devDependencies"
Cohesion: 0.14
Nodes (14): devDependencies, embedded-postgres, jest, @nestjs/cli, @nestjs/testing, prisma, supertest, ts-jest (+6 more)

### Community 52 - "StatelessWidget"
Cohesion: 0.20
Nodes (9): AdminRolesTab, _AdminAuditTab, _AdminDashboardTab, _AdminDepartmentsTab, _OutpassDetailSheet, _StatCard, RootRouter, EmptyState (+1 more)

### Community 54 - "PrismaService"
Cohesion: 0.24
Nodes (6): AuditService, OUTPASS_STATUS, PrismaService, @nestjs/common, @nestjs/config, @nestjs/jwt

### Community 55 - "Point"
Cohesion: 0.21
Nodes (6): Point, x, y, Size, height, width

### Community 56 - "@prisma/client"
Cohesion: 0.05
Nodes (32): prisma, prisma, generateRandomPassCode(), getUniquePassCode(), migrate(), prisma, prisma, prisma (+24 more)

### Community 57 - "ticket_html_generator.dart"
Cohesion: 0.17
Nodes (8): charset, class, _formatDateTime, _formatShortDate, generate, _generateQrSvg, lang, TicketHtmlGenerator

### Community 59 - "async_action_helper.dart"
Cohesion: 0.22
Nodes (4): AsyncActionHelper, extractErrorMessage, run, timeoutDuration

### Community 60 - "app.module.ts"
Cohesion: 0.18
Nodes (7): AdminModule, AuthModule, AppConfigModule, GateModule, NotificationsModule, OutpassModule, Component Responsibilities

### Community 61 - "auth.controller.ts"
Cohesion: 0.37
Nodes (6): FirebaseTokenDto, RefreshDto, RegisterDeviceDto, SendOtpDto, VerifyOtpDto, class-validator

### Community 62 - "ApiClient"
Cohesion: 0.50
Nodes (4): ApiClient, MockAdminApiClient, MockTestApiClient, MockOutpassApiClient

### Community 63 - "ticket_outpass_widget_test.dart"
Cohesion: 0.12
Nodes (8): createOutpass, lastCreatedOutpass, main, createWidgetUnderTest, emergencyOutpass, main, normalOutpass, testState

### Community 64 - "admin_roles_workflows.dart"
Cohesion: 0.06
Nodes (33): _active, _availablePermissions, build, _busy, categories, _chain, createState, _deleteCategory (+25 more)

### Community 67 - "platform_print_web.dart"
Cohesion: 0.40
Nodes (3): _printCleanTicket, printTicketWeb, _windowPrint

### Community 69 - "Technology Stack"
Cohesion: 0.25
Nodes (7): Configuration, Frameworks, Key Dependencies, Languages, Platform Requirements, Runtime, Technology Stack

### Community 70 - "Codebase Structure"
Cohesion: 0.29
Nodes (6): Codebase Structure, Directory Layout, Directory Purposes, Key File Locations, Naming Conventions, Where to Add New Code

### Community 72 - "role_service.dart"
Cohesion: 0.11
Nodes (16): canAccessAdmin, canApproveOutpass, canCreateOutpass, canManageRoles, canManageUsers, canScanGate, hasPermission, isPending (+8 more)

### Community 73 - "app_constants.dart"
Cohesion: 0.11
Nodes (18): approved, cancelled, completed, emergency, exited, expired, hod, isPending (+10 more)

### Community 74 - "OutpassStatus"
Cohesion: 0.11
Nodes (17): OutpassStatus, APPROVED, CANCELLED, COMPLETED, EXITED, EXPIRED, OVERDUE, PENDING_HOD (+9 more)

### Community 75 - "AllExceptionsFilter"
Cohesion: 0.06
Nodes (26): AllExceptionsFilter, GuardRateLimitState, bootstrap(), Architectural Constraints, Architecture, Data Flow, Entry Points, Key Abstractions (+18 more)

### Community 78 - "FlutterWindow"
Cohesion: 0.25
Nodes (3): FlutterWindow, flutter_controller_, project_

### Community 80 - "printed_receipt_reveal.dart"
Cohesion: 0.07
Nodes (24): build, _build3DPrinter, _buildLedLight, child, clearPassFromSession, _controller, createState, dispose (+16 more)

### Community 81 - "verify-gate-return-flow.cjs"
Cohesion: 0.09
Nodes (22): crypto, http, post(), prisma, { PrismaClient }, run(), uuid(), crypto (+14 more)

## Knowledge Gaps
- **599 isolated node(s):** `@nestjs/passport`, `@nestjs/platform-express`, `passport`, `passport-jwt`, `rxjs` (+594 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 987 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **24 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `@nestjs/common` connect `PrismaService` to `GateService`, `auth.decorator.ts`, `NotificationsService`, `gate.e2e-spec.ts`, `package.json`, `outpass.service.ts`, `app.module.ts`, `auth.controller.ts`?**
  _High betweenness centrality (0.035) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `OutpassService` (e.g. with `Component Responsibilities` and `Primary Outpass Lifecycle Path`) actually correct?**
  _`OutpassService` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `@nestjs/passport`, `@nestjs/platform-express`, `passport` to the rest of the system?**
  _599 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `phone_normalization_and_router_test.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.11764705882352941 - nodes in this community are weakly interconnected._
- **Why does `@prisma/client` connect `@prisma/client` to `package.json`, `verify-gate-return-flow.cjs`, `outpass.service.ts`, `PrismaService`?**
  _High betweenness centrality (0.034) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `AuditService` (e.g. with `Component Responsibilities` and `Monitoring & Observability`) actually correct?**
  _`AuditService` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Should `OutpassService` be split into smaller, more focused modules?**
  _Cohesion score 0.06274509803921569 - nodes in this community are weakly interconnected._