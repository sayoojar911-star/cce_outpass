import { Test } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma.service';
import { login, newKeyPair, useTestFirebaseAuth } from './helpers';

const T = { student: '9111111101', tutor: '9111111102', hod: '9111111103', tutor2: '9111111104', student2: '9111111105' };

describe('Outpass approval flow (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let studentTok: string, student2Tok: string, tutorTok: string, hodTok: string, tutor2Tok: string;

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

    // Clean any previous run, then seed the fixture users
    const old = await prisma.user.findMany({ where: { mobile: { startsWith: '91111111' } } });
    const oldIds = old.map((u) => u.id);
    await prisma.gateEvent.deleteMany({ where: { guardId: { in: oldIds } } });
    await prisma.approval.deleteMany({ where: { request: { studentId: { in: oldIds } } } });
    await prisma.outpassRequest.deleteMany({ where: { studentId: { in: oldIds } } });
    await prisma.student.deleteMany({ where: { userId: { in: oldIds } } });
    await prisma.session.deleteMany({ where: { userId: { in: oldIds } } });
    await prisma.device.deleteMany({ where: { userId: { in: oldIds } } });
    await prisma.notification.deleteMany({ where: { userId: { in: oldIds } } });
    await prisma.user.deleteMany({ where: { id: { in: oldIds } } });

    const mkStudent = async (mobile: string, registerNo: string, tutorId?: string) => {
      const u = await prisma.user.create({
        data: { name: 'Test Student', role: 'STUDENT', mobile, department: 'CSE' },
      });
      await prisma.student.create({
        data: { userId: u.id, registerNo, department: 'CSE', semester: 3, tutorId },
      });
      return u;
    };
    const tutor = await prisma.user.create({
      data: { name: 'Test Tutor', role: 'TUTOR', mobile: T.tutor, department: 'CSE' },
    });
    await prisma.user.create({
      data: { name: 'Test HOD', role: 'HOD', mobile: T.hod, department: 'CSE' },
    });
    await prisma.user.create({
      data: { name: 'Other Tutor', role: 'TUTOR', mobile: T.tutor2, department: 'ECE' },
    });
    await mkStudent(T.student, 'CCE99TEST01', tutor.id);
    await mkStudent(T.student2, 'CCE99TEST03', tutor.id);

    studentTok = await login(app, T.student);
    student2Tok = await login(app, T.student2);
    tutorTok = await login(app, T.tutor);
    hodTok = await login(app, T.hod);
    tutor2Tok = await login(app, T.tutor2);

    // Device key so the flow can reach APPROVED
    const { pem } = newKeyPair();
    await request(app.getHttpServer())
      .post('/v1/auth/device/register')
      .set('Authorization', `Bearer ${studentTok}`)
      .send({ publicKeyPem: pem, platform: 'test' })
      .expect(201);
  });

  afterAll(async () => {
    await app.close();
  });

  const createOutpass = (tok: string) =>
    request(app.getHttpServer())
      .post('/v1/outpasses')
      .set('Authorization', `Bearer ${tok}`)
      .send({
        requestedExitAt: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
        expectedReturnAt: new Date(Date.now() + 3 * 60 * 60 * 1000).toISOString(),
        destination: 'Irinjalakuda Medical Centre',
        purposeCategory: 'Medical',
        purposeText: 'Dental appointment',
      });

  let outpassId: string;

  it('student creates an outpass → PENDING_TUTOR', async () => {
    const res = await createOutpass(studentTok).expect(201);
    expect(res.body.status).toBe('PENDING_TUTOR');
    expect(res.body.displayId).toMatch(/^OP\d{12}$/);
    outpassId = res.body.id;
  });

  it('blocks a second overlapping request (PRD §14)', async () => {
    await createOutpass(studentTok).expect(409);
  });

  it('unmapped tutor cannot see or decide the request', async () => {
    await request(app.getHttpServer())
      .get('/v1/approvals/pending')
      .set('Authorization', `Bearer ${tutor2Tok}`)
      .expect(200)
      .then((r) => {
        expect(r.body.find((o: any) => o.id === outpassId)).toBeUndefined();
      });
    await request(app.getHttpServer())
      .post(`/v1/approvals/${outpassId}/decision`)
      .set('Authorization', `Bearer ${tutor2Tok}`)
      .send({ decision: 'APPROVED' })
      .expect(403);
  });

  it('concurrent tutor decisions → exactly one wins, other gets 409', async () => {
    const body = { decision: 'APPROVED', comment: 'ok' };
    const [a, b] = await Promise.all([
      request(app.getHttpServer())
        .post(`/v1/approvals/${outpassId}/decision`)
        .set('Authorization', `Bearer ${tutorTok}`)
        .send(body),
      request(app.getHttpServer())
        .post(`/v1/approvals/${outpassId}/decision`)
        .set('Authorization', `Bearer ${tutorTok}`)
        .send(body),
    ]);
    const codes = [a.status, b.status].sort();
    expect(codes).toEqual([201, 409]);
    const one = a.status === 201 ? a : b;
    expect(one.body.status).toBe('PENDING_HOD');
  });

  it('HOD approval → APPROVED with validity window and recorded approval', async () => {
    const res = await request(app.getHttpServer())
      .post(`/v1/approvals/${outpassId}/decision`)
      .set('Authorization', `Bearer ${hodTok}`)
      .send({ decision: 'APPROVED', comment: 'Approved' })
      .expect(201);
    expect(res.body.status).toBe('APPROVED');
    expect(new Date(res.body.validUntil).getTime()).toBeGreaterThan(Date.now());
    // tutor (earlier in this spec) + HOD
    expect(res.body.approvals).toHaveLength(2);
  });

  it('students cannot access approver routes', async () => {
    await request(app.getHttpServer())
      .get('/v1/approvals/pending')
      .set('Authorization', `Bearer ${studentTok}`)
      .expect(403);
  });

  it('reject without reason is refused; with reason → REJECTED (student2)', async () => {
    const r = await createOutpass(student2Tok).expect(201);
    await request(app.getHttpServer())
      .post(`/v1/approvals/${r.body.id}/decision`)
      .set('Authorization', `Bearer ${tutorTok}`)
      .send({ decision: 'REJECTED' })
      .expect(409);
    await request(app.getHttpServer())
      .post(`/v1/approvals/${r.body.id}/decision`)
      .set('Authorization', `Bearer ${tutorTok}`)
      .send({ decision: 'REJECTED', comment: 'Internal examination scheduled' })
      .expect(201)
      .then((res: any) => expect(res.body.status).toBe('REJECTED'));
  });

  it('student cancels a fresh request → CANCELLED (student2)', async () => {
    const r = await createOutpass(student2Tok).expect(201);
    await request(app.getHttpServer())
      .post(`/v1/outpasses/${r.body.id}/cancel`)
      .set('Authorization', `Bearer ${student2Tok}`)
      .send({ reason: 'Plans changed' })
      .expect(201)
      .then((res: any) => expect(res.body.ok).toBe(true));
    await request(app.getHttpServer())
      .get(`/v1/outpasses/${r.body.id}`)
      .set('Authorization', `Bearer ${student2Tok}`)
      .expect(200)
      .then((res: any) => expect(res.body.status).toBe('CANCELLED'));
  });

  it('students see their own history with timeline', async () => {
    const res = await request(app.getHttpServer())
      .get('/v1/outpasses')
      .set('Authorization', `Bearer ${studentTok}`)
      .expect(200);
    expect(res.body.length).toBeGreaterThanOrEqual(1);
    const target = res.body.find((o: any) => o.id === outpassId);
    expect(target.approvals.length).toBeGreaterThanOrEqual(1);
  });
});
