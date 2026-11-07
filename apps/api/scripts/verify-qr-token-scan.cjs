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

async function run() {
  console.log('Testing cryptographic QR token scan for EXIT and CAMPUS RETURN...');

  // Generate ECDSA P-256 key pair
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ec', {
    namedCurve: 'prime256v1',
    publicKeyEncoding: { type: 'spki', format: 'pem' },
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  });

  const student = await prisma.user.findFirst({ where: { roleId: 'student' } });
  // Register or ensure device for student
  let device = await prisma.device.findFirst({ where: { userId: student.id, revokedAt: null } });
  if (device) {
    device = await prisma.device.update({
      where: { id: device.id },
      data: { publicKey },
    });
  } else {
    device = await prisma.device.create({
      data: {
        userId: student.id,
        platform: 'web',
        publicKey,
      },
    });
  }

  // Create an approved outpass
  const now = new Date();
  const outpass = await prisma.outpassRequest.create({
    data: {
      displayId: 'OP-QR-' + Date.now(),
      passCode: 'QR' + Math.floor(1000 + Math.random() * 9000),
      studentId: student.id,
      studentUserId: student.id,
      type: 'NORMAL',
      status: 'APPROVED',
      destination: 'Campus Lab',
      purposeCategory: 'Academic',
      requestedExitAt: now,
      expectedReturnAt: new Date(now.getTime() + 2 * 60 * 60 * 1000),
      validFrom: new Date(now.getTime() - 10 * 60 * 1000),
      validUntil: new Date(now.getTime() + 4 * 60 * 60 * 1000),
    },
  });

  // Admin login for guard scan
  const admin = await prisma.user.findFirst({ where: { roleId: 'admin' } });
  const adminLogin = await post('/auth/otp/verify', { mobile: admin.mobile, code: '123456' });
  const guardToken = adminLogin.body.accessToken;

  // Build exit QR token: v1.<outpassId>.<ts>.<sig>
  const nowSec = Math.floor(Date.now() / 1000);
  const ts = Math.floor(nowSec / 30) * 30;
  const message = `v1.${outpass.id}.${ts}`;
  const sign = crypto.createSign('SHA256');
  sign.update(message);
  sign.end();
  const sig = sign.sign(privateKey);
  const sigB64 = sig.toString('base64url');
  const token = `${message}.${sigB64}`;

  // 1. Scan EXIT
  console.log('1. Scanning EXIT with QR token...');
  const exitRes = await post(
    '/gate/scans',
    {
      token,
      direction: 'EXIT',
      gateId: 'main-gate',
      clientScanId: crypto.randomUUID(),
    },
    guardToken,
  );
  console.log('   Exit Scan Result:', exitRes.body.result, '| Message:', exitRes.body.message);
  if (exitRes.body.result !== 'OK_EXIT') {
    throw new Error('Exit scan failed: ' + JSON.stringify(exitRes.body));
  }
  console.log('   PASS: Exit QR scan succeeded with OK_EXIT!\n');

  // Set exitAt to 15 minutes ago to satisfy dwell time
  await prisma.outpassRequest.update({
    where: { id: outpass.id },
    data: { exitAt: new Date(Date.now() - 15 * 60 * 1000) },
  });

  // 2. Scan CAMPUS RETURN with a fresh QR token
  console.log('2. Scanning CAMPUS RETURN with a fresh QR token...');
  const returnNowSec = Math.floor(Date.now() / 1000);
  const returnTs = Math.floor(returnNowSec / 30) * 30;
  const returnMessage = `v1.${outpass.id}.${returnTs}`;
  const returnSign = crypto.createSign('SHA256');
  returnSign.update(returnMessage);
  returnSign.end();
  const returnSig = returnSign.sign(privateKey);
  const returnSigB64 = returnSig.toString('base64url');
  const returnToken = `${returnMessage}.${returnSigB64}`;

  const returnRes = await post(
    '/gate/scans',
    {
      token: returnToken,
      direction: 'ENTRY',
      gateId: 'main-gate',
      clientScanId: crypto.randomUUID(),
    },
    guardToken,
  );
  console.log('   Return Scan Result:', returnRes.body.result, '| Message:', returnRes.body.message);
  if (returnRes.body.result !== 'OK_ENTRY') {
    throw new Error('Return scan failed: ' + JSON.stringify(returnRes.body));
  }
  console.log('   PASS: Return QR scan succeeded with OK_ENTRY (NO QR_STALE)!\n');

  console.log('QR SCAN FLOW VERIFIED SUCCESSFULLY!');
}

run()
  .catch((e) => {
    console.error('QR SCAN TEST FAILED:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
