---
last_mapped_commit: c4fce159181245c0e342cc4825e08bf487a2910c
last_mapped_at: 2026-10-11
---
# Testing Patterns

**Analysis Date:** 2026-10-11

## Test Framework

**Backend (`apps/api`):**
- Runner: Jest 29.7.0 (`apps/api/package.json`)
- Config: Embedded in `package.json` and `apps/api/test/jest-e2e.json`
- Assertion Library: Jest `expect()` and Supertest `expect()`
- Commands:
  ```bash
  npm run test          # Run all API unit/integration tests
  npm run test:e2e      # Run API end-to-end integration tests
  npm run lint          # Run TypeScript static check
  ```

**Frontend (`apps/mobile`):**
- Runner: Flutter Test SDK
- Assertion Library: `package:flutter_test` matchers (`find.byType`, `find.text`, `expect(find..., findsOneWidget)`)
- Commands:
  ```bash
  flutter test          # Run all Flutter widget and unit tests
  flutter analyze       # Run static analysis and linting
  ```

**Verification Scripts:**
- Direct Node.js integration verification scripts in workspace root:
  ```bash
  node verify-gate-return-flow.cjs
  node verify-qr-token-scan.cjs
  node verify-e2e-walkthrough.cjs
  node verify-tutor-approval-flow.cjs
  node verify-hod-registration-flow.cjs
  ```

## Test File Organization

**Backend:**
- Unit & Audit Specs: Co-located next to implementation files (e.g., `apps/api/src/admin/admin-student-registration.spec.ts`, `apps/api/src/api-audit.spec.ts`).
- E2E Tests: Located in dedicated `apps/api/test/` directory (`apps/api/test/gate.e2e-spec.ts`).

**Frontend:**
- Located in `apps/mobile/test/` directory (`admin_register_person_test.dart`, `ticket_outpass_widget_test.dart`, `phone_normalization_and_router_test.dart`).

## Test Structure

**Backend Spec Example:**

```typescript
describe('AdminStudentRegistration', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    await app.init();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  it('creates student without tutor and saves tutorId as null', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/admin/users')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: 'Sayanth',
        mobile: '9895061553',
        role: 'STUDENT',
        department: 'CE',
        year: 1,
      });

    expect(res.status).toBe(201);
    expect(res.body.student.tutorId).toBeNull();
  });
});
```

**Flutter Widget Test Example:**

```dart
testWidgets('TicketOutpass displays institutional header and pass ID', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TicketOutpass(
          outpass: mockOutpassData,
          deviceKeys: mockDeviceKeys,
        ),
      ),
    ),
  );

  expect(find.text('CHRIST COLLEGE OF ENGINEERING'), findsOneWidget);
  expect(find.text('CCE-OP-8921'), findsOneWidget);
  expect(find.byType(CustomPaint), findsWidgets);
});
```

## Mocking

**API Testing:**
- Use `Test.createTestingModule` from `@nestjs/testing`.
- Replace external services (e.g. Firebase Admin Auth) with test stubs (`useTestFirebaseAuth()`).

**Flutter Testing:**
- Subclass `ApiClient` to provide fake test data (`MockAdminApiClient`, `MockOutpassApiClient`).
- Use `FakeSecureStorage` to test hardware key persistence in unit tests without touching actual hardware Keystore.

## Coverage & Quality Verification

**Status:**
- Backend: 6 test suites passing, 51 tests passed, 0 lint errors.
- Frontend: 19 widget and unit tests passing, 0 analyzer issues.
- Verification: End-to-end multi-role lifecycle walkthrough verified via automated scripts.

---

*Testing analysis: 2026-10-11*
