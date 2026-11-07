const { PrismaClient } = require('@prisma/client');
const crypto = require('crypto');
const http = require('http');

const prisma = new PrismaClient();
const API_BASE = 'http://localhost:3000/v1';

function post(path, body, token) {
  return new Promise((resolve, reject) => {
    const url = new URL(API_BASE + path);
    const data = JSON.stringify(body);
    const headers = {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(data),
    };
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const req = http.request(
      url,
      { method: 'POST', headers },
      (res) => {
        let raw = '';
        res.on('data', (c) => (raw += c));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, body: JSON.parse(raw) });
          } catch (e) {
            resolve({ status: res.statusCode, body: raw });
          }
        });
      },
    );
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

function get(path, token) {
  return new Promise((resolve, reject) => {
    const url = new URL(API_BASE + path);
    const headers = {};
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const req = http.request(url, { method: 'GET', headers }, (res) => {
      let raw = '';
      res.on('data', (c) => (raw += c));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(raw) });
        } catch (e) {
          resolve({ status: res.statusCode, body: raw });
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

function uuid() {
  return crypto.randomUUID();
}

async function run() {
  console.log('====================================================');
  console.log('STARTING GATE CAMPUS RETURN & MANUAL ENTRY TEST SUITE');
  console.log('====================================================\n');

  // 1. Guard Login
  console.log('1. Logging in as Security Guard (mobile: 8921578834)...');
  const guardLogin = await post('/auth/otp/verify', { mobile: '8921578834', code: '123456' });
  if (!guardLogin.body.accessToken) {
    throw new Error('Guard login failed: ' + JSON.stringify(guardLogin.body));
  }
  const guardToken = guardLogin.body.accessToken;
  console.log('   Guard login successful! Guard token obtained.\n');

  // 2. Start Guard Shift
  console.log('2. Starting guard shift at main-gate...');
  const shiftRes = await post('/gate/session/start', { gateId: 'main-gate' }, guardToken);
  console.log('   Shift status:', shiftRes.status, shiftRes.body.gate?.name);

  // 3. Test Manual Entry - NOT_FOUND
  console.log('\n3. Testing Manual Entry with unknown code (expecting NOT_FOUND)...');
  const badCodeRes = await post(
    '/gate/manual-entry',
    {
      code: 'ZZZZZZ',
      direction: 'ENTRY',
      gateId: 'main-gate',
      clientScanId: uuid(),
    },
    guardToken,
  );
  console.log('   Result:', badCodeRes.body.result, '| Message:', badCodeRes.body.message);
  if (badCodeRes.body.result !== 'NOT_FOUND') {
    throw new Error('Expected NOT_FOUND but got ' + badCodeRes.body.result);
  }
  console.log('   PASS: NOT_FOUND correctly returned with friendly message.\n');

  // 4. Test Lockout after 5 wrong attempts
  console.log('4. Testing Guard Lockout (5 consecutive wrong codes)...');
  // We already did 1 bad attempt above. Let's do 4 more.
  for (let i = 2; i <= 4; i++) {
    await post(
      '/gate/manual-entry',
      { code: `WRONG${i}`, direction: 'EXIT', gateId: 'main-gate', clientScanId: uuid() },
      guardToken,
    );
  }
  const fifthAttempt = await post(
    '/gate/manual-entry',
    { code: 'WRONG5', direction: 'EXIT', gateId: 'main-gate', clientScanId: uuid() },
    guardToken,
  );
  console.log('   5th Attempt Result:', fifthAttempt.body.result, '| Message:', fifthAttempt.body.message);
  if (fifthAttempt.body.result !== 'LOCKOUT') {
    throw new Error('Expected LOCKOUT on 5th attempt, got ' + fifthAttempt.body.result);
  }
  console.log('   PASS: Guard locked out for rate limit!\n');

  // Reset lockout for next test steps (by clearing lockouts in DB or restarting/clearing service)
  // Let's create a fresh outpass in DB to test complete Exit and Return flow
  console.log('5. Creating fresh APPROVED outpass for Exit & Campus Return testing...');
  const student = await prisma.user.findFirst({ where: { roleId: 'student' } });
  if (!student) throw new Error('Student user not found');

  const now = new Date();
  const testPassCode = 'TST' + Math.floor(100 + Math.random() * 900);
  const testDisplayId = 'OP-TEST-' + Date.now();

  const outpass = await prisma.outpassRequest.create({
    data: {
      displayId: testDisplayId,
      passCode: testPassCode,
      studentId: student.id,
      studentUserId: student.id,
      type: 'NORMAL',
      status: 'APPROVED',
      destination: 'Thrissur Town',
      purposeCategory: 'Academic',
      requestedExitAt: now,
      expectedReturnAt: new Date(now.getTime() + 2 * 60 * 60 * 1000), // 2 hours later
      validFrom: new Date(now.getTime() - 10 * 60 * 1000),
      validUntil: new Date(now.getTime() + 4 * 60 * 60 * 1000),
    },
  });
  console.log(`   Created test outpass ${outpass.displayId} with Pass Code: ${outpass.passCode}\n`);

  // To test manual entry without lockout, let's login with another guard or admin who has gateScan permission
  // Admin has gateScan permission! Let's check admin user:
  const admin = await prisma.user.findFirst({ where: { roleId: 'admin' } });
  const adminLogin = await post('/auth/otp/verify', { mobile: admin.mobile, code: '123456' });
  const activeGuardToken = adminLogin.body.accessToken;

  // 6. Test EXIT via Manual Entry
  console.log(`6. Testing EXIT via Manual Pass Code (${outpass.passCode})...`);
  const exitRes = await post(
    '/gate/manual-entry',
    {
      code: outpass.passCode,
      direction: 'EXIT',
      gateId: 'main-gate',
      clientScanId: uuid(),
    },
    activeGuardToken,
  );
  console.log('   Exit Result:', exitRes.body.result, '| Message:', exitRes.body.message);
  if (exitRes.body.result !== 'OK_EXIT') {
    throw new Error('Expected OK_EXIT, got ' + exitRes.body.result);
  }
  const dbAfterExit = await prisma.outpassRequest.findUnique({ where: { id: outpass.id } });
  console.log('   Database Status after Exit:', dbAfterExit.status, '| exitAt:', dbAfterExit.exitAt);
  if (dbAfterExit.status !== 'EXITED') {
    throw new Error('Database status was not updated to EXITED');
  }
  console.log('   PASS: OK_EXIT recorded and EXITED status stored in database!\n');

  // 7. Test Duplicate Exit -> ALREADY_USED with IST time
  console.log('7. Testing Duplicate Exit Scan (expecting ALREADY_USED with IST time)...');
  const dupExitRes = await post(
    '/gate/manual-entry',
    {
      code: outpass.passCode,
      direction: 'EXIT',
      gateId: 'main-gate',
      clientScanId: uuid(),
    },
    activeGuardToken,
  );
  console.log('   Duplicate Exit Result:', dupExitRes.body.result, '| Message:', dupExitRes.body.message);
  if (dupExitRes.body.result !== 'ALREADY_USED') {
    throw new Error('Expected ALREADY_USED, got ' + dupExitRes.body.result);
  }
  if (!dupExitRes.body.message.includes('already used at')) {
    throw new Error('Expected message to contain IST time, got: ' + dupExitRes.body.message);
  }
  console.log('   PASS: Duplicate exit rejected with ALREADY_USED and formatted IST time!\n');

  // 8. Test Campus Return too early -> MIN_DWELL with remaining time message
  console.log('8. Testing Campus Return immediately after exit (expecting MIN_DWELL)...');
  const dwellRes = await post(
    '/gate/manual-entry',
    {
      code: outpass.passCode,
      direction: 'ENTRY',
      gateId: 'main-gate',
      clientScanId: uuid(),
    },
    activeGuardToken,
  );
  console.log('   Dwell Result:', dwellRes.body.result, '| Message:', dwellRes.body.message);
  if (dwellRes.body.result !== 'MIN_DWELL') {
    throw new Error('Expected MIN_DWELL, got ' + dwellRes.body.result);
  }
  if (!dwellRes.body.message.includes('Too early. Return allowed in')) {
    throw new Error('Expected friendly remaining time message, got: ' + dwellRes.body.message);
  }
  console.log('   PASS: MIN_DWELL rejected with friendly remaining-time message!\n');

  // 9. Test Campus Return after Dwell Time -> OK_ENTRY (No QR_STALE)
  console.log('9. Simulating dwell time elapsed and testing Campus Return via Pass Code...');
  // Set exitAt to 15 minutes in the past
  await prisma.outpassRequest.update({
    where: { id: outpass.id },
    data: { exitAt: new Date(Date.now() - 15 * 60 * 1000) },
  });

  const returnRes = await post(
    '/gate/manual-entry',
    {
      code: outpass.passCode,
      direction: 'ENTRY',
      gateId: 'main-gate',
      clientScanId: uuid(),
    },
    activeGuardToken,
  );
  console.log('   Return Result:', returnRes.body.result, '| Message:', returnRes.body.message);
  if (returnRes.body.result !== 'OK_ENTRY') {
    throw new Error('Expected OK_ENTRY, got ' + returnRes.body.result);
  }
  const dbAfterReturn = await prisma.outpassRequest.findUnique({ where: { id: outpass.id } });
  console.log('   Database Status after Return:', dbAfterReturn.status, '| entryAt:', dbAfterReturn.entryAt);
  if (dbAfterReturn.status !== 'RETURNED') {
    throw new Error('Database status was not updated to RETURNED');
  }
  console.log('   PASS: Campus return successfully accepted and status is RETURNED (NO QR_STALE)!\n');

  // 10. Test Duplicate Return Scan -> ALREADY_USED
  console.log('10. Testing Duplicate Return Scan (expecting ALREADY_USED)...');
  const dupReturnRes = await post(
    '/gate/manual-entry',
    {
      code: outpass.passCode,
      direction: 'ENTRY',
      gateId: 'main-gate',
      clientScanId: uuid(),
    },
    activeGuardToken,
  );
  console.log('   Duplicate Return Result:', dupReturnRes.body.result, '| Message:', dupReturnRes.body.message);
  if (dupReturnRes.body.result !== 'ALREADY_USED') {
    throw new Error('Expected ALREADY_USED, got ' + dupReturnRes.body.result);
  }
  console.log('   PASS: Duplicate return correctly rejected with ALREADY_USED!\n');

  // 11. Test LATE RETURN
  console.log('11. Testing Late Return acceptance and flagging...');
  const latePassCode = 'LTE' + Math.floor(100 + Math.random() * 900);
  const lateOutpass = await prisma.outpassRequest.create({
    data: {
      displayId: 'OP-LATE-' + Date.now(),
      passCode: latePassCode,
      studentId: student.id,
      studentUserId: student.id,
      type: 'NORMAL',
      status: 'EXITED',
      exitAt: new Date(Date.now() - 120 * 60 * 1000), // Exited 2 hours ago
      expectedReturnAt: new Date(Date.now() - 30 * 60 * 1000), // Was expected to return 30 mins ago
      validUntil: new Date(Date.now() - 30 * 60 * 1000),
      destination: 'Hospital',
      purposeCategory: 'Medical',
      requestedExitAt: new Date(Date.now() - 120 * 60 * 1000),
    },
  });

  const lateReturnRes = await post(
    '/gate/manual-entry',
    {
      code: lateOutpass.passCode,
      direction: 'ENTRY',
      gateId: 'main-gate',
      clientScanId: uuid(),
    },
    activeGuardToken,
  );
  console.log('   Late Return Result:', lateReturnRes.body.result, '| Message:', lateReturnRes.body.message);
  console.log('   Late details:', lateReturnRes.body.outpass?.isLate, '| Late minutes:', lateReturnRes.body.outpass?.lateMinutes);
  if (lateReturnRes.body.result !== 'OK_ENTRY') {
    throw new Error('Expected OK_ENTRY for late return, got ' + lateReturnRes.body.result);
  }
  if (!lateReturnRes.body.outpass?.isLate) {
    throw new Error('Expected isLate to be true');
  }
  const dbAfterLate = await prisma.outpassRequest.findUnique({ where: { id: lateOutpass.id } });
  console.log('   DB isLate:', dbAfterLate.isLate, '| lateMinutes:', dbAfterLate.lateMinutes);
  if (!dbAfterLate.isLate || dbAfterLate.lateMinutes <= 0) {
    throw new Error('Database isLate or lateMinutes was not stored correctly');
  }
  console.log('   PASS: Late return accepted and flagged with lateMinutes in database!\n');

  console.log('====================================================');
  console.log('ALL VERIFICATION TESTS COMPLETED SUCCESSFULLY!');
  console.log('====================================================');
}

run()
  .catch((e) => {
    console.error('TEST FAILED:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
