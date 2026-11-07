const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const BASE_URL = 'http://localhost:3000/v1';

async function post(path, body, token) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${BASE_URL}${path}`, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, ok: res.ok, data };
}

async function get(path, token) {
  const headers = {};
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${BASE_URL}${path}`, { headers });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, ok: res.ok, data };
}

async function loginAs(mobile) {
  const sendRes = await post('/auth/otp/send', { mobile });
  if (!sendRes.ok) throw new Error(`OTP send failed for ${mobile}: ${JSON.stringify(sendRes.data)}`);

  const verifyRes = await post('/auth/otp/verify', {
    mobile,
    code: '123456',
  });
  if (!verifyRes.ok) throw new Error(`OTP verify failed for ${mobile}: ${JSON.stringify(verifyRes.data)}`);
  return {
    token: verifyRes.data.accessToken,
    user: verifyRes.data.user,
  };
}

async function run() {
  console.log('================================================================');
  console.log('E2E VERIFICATION: HOD Registration & Emergency Outpass Routing');
  console.log('================================================================\n');

  // Step 1: Admin Login
  const adminAuth = await loginAs('8921578838');
  console.log(`[Step 1] Admin logged in: ${adminAuth.user.name} (${adminAuth.user.roleId})`);

  // Ensure department ECE exists with no active HOD for Step 2
  let eceDept = await prisma.department.findUnique({ where: { code: 'ECE' } });
  if (!eceDept) {
    eceDept = await prisma.department.create({
      data: {
        code: 'ECE',
        name: 'Electronics and Communication',
        active: true,
      },
    });
  } else {
    // Clear any HOD on ECE to ensure it has no active HOD
    await prisma.user.updateMany({
      where: { department: 'ECE', roleId: 'hod' },
      data: { active: false, status: 'INACTIVE' },
    });
    await prisma.department.update({
      where: { code: 'ECE' },
      data: { hodUserId: null, hodId: null },
    });
  }
  console.log(`[Step 2 Setup] Department ECE initialized with no HOD.`);

  // Clean up any test users from prior runs
  await prisma.user.deleteMany({
    where: {
      mobile: { in: ['9876500001', '9876500002', '9876500003'] },
    },
  });

  // Step 2: Register HOD for department with NO HOD
  console.log('\n--- Step 2: Register HOD for department with NO HOD (ECE) ---');
  const eceHodPayload = {
    name: 'Prof. ECE HOD',
    mobile: '9876500001',
    roleId: 'hod',
    role: 'Head of Department',
    department: 'ECE',
    departmentId: eceDept.id,
  };

  const regEceRes = await post('/admin/users', eceHodPayload, adminAuth.token);
  console.log(`Register ECE HOD Response: status=${regEceRes.status}, ok=${regEceRes.ok}`);
  if (!regEceRes.ok) {
    throw new Error(`Failed to register ECE HOD: ${JSON.stringify(regEceRes.data)}`);
  }
  const createdEceHod = regEceRes.data;
  console.log(`Created ECE HOD: id=${createdEceHod.id}, name=${createdEceHod.name}, roleId=${createdEceHod.roleId}`);

  // Verify in DB that Department.hodUserId was set to the new HOD's id
  const updatedEceDept = await prisma.department.findUnique({ where: { code: 'ECE' } });
  console.log(`ECE Department in DB: hodUserId=${updatedEceDept.hodUserId}, hodId=${updatedEceDept.hodId}`);
  if (updatedEceDept.hodUserId !== createdEceHod.id) {
    throw new Error(`Expected ECE Department.hodUserId to be ${createdEceHod.id}, got ${updatedEceDept.hodUserId}`);
  }
  console.log(`✓ Department.hodUserId atomically updated to new HOD's id!`);

  // Step 3: Attempt to register an HOD for CSE (which already has an active HOD) without replace
  console.log('\n--- Step 3: Register HOD for CSE with existing HOD (Without Replace) ---');
  // First ensure CSE has an active HOD
  const cseDept = await prisma.department.findUnique({ where: { code: 'CSE' } });
  let existingCseHod = await prisma.user.findFirst({
    where: { department: 'CSE', roleId: 'hod', active: true, status: 'ACTIVE' },
  });
  if (!existingCseHod) {
    // Seed an active CSE HOD if none exists
    existingCseHod = await prisma.user.create({
      data: {
        name: 'Dr. Jayaraj',
        mobile: '9876500099',
        roleId: 'hod',
        role: 'Head of Department',
        department: 'CSE',
        departmentId: cseDept.id,
        active: true,
        status: 'ACTIVE',
      },
    });
    await prisma.department.update({
      where: { code: 'CSE' },
      data: { hodUserId: existingCseHod.id, hodId: existingCseHod.id },
    });
  }
  console.log(`Current active CSE HOD: ${existingCseHod.name} (${existingCseHod.id})`);

  const duplicateHodPayload = {
    name: 'Dr. Candidate HOD',
    mobile: '9876500002',
    roleId: 'hod',
    role: 'Head of Department',
    department: 'CSE',
    departmentId: cseDept.id,
    replaceHod: false,
  };

  const dupRes = await post('/admin/users', duplicateHodPayload, adminAuth.token);
  console.log(`Register duplicate HOD Response: status=${dupRes.status}, message=${dupRes.data.message}`);
  if (dupRes.status !== 400 || !dupRes.data.message.includes('already has an HOD')) {
    throw new Error(`Expected 400 with 'already has an HOD', got ${dupRes.status}: ${JSON.stringify(dupRes.data)}`);
  }
  console.log(`✓ Correctly rejected with message: "${dupRes.data.message}"`);

  // Step 4: Register HOD for CSE WITH replaceHod: true
  console.log('\n--- Step 4: Register HOD for CSE with replaceHod: true ---');
  const replaceHodPayload = {
    name: 'Dr. New CSE Head',
    mobile: '9876500003',
    roleId: 'hod',
    role: 'Head of Department',
    department: 'CSE',
    departmentId: cseDept.id,
    replaceHod: true,
  };

  const replaceRes = await post('/admin/users', replaceHodPayload, adminAuth.token);
  console.log(`Register with replaceHod Response: status=${replaceRes.status}, ok=${replaceRes.ok}`);
  if (!replaceRes.ok) {
    throw new Error(`Failed to replace HOD: ${JSON.stringify(replaceRes.data)}`);
  }
  const newCseHod = replaceRes.data;
  console.log(`Created New CSE HOD: id=${newCseHod.id}, name=${newCseHod.name}`);

  // Verify in DB that:
  // 1. Previous HOD is deactivated
  const oldHodInDb = await prisma.user.findUnique({ where: { id: existingCseHod.id } });
  console.log(`Previous HOD in DB: active=${oldHodInDb.active}, status=${oldHodInDb.status}`);
  if (oldHodInDb.active !== false || oldHodInDb.status !== 'INACTIVE') {
    throw new Error(`Expected previous HOD to be deactivated (active: false, status: INACTIVE)`);
  }

  // 2. CSE Department hodUserId is updated to new HOD
  const updatedCseDept = await prisma.department.findUnique({ where: { code: 'CSE' } });
  console.log(`CSE Department in DB: hodUserId=${updatedCseDept.hodUserId}, hodId=${updatedCseDept.hodId}`);
  if (updatedCseDept.hodUserId !== newCseHod.id) {
    throw new Error(`Expected CSE Department.hodUserId to be ${newCseHod.id}, got ${updatedCseDept.hodUserId}`);
  }
  console.log(`✓ Previous HOD deactivated and Department.hodUserId updated in one transaction!`);

  // Step 5: Verify Student Emergency Outpass reaches the NEW HOD
  console.log('\n--- Step 5: Verify Emergency Outpass reaches the New HOD ---');
  // Student Arjun K (8921578831)
  const studentAuth = await loginAs('8921578831');
  console.log(`Student logged in: ${studentAuth.user.name}`);

  // Create Emergency Outpass
  const now = new Date();
  const exitAt = new Date(now.getTime() + 60 * 60 * 1000).toISOString();
  const returnAt = new Date(now.getTime() + 4 * 60 * 60 * 1000).toISOString();

  const emergencyPayload = {
    type: 'emergency',
    purposeCategory: 'Emergency',
    purposeText: 'Urgent family medical situation requiring immediate travel home.',
    destination: 'Home',
    requestedExitAt: exitAt,
    expectedReturnAt: returnAt,
  };

  const createPassRes = await post('/outpasses', emergencyPayload, studentAuth.token);
  console.log(`Emergency Outpass Creation Response: status=${createPassRes.status}, ok=${createPassRes.ok}`);
  if (!createPassRes.ok) {
    throw new Error(`Failed to create emergency outpass: ${JSON.stringify(createPassRes.data)}`);
  }
  const createdPass = createPassRes.data;
  console.log(`Created Emergency Outpass: id=${createdPass.id}, displayId=${createdPass.displayId}, status=${createdPass.status}, currentStageRoleId=${createdPass.currentStageRoleId}`);

  // Login as the NEW HOD
  const newHodAuth = await loginAs('9876500003');
  console.log(`New HOD logged in: ${newHodAuth.user.name} (${newHodAuth.user.roleId})`);

  // Query outpasses for the new HOD
  const pendingPassesRes = await get('/approvals/pending', newHodAuth.token);
  console.log(`New HOD pending passes count: ${pendingPassesRes.data.length}`);
  const foundPass = pendingPassesRes.data.find((p) => p.id === createdPass.id);
  if (!foundPass) {
    throw new Error(`Emergency outpass ${createdPass.id} did NOT reach the new HOD!`);
  }
  console.log(`✓ Emergency Outpass ${foundPass.displayId} successfully reached the new HOD!`);

  // New HOD approves the outpass
  const approveRes = await post(`/approvals/${createdPass.id}/decision`, {
    decision: 'APPROVED',
    comment: 'Approved by new HOD',
  }, newHodAuth.token);

  console.log(`Approval response: status=${approveRes.status}, ok=${approveRes.ok}`);
  if (!approveRes.ok) {
    throw new Error(`HOD approval failed: ${JSON.stringify(approveRes.data)}`);
  }
  console.log(`Approved Outpass status: ${approveRes.data.status}`);
  if (approveRes.data.status !== 'APPROVED') {
    throw new Error(`Expected outpass status to be APPROVED, got ${approveRes.data.status}`);
  }
  console.log(`✓ Emergency outpass fully approved by the new HOD!`);

  console.log('\n================================================================');
  console.log('ALL VERIFICATIONS PASSED SUCCESSFULLY!');
  console.log('================================================================');
}

run()
  .catch((e) => {
    console.error('VERIFICATION ERROR:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
