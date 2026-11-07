# Graph Report - College-app  (2026-10-12)

## Corpus Check
- 190 files · ~1,653,325 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 55 file(s) not represented in the graph (top: (none) 8, .xcconfig 8, .xml 7)

## Summary
- 1881 nodes · 2781 edges · 105 communities (81 shown, 24 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 103 edges (avg confidence: 0.88)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `28504914`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- phone_normalization_and_router_test.dart
- OutpassService
- GateService
- AppDelegate
- admin_screen.dart
- normalizeMobile
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
- app_layout.dart
- utils.cpp
- jest
- backup-all.cjs
- windows/flutter/generated_plugin_registrant.cc
- nest-cli.json
- device_key_persistence_test.dart
- AdminController
- api-audit.spec.ts
- MainActivity.kt
- CCE Outpass — MVP
- PrismaService
- CCE Outpass — PRD Summary (MVP scope)
- FlutterWindow
- Win32Window
- cce_outpass
- LaunchImage.imageset/README.md
- decisions.md
- devDependencies
- StatelessWidget
- .MessageHandler
- @nestjs/common
- Point
- @prisma/client
- ticket_html_generator.dart
- ApiException
- package:flutter/material.dart
- app.module.ts
- Architecture
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
- Phase 1: Core Lifecycle & Gate Security Hardening - Context
- AuthService
- printed_receipt_reveal.dart
- verify-gate-return-flow.cjs
- responsive_overflow_test.dart
- seed-dynamic-data.cjs
- Christ College of Engineering (CCE) Digital Outpass System
- v1 Requirements
- Synthesized Decisions
- scripts
- Phase Details
- verify-qr-token-scan.cjs
- verify-e2e-walkthrough.cjs
- verify-hod-registration-flow.cjs
- verify-tutor-approval-flow.cjs
- Testing Patterns
- Onboarding Summary
- Project State
- migrate-pass-codes.ts
- Ingest Conflicts Report
- Plan 01-02: Guard Verdict UX & Ticket Invalidation Integration
- check-counts.cjs
- bootstrap-admin.cjs
- Synthesized Requirements
- Document Synthesis
- CustomPainter
- inspect-db.cjs

## God Nodes (most connected - your core abstractions)
1. `AdminController` - 38 edges
2. `@nestjs/common` - 37 edges
3. `PrismaService` - 37 edges
4. `OutpassService` - 22 edges
5. `AuditService` - 21 edges
6. `AuthService` - 21 edges
7. `GateService` - 21 edges
8. `Win32Window` - 21 edges
9. `@prisma/client` - 18 edges
10. `compilerOptions` - 18 edges

## Surprising Connections (you probably didn't know these)
- `3. Phone Number Normalization Standard` --references--> `normalizeMobile()`  [INFERRED]
  ONBOARDING.md → apps/api/src/auth/dto.ts
- `Feature Completeness Analysis` --references--> `normalizeMobile()`  [INFERRED]
  ONBOARDING.md → apps/api/src/auth/dto.ts
- `Architectural Constraints` --references--> `normalizeMobile()`  [INFERRED]
  .planning/codebase/ARCHITECTURE.md → apps/api/src/auth/dto.ts
- `Established Patterns` --references--> `normalizeMobile()`  [INFERRED]
  .planning/phases/01-core-lifecycle-gate-security-hardening/01-CONTEXT.md → apps/api/src/auth/dto.ts
- `Error Handling` --references--> `AllExceptionsFilter`  [INFERRED]
  .planning/codebase/CONVENTIONS.md → apps/api/src/common/all-exceptions.filter.ts

## Import Cycles
- None detected.

## Communities (105 total, 24 thin omitted)

### Community 0 - "phone_normalization_and_router_test.dart"
Cohesion: 0.12
Nodes (12): adminGetAuditLog, adminGetDepartments, adminGetOutpasses, adminGetSettings, adminGetUsers, delete, guardScans, main (+4 more)

### Community 1 - "OutpassService"
Cohesion: 0.06
Nodes (16): AuthUser, ExpiryService, CancelDto, CreateOutpassDto, DecisionDto, OutpassController, OutpassService, 1. Environment & Infrastructure (+8 more)

### Community 2 - "GateService"
Cohesion: 0.06
Nodes (25): ManualEntryDto, ScanDto, StartShiftDto, GateController, formatISTDateTime(), formatISTTime(), GateService, ACCEPT_WINDOW_SECONDS (+17 more)

### Community 3 - "AppDelegate"
Cohesion: 0.06
Nodes (15): AppDelegate, SceneDelegate, RunnerTests, RegisterGeneratedPlugins(), AppDelegate, MainFlutterWindow, RunnerTests, Cocoa (+7 more)

### Community 4 - "admin_screen.dart"
Cohesion: 0.02
Nodes (82): allUsers, _auditLogs, build, _buildRoleList, _busy, _cancelPass, _categories, _collegeCtrl (+74 more)

### Community 5 - "normalizeMobile"
Cohesion: 0.06
Nodes (24): AuthController, sha256(), FirebaseTokenDto, normalizeMobile(), RefreshDto, RegisterDeviceDto, SendOtpDto, VerifyOtpDto (+16 more)

### Community 6 - "student_screen.dart"
Cohesion: 0.06
Nodes (34): build, _buildCurrentPassView, _buildHistoryView, _busy, createState, _destination, _destinationFocusNode, didChangeDependencies (+26 more)

### Community 7 - "e2e_live.dart"
Cohesion: 0.05
Nodes (40): admin, adminTok, apiBase, auditLogs, call, cancelId, cancelRes, check (+32 more)

### Community 8 - "my_application.cc"
Cohesion: 0.08
Nodes (14): fl_register_plugins(), main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line() (+6 more)

### Community 9 - "gate.e2e-spec.ts"
Cohesion: 0.22
Nodes (11): test, AppModule, T, login(), newKeyPair(), signToken(), useTestFirebaseAuth(), uuid() (+3 more)

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
Cohesion: 0.10
Nodes (17): build, _busy, _code, createState, dispose, _error, _formKey, _mobile (+9 more)

### Community 15 - "qr_token.dart"
Cohesion: 0.08
Nodes (15): _bigIntTo32Bytes, buildToken, _bytesToBigInt, currentStep, DeviceKeys, fromPrivateKeyPem, generate, kTokenStepSeconds (+7 more)

### Community 16 - "package.json"
Cohesion: 0.08
Nodes (24): name, prisma, seed, private, version, embedded-postgres, firebase-admin, jest (+16 more)

### Community 17 - "compilerOptions"
Cohesion: 0.11
Nodes (18): compilerOptions, allowSyntheticDefaultImports, baseUrl, declaration, emitDecoratorMetadata, esModuleInterop, experimentalDecorators, forceConsistentCasingInFileNames (+10 more)

### Community 18 - "win32_window.cpp"
Cohesion: 0.18
Nodes (5): Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, instance_

### Community 19 - "guard_screen.dart"
Cohesion: 0.06
Nodes (30): build, _cameraOn, createState, day, _Dir, dispose, dt, formatToIST (+22 more)

### Community 20 - "ticket_outpass.dart"
Cohesion: 0.04
Nodes (39): animatePrint, animation, build, _buildActionButtons, _buildApprovalProgressCard, _buildDestinationAndPurpose, _buildPerforationDivider, _buildQrAndPassCodeSection (+31 more)

### Community 21 - "main.dart"
Cohesion: 0.11
Nodes (11): _appState, build, CceOutpassApp, _CceOutpassAppState, _checkStatus, createState, main, PendingApprovalScreen (+3 more)

### Community 22 - "approver_screen.dart"
Cohesion: 0.09
Nodes (16): _askReason, build, _confirmApproval, createState, _decide, dispose, _error, _fetchPending (+8 more)

### Community 23 - "dependencies"
Cohesion: 0.12
Nodes (17): dependencies, class-transformer, class-validator, firebase-admin, @nestjs/common, @nestjs/config, @nestjs/core, @nestjs/jwt (+9 more)

### Community 24 - "State"
Cohesion: 0.09
Nodes (30): AdminWorkflowsTab, _AdminWorkflowsTabState, AdminHome, _AdminHomeState, _AdminOutpassMonitorTab, _AdminOutpassMonitorTabState, _AdminPeopleTab, _AdminPeopleTabState (+22 more)

### Community 25 - "admin_register_person_test.dart"
Cohesion: 0.13
Nodes (12): adminAddUser, adminGetAuditLog, adminGetDepartments, adminGetOutpasses, adminGetSettings, adminGetUsers, createTestApp, departments (+4 more)

### Community 26 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 27 - "app_layout.dart"
Cohesion: 0.02
Nodes (87): action, actions, alignment, AppLayout, AppRadii, AppSpacing, autofocus, backgroundColor (+79 more)

### Community 28 - "utils.cpp"
Cohesion: 0.18
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 29 - "jest"
Cohesion: 0.22
Nodes (9): jest, collectCoverageFrom, coverageDirectory, moduleFileExtensions, rootDir, testEnvironment, testRegex, transform (+1 more)

### Community 30 - "backup-all.cjs"
Cohesion: 0.12
Nodes (12): backup(), fs, path, prisma, { PrismaClient }, replacer(), child, fs (+4 more)

### Community 32 - "nest-cli.json"
Cohesion: 0.33
Nodes (5): collection, compilerOptions, deleteOutDir, $schema, sourceRoot

### Community 33 - "device_key_persistence_test.dart"
Cohesion: 0.14
Nodes (10): containsKey, _data, delete, FakeSecureStorage, main, noSuchMethod, read, throwOnRead (+2 more)

### Community 35 - "api-audit.spec.ts"
Cohesion: 0.15
Nodes (7): JwtAuthGuard, PERMISSIONS_KEY, PermissionsGuard, ROLES_KEY, RolesGuard, Authentication & Identity, @nestjs/core

### Community 37 - "CCE Outpass — MVP"
Cohesion: 0.25
Nodes (7): CCE Outpass — MVP, Initial Admin Account, Layout, Phone sign-in setup, Quick start, Security posture (MVP), Tests

### Community 39 - "PrismaService"
Cohesion: 0.12
Nodes (5): Auth(), NotificationsController, NotificationsService, ACTIVE_STATUSES, PrismaService

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
Cohesion: 0.08
Nodes (23): AdminRolesTab, _AdminAuditTab, _AdminDashboardTab, _AdminDepartmentsTab, _OutpassDetailSheet, _StatCard, AppButtonRow, AppCard (+15 more)

### Community 54 - "@nestjs/common"
Cohesion: 0.29
Nodes (3): AuditService, OUTPASS_STATUS, @nestjs/common

### Community 55 - "Point"
Cohesion: 0.21
Nodes (6): Point, x, y, Size, height, width

### Community 56 - "@prisma/client"
Cohesion: 0.14
Nodes (6): prisma, prisma, prisma, prisma, { PrismaClient }, @prisma/client

### Community 57 - "ticket_html_generator.dart"
Cohesion: 0.17
Nodes (8): charset, class, _formatDateTime, _formatShortDate, generate, _generateQrSvg, lang, TicketHtmlGenerator

### Community 59 - "package:flutter/material.dart"
Cohesion: 0.20
Nodes (4): AsyncActionHelper, extractErrorMessage, run, timeoutDuration

### Community 60 - "app.module.ts"
Cohesion: 0.14
Nodes (10): AdminModule, AuthModule, RequirePermissions(), AppConfigModule, GateModule, NotificationsModule, ApprovalsController, OutpassModule (+2 more)

### Community 61 - "Architecture"
Cohesion: 0.22
Nodes (8): Architectural Constraints, Architecture, Data Flow, Key Abstractions, Layers, Pattern Overview, Primary Outpass Lifecycle Path, System Overview

### Community 62 - "ApiClient"
Cohesion: 0.40
Nodes (5): ApiClient, MockAdminApiClient, MockTestApiClient, MockOutpassApiClient, MockResponsiveApiClient

### Community 63 - "ticket_outpass_widget_test.dart"
Cohesion: 0.12
Nodes (8): createOutpass, lastCreatedOutpass, main, createWidgetUnderTest, emergencyOutpass, main, normalOutpass, testState

### Community 64 - "admin_roles_workflows.dart"
Cohesion: 0.05
Nodes (35): _active, _availablePermissions, build, _busy, categories, CategoryFormDialog, _CategoryFormDialogState, _chain (+27 more)

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
Cohesion: 0.10
Nodes (18): approved, cancelled, completed, emergency, exited, expired, hod, isPending (+10 more)

### Community 74 - "OutpassStatus"
Cohesion: 0.11
Nodes (17): OutpassStatus, APPROVED, CANCELLED, COMPLETED, EXITED, EXPIRED, OVERDUE, PENDING_HOD (+9 more)

### Community 75 - "AllExceptionsFilter"
Cohesion: 0.13
Nodes (11): AllExceptionsFilter, GuardRateLimitState, bootstrap(), Entry Points, APIs & External Services, CI/CD & Deployment, Data Storage, Environment Configuration (+3 more)

### Community 78 - "Phase 1: Core Lifecycle & Gate Security Hardening - Context"
Cohesion: 0.12
Nodes (15): Architecture & Security Specs, Canonical References, Deferred Ideas, Established Patterns, Existing Code Insights, Gate Scanner Verdict Overlay & Feedback, Guard Shift & Location Management, Implementation Decisions (+7 more)

### Community 79 - "AuthService"
Cohesion: 0.33
Nodes (4): AuthService, FirebaseAuthService, @nestjs/config, @nestjs/jwt

### Community 80 - "printed_receipt_reveal.dart"
Cohesion: 0.03
Nodes (54): build, _build3DPrinterBody, _buildStatusLed, child, clearPassFromSession, color, _controller, createState (+46 more)

### Community 81 - "verify-gate-return-flow.cjs"
Cohesion: 0.28
Nodes (7): crypto, http, post(), prisma, { PrismaClient }, run(), uuid()

### Community 82 - "responsive_overflow_test.dart"
Cohesion: 0.12
Nodes (14): adminGetAuditLog, adminGetDepartments, adminGetOutpasses, adminGetSettings, adminGetUsers, delete, guardScans, main (+6 more)

### Community 84 - "Christ College of Engineering (CCE) Digital Outpass System"
Cohesion: 0.17
Nodes (11): Active, Business Context, Christ College of Engineering (CCE) Digital Outpass System, Constraints, Context, Core Value, Key Decisions, Out of Scope (+3 more)

### Community 85 - "v1 Requirements"
Cohesion: 0.17
Nodes (11): Authentication & Device Binding, Communications & Alerts, Faculty Approval Workflow, Gate Clearance & Security, Operations & Reliability, Outpass Request & Student Portal, Requirements: CCE Digital Outpass System, Specialized Approvals (+3 more)

### Community 86 - "Synthesized Decisions"
Cohesion: 0.18
Nodes (10): ADR-01: Framework and Architecture, ADR-02: Flutter Web & Multi-Platform Support, ADR-03: ECDSA P-256 Device Keys, ADR-04: Rotating QR Token Specification, ADR-05: DER Signature Encoding, ADR-06: Atomic Database Transitions, ADR-07: Authentication & OTP, ADR-08: Validity Window Calculation (+2 more)

### Community 87 - "scripts"
Cohesion: 0.20
Nodes (10): scripts, build, lint, prisma:deploy, prisma:generate, prisma:migrate, seed, start (+2 more)

### Community 88 - "Phase Details"
Cohesion: 0.22
Nodes (8): Overview, Phase 1: Core Lifecycle & Gate Security Hardening, Phase 2: Administrative Modularization & Academic Controls, Phase 3: Multi-Channel Notifications, Phase 4: Warden Stage & Offline Gate Scanning, Phase Details, Phases, Roadmap: Christ College of Engineering (CCE) Digital Outpass System

### Community 90 - "verify-qr-token-scan.cjs"
Cohesion: 0.29
Nodes (6): crypto, http, post(), prisma, { PrismaClient }, run()

### Community 92 - "verify-e2e-walkthrough.cjs"
Cohesion: 0.48
Nodes (6): get(), loginAs(), post(), prisma, { PrismaClient }, run()

### Community 93 - "verify-hod-registration-flow.cjs"
Cohesion: 0.48
Nodes (6): get(), loginAs(), post(), prisma, { PrismaClient }, run()

### Community 94 - "verify-tutor-approval-flow.cjs"
Cohesion: 0.48
Nodes (6): get(), loginAs(), post(), prisma, { PrismaClient }, run()

### Community 97 - "Testing Patterns"
Cohesion: 0.29
Nodes (6): Coverage & Quality Verification, Mocking, Test File Organization, Test Framework, Test Structure, Testing Patterns

### Community 98 - "Onboarding Summary"
Cohesion: 0.33
Nodes (5): Codebase Context, Docs Context, Onboarding Summary, Project State, Recommended Next Step

### Community 99 - "Project State"
Cohesion: 0.33
Nodes (5): Current Position, Decisions Log, Performance Metrics, Project Reference, Project State

### Community 100 - "migrate-pass-codes.ts"
Cohesion: 0.60
Nodes (4): generateRandomPassCode(), getUniquePassCode(), migrate(), prisma

### Community 101 - "Ingest Conflicts Report"
Cohesion: 0.40
Nodes (4): BLOCKERS (0), INFO (12), Ingest Conflicts Report, WARNINGS (0)

### Community 102 - "Plan 01-02: Guard Verdict UX & Ticket Invalidation Integration"
Cohesion: 0.40
Nodes (4): Objective, Plan 01-02: Guard Verdict UX & Ticket Invalidation Integration, STRIDE Threat Register, Trust Boundaries

### Community 106 - "Synthesized Requirements"
Cohesion: 0.50
Nodes (3): Deferred to Subsequent Milestones, Synthesized Requirements, Validated / Implemented MVP Scope

### Community 107 - "Document Synthesis"
Cohesion: 0.50
Nodes (3): Document Synthesis, Ingest Summary, Project Overview

### Community 108 - "CustomPainter"
Cohesion: 0.50
Nodes (3): _PaperGrainPainter, _PrinterVentGrillePainter, _ZigZagTornEdgePainter

## Knowledge Gaps
- **744 isolated node(s):** `@nestjs/passport`, `@nestjs/platform-express`, `passport`, `passport-jwt`, `rxjs` (+739 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1220 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **24 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `@prisma/client` connect `@prisma/client` to `migrate-pass-codes.ts`, `check-counts.cjs`, `bootstrap-admin.cjs`, `PrismaService`, `inspect-db.cjs`, `package.json`, `verify-gate-return-flow.cjs`, `seed-dynamic-data.cjs`, `@nestjs/common`, `verify-tutor-approval-flow.cjs`, `verify-qr-token-scan.cjs`, `verify-e2e-walkthrough.cjs`, `verify-hod-registration-flow.cjs`, `backup-all.cjs`?**
  _High betweenness centrality (0.034) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `OutpassService` (e.g. with `Component Responsibilities` and `Primary Outpass Lifecycle Path`) actually correct?**
  _`OutpassService` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `@nestjs/passport`, `@nestjs/platform-express`, `passport` to the rest of the system?**
  _744 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `phone_normalization_and_router_test.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.125 - nodes in this community are weakly interconnected._
- **Why does `@nestjs/common` connect `@nestjs/common` to `GateService`, `api-audit.spec.ts`, `normalizeMobile`, `PrismaService`, `gate.e2e-spec.ts`, `AllExceptionsFilter`, `AuthService`, `package.json`, `app.module.ts`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._
- **Should `OutpassService` be split into smaller, more focused modules?**
  _Cohesion score 0.05605499735589635 - nodes in this community are weakly interconnected._
- **Why does `normalizeMobile()` connect `normalizeMobile` to `AdminController`, `CCE Outpass — Comprehensive Project Onboarding Report`, `Phase 1: Core Lifecycle & Gate Security Hardening - Context`, `AuthService`, `@nestjs/common`, `Architecture`?**
  _High betweenness centrality (0.025) - this node is a cross-community bridge._