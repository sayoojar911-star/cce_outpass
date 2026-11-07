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
  console.log('E2E VERIFICATION: Normal Outpass Flow & Tutor Approval Verification');
  console.log('================================================================\n');

  // Find test users
  const adminAuth = await loginAs('8921578838');
  console.log(`[1] Admin logged in: ${adminAuth.user.name}`);

  const tutorUser = await prisma.user.findFirst({ where: { mobile: '8921578833' } }); // Dr. Sreedevi (Tutor)
  const hodUser = await prisma.user.findFirst({ where: { mobile: '8921578832' } }); // Dr. Priya Menon (HOD)
  const studentUser = await prisma.user.findFirst({ where: { mobile: '8921578831' } }); // Arjun K (Student)

  if (!tutorUser || !hodUser || !studentUser) {
    throw new Error('Required test users not found in DB');
  }

  // Ensure department CSE exists
  const dept = await prisma.department.findFirst({ where: { code: 'CSE' } });

  // Complete any lingering passes for clean test run
  await prisma.outpassRequest.updateMany({
    where: { studentUserId: studentUser.id, status: { notIn: ['REJECTED', 'EXPIRED', 'COMPLETED', 'CANCELLED'] } },
    data: { status: 'COMPLETED' },
  });

  // -------------------------------------------------------------
  // Test 1: Student without tutor is blocked with clear message
  // -------------------------------------------------------------
  console.log('\n--- Test 1: Student without tutor is blocked from Normal outpass ---');
  // Temporarily clear Arjun's tutorId
  await prisma.user.update({
    where: { id: studentUser.id },
    data: { tutorId: null },
  });
  await prisma.student.updateMany({
    where: { userId: studentUser.id },
    data: { tutorId: null },
  });

  const studentAuthNoTutor = await loginAs('8921578831');
  const now = new Date();
  const exitTime = new Date(now.getTime() + 30 * 60 * 1000).toISOString();
  const returnTime = new Date(now.getTime() + 3 * 3600 * 1000).toISOString();

  const blockedRes = await post(
    '/outpasses',
    {
      requestedExitAt: exitTime,
      expectedReturnAt: returnTime,
      destination: 'Thrissur Round',
      purposeCategory: 'Personal',
      type: 'normal',
    },
    studentAuthNoTutor.token,
  );

  console.log(`  Submit response status: ${blockedRes.status}`);
  console.log(`  Submit response error: ${JSON.stringify(blockedRes.data)}`);
  if (blockedRes.ok || blockedRes.status !== 400 || !blockedRes.data.message?.includes('No tutor assigned, contact admin')) {
    throw new Error(`Expected submission to be blocked with "No tutor assigned, contact admin", got status ${blockedRes.status}`);
  }
  console.log('✓ PASS: Normal outpass creation correctly blocked with "No tutor assigned, contact admin"');

  // -------------------------------------------------------------
  // Test 2: Admin assigns Tutor to Student
  // -------------------------------------------------------------
  console.log('\n--- Test 2: Admin assigns Tutor to Student ---');
  const assignRes = await post(
    `/admin/users/${studentUser.id}`,
    {
      name: 'Arjun K',
      roleId: 'student',
      departmentId: dept.id,
      tutorId: tutorUser.id,
      year: 3,
      division: 'A',
    },
    adminAuth.token,
  );
  if (!assignRes.ok) throw new Error(`Failed to assign tutor: ${JSON.stringify(assignRes.data)}`);
  console.log(`✓ Admin assigned tutor ${tutorUser.name} (${tutorUser.id}) to student Arjun K`);

  // -------------------------------------------------------------
  // Test 3: Student with assigned tutor submits Normal Outpass
  // -------------------------------------------------------------
  console.log('\n--- Test 3: Student submits Normal Outpass (Tutor -> HOD) ---');
  const studentAuth = await loginAs('8921578831');
  console.log(`  Student logged in: ${studentAuth.user.name}, tutorId: ${studentAuth.user.tutorId}`);

  // Complete any lingering passes for clean test
  await prisma.outpassRequest.updateMany({
    where: { studentUserId: studentUser.id, status: { notIn: ['REJECTED', 'EXPIRED', 'COMPLETED', 'CANCELLED'] } },
    data: { status: 'COMPLETED' },
  });

  const createRes = await post(
    '/outpasses',
    {
      requestedExitAt: exitTime,
      expectedReturnAt: returnTime,
      destination: 'Thrissur Town',
      purposeCategory: 'Medical',
      purposeText: 'Dentist appointment at city clinic',
      type: 'normal',
    },
    studentAuth.token,
  );

  if (!createRes.ok) throw new Error(`Outpass creation failed: ${JSON.stringify(createRes.data)}`);
  const createdPass = createRes.data;
  console.log(`✓ Created outpass: ${createdPass.displayId} (${createdPass.id})`);
  console.log(`  Fields: status=${createdPass.status}, currentStep=${createdPass.currentStep}, currentStageRoleId=${createdPass.currentStageRoleId}, tutorId=${createdPass.tutorId}, typeId=${createdPass.typeId}`);

  if (createdPass.status !== 'PENDING_TUTOR') throw new Error(`Expected status PENDING_TUTOR, got ${createdPass.status}`);
  if (createdPass.currentStep !== 0) throw new Error(`Expected currentStep 0, got ${createdPass.currentStep}`);
  if (createdPass.currentStageRoleId !== 'tutor') throw new Error(`Expected currentStageRoleId tutor, got ${createdPass.currentStageRoleId}`);
  if (createdPass.tutorId !== tutorUser.id) throw new Error(`Expected tutorId ${tutorUser.id}, got ${createdPass.tutorId}`);

  // -------------------------------------------------------------
  // Test 4: Tutor sees it immediately in pending approvals
  // -------------------------------------------------------------
  console.log('\n--- Test 4: Tutor queries pending approvals ---');
  const tutorAuth = await loginAs('8921578833');
  console.log(`  Tutor logged in: ${tutorAuth.user.name} (${tutorAuth.user.id})`);

  const pendingRes = await get('/approvals/pending', tutorAuth.token);
  if (!pendingRes.ok) throw new Error(`Tutor pending query failed: ${JSON.stringify(pendingRes.data)}`);
  const pendingList = pendingRes.data;
  console.log(`  Pending approvals count for tutor: ${pendingList.length}`);

  const matched = pendingList.find((p) => p.id === createdPass.id);
  if (!matched) {
    throw new Error(`Created outpass ${createdPass.displayId} was NOT found in tutor's pending approvals!`);
  }
  console.log(`✓ PASS: Created outpass ${matched.displayId} appears immediately in tutor's pending list!`);

  // -------------------------------------------------------------
  // Test 5: Tutor approves outpass -> moves to HOD (currentStep 1, PENDING_HOD)
  // -------------------------------------------------------------
  console.log('\n--- Test 5: Tutor approves outpass ---');
  const approveRes = await post(
    `/approvals/${createdPass.id}/decision`,
    {
      decision: 'APPROVED',
      comment: 'Approved by tutor Dr. Sreedevi',
    },
    tutorAuth.token,
  );

  if (!approveRes.ok) throw new Error(`Tutor approval failed: ${JSON.stringify(approveRes.data)}`);
  const approvedData = approveRes.data;
  console.log(`✓ Tutor approval result: status=${approvedData.status}, currentStep=${approvedData.currentStep}, currentStageRoleId=${approvedData.currentStageRoleId}`);

  if (approvedData.status !== 'PENDING_HOD') throw new Error(`Expected status PENDING_HOD, got ${approvedData.status}`);
  if (approvedData.currentStep !== 1) throw new Error(`Expected currentStep 1, got ${approvedData.currentStep}`);
  if (approvedData.currentStageRoleId !== 'hod') throw new Error(`Expected currentStageRoleId hod, got ${approvedData.currentStageRoleId}`);

  // -------------------------------------------------------------
  // Test 6: Verify outpass is no longer in tutor's pending and is in HOD's pending
  // -------------------------------------------------------------
  console.log('\n--- Test 6: Verify HOD pending and Tutor pending status ---');
  const tutorPendingAfter = await get('/approvals/pending', tutorAuth.token);
  const tutorStillSees = tutorPendingAfter.data.some((p) => p.id === createdPass.id);
  if (tutorStillSees) throw new Error(`Outpass should NO LONGER be in tutor pending list!`);
  console.log('✓ PASS: Outpass no longer appears in tutor pending list');

  const hodAuth = await loginAs('8921578832');
  console.log(`  HOD logged in: ${hodAuth.user.name} (${hodAuth.user.id})`);
  const hodPendingRes = await get('/approvals/pending', hodAuth.token);
  const hodSees = hodPendingRes.data.some((p) => p.id === createdPass.id);
  if (!hodSees) throw new Error(`Outpass did NOT appear in HOD pending list!`);
  console.log('✓ PASS: Outpass moved to HOD and appears immediately in HOD pending list');

  // HOD approves
  const hodApproveRes = await post(
    `/approvals/${createdPass.id}/decision`,
    { decision: 'APPROVED', comment: 'Approved by HOD Dr. Priya Menon' },
    hodAuth.token,
  );
  if (!hodApproveRes.ok) throw new Error(`HOD approval failed: ${JSON.stringify(hodApproveRes.data)}`);
  console.log(`✓ HOD final approval result: status=${hodApproveRes.data.status}`);
  if (hodApproveRes.data.status !== 'APPROVED') throw new Error(`Expected final status APPROVED, got ${hodApproveRes.data.status}`);

  // -------------------------------------------------------------
  // Test 7: Emergency Outpass flow directly starts at HOD
  // -------------------------------------------------------------
  console.log('\n--- Test 7: Emergency Outpass starts at HOD (bypasses Tutor) ---');
  // Complete previous pass
  await prisma.outpassRequest.update({ where: { id: createdPass.id }, data: { status: 'COMPLETED' } });

  const emerCreateRes = await post(
    '/outpasses',
    {
      requestedExitAt: exitTime,
      expectedReturnAt: returnTime,
      destination: 'District Hospital',
      purposeCategory: 'Emergency',
      purposeText: 'High fever and severe illness requires immediate medical admission',
      type: 'emergency',
    },
    studentAuth.token,
  );

  if (!emerCreateRes.ok) throw new Error(`Emergency outpass creation failed: ${JSON.stringify(emerCreateRes.data)}`);
  const emerPass = emerCreateRes.data;
  console.log(`✓ Created Emergency Outpass: ${emerPass.displayId}`);
  console.log(`  status=${emerPass.status}, currentStep=${emerPass.currentStep}, currentStageRoleId=${emerPass.currentStageRoleId}`);

  if (emerPass.status !== 'PENDING_HOD') throw new Error(`Expected emergency status PENDING_HOD, got ${emerPass.status}`);
  if (emerPass.currentStageRoleId !== 'hod') throw new Error(`Expected emergency currentStageRoleId hod, got ${emerPass.currentStageRoleId}`);

  // Verify tutor does not see it, but HOD does
  const tutorCheck = await get('/approvals/pending', tutorAuth.token);
  if (tutorCheck.data.some((p) => p.id === emerPass.id)) {
    throw new Error('Emergency outpass must NOT appear in tutor pending list!');
  }
  const hodCheck = await get('/approvals/pending', hodAuth.token);
  if (!hodCheck.data.some((p) => p.id === emerPass.id)) {
    throw new Error('Emergency outpass MUST appear directly in HOD pending list!');
  }
  console.log('✓ PASS: Emergency outpass correctly bypassed tutor and went directly to HOD');

  // Clean up emergency pass
  await prisma.outpassRequest.update({ where: { id: emerPass.id }, data: { status: 'COMPLETED' } });

  console.log('\n================================================================');
  console.log('ALL E2E VERIFICATION CHECKS PASSED SUCCESSFULLY!');
  console.log('================================================================');
}

run()
  .catch((e) => {
    console.error('\n❌ E2E VERIFICATION FAILED:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
