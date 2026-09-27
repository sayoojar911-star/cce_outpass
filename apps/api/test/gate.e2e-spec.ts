import { Test } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma.service';
import { login, newKeyPair, signToken, useTestFirebaseAuth, uuid } from './helpers';

const T = { student: '9111111201', tutor: '9111111202', hod: '9111111203', guard: '9111111204' };
const GATE = 'main-gate';

describe('Gate scan flow (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let studentTok: string, tutorTok: string, hodTok: string, guardTok: string;
  let privKey: any;
  let studentId: string;

  beforeAll(async () => {
    process.env.NODE_ENV = 'development';
    const moduleRef = await useTestFirebaseAuth(
      Test.createTestingModule({ imports: [AppModule] }),
    ).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1');
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
    prisma = app.get(PrismaService);

    const old = await prisma.user.findMany({ where: { mobile: { startsWith: '91111112' } } });
    const oldIds = old.map((u) => u.id);
    await prisma.gateEvent.deleteMany({ where: { OR: [{ guardId: { in: oldIds } }, { outpassId: { not: null } }] } });
    await prisma.approval.deleteMany({ where: { request: { studentId: { in: oldIds } } } });
    await prisma.outpassRequest.deleteMany({ where: { studentId: { in: oldIds } } });
    await prisma.student.deleteMany({ where: { userId: { in: oldIds } } });
    await prisma.session.deleteMany({ where: { userId: { in: oldIds } } });
    await prisma.device.deleteMany({ where: { userId: { in: oldIds } } });
    await prisma.notification.deleteMany({ where: { userId: { in: oldIds } } });
    await prisma.user.deleteMany({ where: { id: { in: oldIds } } });

    const student = await prisma.user.create({
      data: { name: 'Gate Student', role: 'STUDENT', mobile: T.student, department: 'CSE' },
    });
    studentId = student.id;
    await prisma.student.create({
      data: { userId: student.id, registerNo: 'CCE99TEST02', department: 'CSE', semester: 3 },
    });
    const tutor = await prisma.user.create({
      data: { name: 'Gate Tutor', role: 'TUTOR', mobile: T.tutor, department: 'CSE' },
    });
    await prisma.user.create({ data: { name: 'Gate HOD', role: 'HOD', mobile: T.hod, department: 'CSE' } });
    await prisma.user.create({ data: { name: 'Gate Guard', role: 'GUARD', mobile: T.guard } });
    await prisma.student.update({ where: { userId: student.id }, data: { tutorId: tutor.id } });

    studentTok = await login(app, T.student);
    tutorTok = await login(app, T.tutor);
    hodTok = await login(app, T.hod);
    guardTok = await login(app, T.guard);

    const kp = newKeyPair();
    privKey = kp.privateKey;
    await request(app.getHttpServer())
      .post('/v1/auth/device/register')
      .set('Authorization', `Bearer ${studentTok}`)
      .send({ publicKeyPem: kp.pem, platform: 'test' })
      .expect(201);

    await request(app.getHttpServer())
      .post('/v1/gate/session/start')
      .set('Authorization', `Bearer ${guardTok}`)
      .send({ gateId: GATE })
      .expect(201);
  });

  afterAll(async () => {
    await app.close();
  });

  // Keep only one active outpass for the fixture student (overlap rule PRD §14)
  const deactivateActive = () =>
    prisma.outpassRequest.updateMany({
      where: { studentId, status: { in: ['PENDING_TUTOR', 'PENDING_HOD', 'APPROVED', 'EXITED', 'OVERDUE'] } },
      data: { status: 'RETURNED' },
    });

  const createOutpass = () =>
    request(app.getHttpServer())
      .post('/v1/outpasses')
      .set('Authorization', `Bearer ${studentTok}`)
      .send({
        requestedExitAt: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
        expectedReturnAt: new Date(Date.now() + 3 * 60 * 60 * 1000).toISOString(),
        destination: 'Medical Centre',
        purposeCategory: 'Medical',
      });

  async function approveFully(): Promise<string> {
    await deactivateActive();
    const r = await createOutpass().expect(201);
    const id = r.body.id;
    await request(app.getHttpServer())
      .post(`/v1/approvals/${id}/decision`)
      .set('Authorization', `Bearer ${tutorTok}`)
      .send({ decision: 'APPROVED' })
      .expect(201);
    await request(app.getHttpServer())
      .post(`/v1/approvals/${id}/decision`)
      .set('Authorization', `Bearer ${hodTok}`)
      .send({ decision: 'APPROVED' })
      .expect(201);
    return id;
  }

  const scan = (body: object) =>
    request(app.getHttpServer())
      .post('/v1/gate/scans')
      .set('Authorization', `Bearer ${guardTok}`)
      .send(body);

  const nowSec = () => Math.floor(Date.now() / 1000);
  let lastExitedId: string;

  it('pending outpass scanned at the gate → PENDING_TUTOR', async () => {
    await deactivateActive();
    const r = await createOutpass().expect(201);
    const res = await scan({
      token: signToken(privKey, r.body.id, nowSec()),
      direction: 'EXIT',
      gateId: GATE,
      clientScanId: uuid(),
    }).expect(201);
    expect(res.body.result).toBe('PENDING_TUTOR');
  });

  it('stale token (old ts) → QR_STALE with no state change', async () => {
    const id = await approveFully();
    const res = await scan({
      token: signToken(privKey, id, nowSec() - 300),
      direction: 'EXIT',
      gateId: GATE,
      clientScanId: uuid(),
    }).expect(201);
    expect(res.body.result).toBe('QR_STALE');
  });

  it('valid exit scan → OK_EXIT, status EXITED, idempotent replay of scan id', async () => {
    const id = await approveFully();
    const ts = nowSec() - (nowSec() % 30);
    const token = signToken(privKey, id, ts);
    const clientScanId = uuid();
    const res = await scan({ token, direction: 'EXIT', gateId: GATE, clientScanId }).expect(201);
    expect(res.body.result).toBe('OK_EXIT');
    expect(res.body.outpass.student.registerNo).toBe('CCE99TEST02');

    // Idempotency: same client_scan_id → same stored result, no new event
    const res2 = await scan({ token, direction: 'EXIT', gateId: GATE, clientScanId }).expect(201);
    expect(res2.body.result).toBe('OK_EXIT');
    expect(res2.body.replay).toBe(true);
    const events = await prisma.gateEvent.count({ where: { clientScanId } });
    expect(events).toBe(1);

    const db = await prisma.outpassRequest.findUnique({ where: { id } });
    expect(db!.status).toBe('EXITED');
    expect(db!.exitGateId).toBe(GATE);
    lastExitedId = id;
  });

  it('rescanning the same QR in exit mode → ALREADY_USED', async () => {
    const res = await scan({
      token: signToken(privKey, lastExitedId, nowSec()),
      direction: 'EXIT',
      gateId: GATE,
      clientScanId: uuid(),
    }).expect(201);
    expect(res.body.result).toBe('ALREADY_USED');
  });

  it('tampered token → QR_INVALID', async () => {
    const id = await approveFully();
    const token = signToken(privKey, id, nowSec());
    const parts = token.split('.');
    const res = await scan({
      token: `${parts[0]}.${parts[1]}.${parts[2]}.AAAA${parts[3].slice(4)}`,
      direction: 'EXIT',
      gateId: GATE,
      clientScanId: uuid(),
    }).expect(201);
    expect(res.body.result).toBe('QR_INVALID');
  });

  it('unknown outpass id → QR_INVALID', async () => {
    const res = await scan({
      token: signToken(privKey, uuid(), nowSec()),
      direction: 'EXIT',
      gateId: GATE,
      clientScanId: uuid(),
    }).expect(201);
    expect(res.body.result).toBe('QR_INVALID');
  });

  it('entry scan before exit → WRONG_GATE; after a real exit + dwell → OK_ENTRY → RETURNED', async () => {
    const id = await approveFully();
    const token = signToken(privKey, id, nowSec());
    // PRD §7.4: entry only allowed for EXITED/OVERDUE — an approved-but-not-exited pass is WRONG_GATE
    const beforeExit = await scan({
      token,
      direction: 'ENTRY',
      gateId: GATE,
      clientScanId: uuid(),
    }).expect(201);
    expect(beforeExit.body.result).toBe('WRONG_GATE');

    // Real exit scan
    const exit = await scan({
      token: signToken(privKey, id, nowSec()),
      direction: 'EXIT',
      gateId: GATE,
      clientScanId: uuid(),
    }).expect(201);
    expect(exit.body.result).toBe('OK_EXIT');

    // Immediate re-entry violates the minimum dwell rule (PRD §6.9)
    const tooSoon = await scan({
      token,
      direction: 'ENTRY',
      gateId: GATE,
      clientScanId: uuid(),
    }).expect(201);
    expect(tooSoon.body.result).toBe('MIN_DWELL');

    // Simulate 11 minutes elapsed since exit
    await prisma.outpassRequest.update({
      where: { id },
      data: {
        exitAt: new Date(Date.now() - 11 * 60 * 1000),
        expectedReturnAt: new Date(Date.now() - 5 * 60 * 1000),
      },
    });
    // Fresh token: the monotonic counter (SEC-QR-05) rejects replayed ts values
    const ok = await scan({
      token: signToken(privKey, id, nowSec() + 30),
      direction: 'ENTRY',
      gateId: GATE,
      clientScanId: uuid(),
    }).expect(201);
    expect(ok.body.result).toBe('OK_ENTRY');
    const db = await prisma.outpassRequest.findUnique({ where: { id } });
    expect(db!.status).toBe('RETURNED');
    expect(db!.entryGateId).toBe(GATE);
  });

  it('second entry after return → ALREADY_USED', async () => {
    const id = await approveFully();
    // put it into RETURNED state directly
    await prisma.outpassRequest.update({
      where: { id },
      data: { status: 'RETURNED', exitAt: new Date(Date.now() - 3 * 60 * 60 * 1000), entryAt: new Date() },
    });
    const res = await scan({
      token: signToken(privKey, id, nowSec() + 30),
      direction: 'ENTRY',
      gateId: GATE,
      clientScanId: uuid(),
    }).expect(201);
    expect(res.body.result).toBe('ALREADY_USED');
  });

  it('concurrent scans of two fresh tokens → exactly one state change wins', async () => {
    const id = await approveFully();
    const t1 = nowSec() - (nowSec() % 30);
    const t2 = t1 + 30;
    const [a, b] = await Promise.all([
      scan({ token: signToken(privKey, id, t1), direction: 'EXIT', gateId: GATE, clientScanId: uuid() }),
      scan({ token: signToken(privKey, id, t2), direction: 'EXIT', gateId: GATE, clientScanId: uuid() }),
    ]);
    const results = [a.body.result, b.body.result].sort();
    expect(results).toEqual(['ALREADY_USED', 'OK_EXIT']);
  });

  it('revoked student device → DEVICE_REVOKED', async () => {
    const id = await approveFully();
    await prisma.device.updateMany({
      where: { userId: studentId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    const res = await scan({
      token: signToken(privKey, id, nowSec()),
      direction: 'EXIT',
      gateId: GATE,
      clientScanId: uuid(),
    }).expect(201);
    expect(res.body.result).toBe('DEVICE_REVOKED');
    // restore device for any later use
    await prisma.device.updateMany({ where: { userId: studentId }, data: { revokedAt: null } });
  });

  it('cancelled outpass → CANCELLED at the gate', async () => {
    await deactivateActive();
    const r = await createOutpass().expect(201);
    await request(app.getHttpServer())
      .post(`/v1/outpasses/${r.body.id}/cancel`)
      .set('Authorization', `Bearer ${studentTok}`)
      .send({})
      .expect(201);
    const res = await scan({
      token: signToken(privKey, r.body.id, nowSec()),
      direction: 'EXIT',
      gateId: GATE,
      clientScanId: uuid(),
    }).expect(201);
    expect(res.body.result).toBe('CANCELLED');
  });

  it('guard sees own scan history; students cannot access gate endpoints', async () => {
    await request(app.getHttpServer())
      .get('/v1/gate/scans/mine')
      .set('Authorization', `Bearer ${guardTok}`)
      .expect(200)
      .then((r) => expect(r.body.length).toBeGreaterThanOrEqual(5));
    await request(app.getHttpServer())
      .post('/v1/gate/scans')
      .set('Authorization', `Bearer ${studentTok}`)
      .send({ token: 'x', direction: 'EXIT', gateId: GATE, clientScanId: uuid() })
      .expect(403);
  });
});
