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
  // Step 1: request OTP
  const sendRes = await post('/auth/otp/send', { mobile });
  if (!sendRes.ok) throw new Error(`OTP send failed for ${mobile}: ${JSON.stringify(sendRes.data)}`);

  // Step 2: verify OTP
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
  console.log('=====================================================');
  console.log('PART 5 VERIFICATION: End-to-End Walkthrough');
  console.log('=====================================================\n');

  // Clear any existing active outpasses for Arjun so we have a clean test run
  const arjunUser = await prisma.user.findFirst({ where: { mobile: '8921578831' } });
  if (arjunUser) {
    await prisma.outpassRequest.updateMany({
      where: { studentUserId: arjunUser.id, status: { notIn: ['REJECTED', 'EXPIRED', 'COMPLETED'] } },
      data: { status: 'COMPLETED' },
    });
  }

  // -----------------------------------------------------------------
  // Step 1: Admin assigns Arjun K Student role, a tutor, and a department
  // -----------------------------------------------------------------
  console.log('--- Step 1: Admin configures Arjun K ---');
  const adminAuth = await loginAs('8921578838');
  console.log(`✓ Admin logged in: ${adminAuth.user.name} (Role: ${adminAuth.user.roleId})`);

  const tutorUser = await prisma.user.findFirst({ where: { mobile: '8921578833' } });
  const dept = await prisma.department.findFirst({ where: { code: 'CSE' } });
  console.log(`  Assigning to Arjun K -> Role: student, Dept: ${dept.code}, Tutor: ${tutorUser.name}`);

  const assignRes = await post(
    `/admin/users/${arjunUser.id}`,
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
  if (!assignRes.ok) throw new Error(`Failed to update Arjun K: ${JSON.stringify(assignRes.data)}`);
  console.log('✓ Admin successfully assigned Arjun K role=student, tutor, and department via API');

  // Also ensure Dr. Priya Menon is active HOD for CSE
  const priyaUser = await prisma.user.findFirst({ where: { mobile: '8921578832' } });
  if (priyaUser) {
    await post(
      `/admin/users/${priyaUser.id}`,
      { name: 'Dr. Priya Menon', mobile: '8921578832', status: 'ACTIVE', roleId: 'hod', departmentId: dept.id, active: true },
      adminAuth.token,
    );
    await post(
      `/admin/departments`,
      { id: dept.id, code: dept.code, name: dept.name, hodUserId: priyaUser.id },
      adminAuth.token,
    );
    console.log('✓ Admin ensured Dr. Priya Menon is active HOD for CSE');
  }

  // Verify in DB
  const updatedArjun = await prisma.user.findUnique({
    where: { id: arjunUser.id },
    include: { roleRef: true, deptRef: true, tutor: true },
  });
  console.log(`✓ DB verification: roleId=${updatedArjun.roleId}, dept=${updatedArjun.deptRef?.name}, tutor=${updatedArjun.tutor?.name}`);

  // -----------------------------------------------------------------
  // Step 2: Arjun submits a "Normal (Tutor -> HOD)" outpass from DB-defined chain
  // -----------------------------------------------------------------
  console.log('\n--- Step 2: Arjun submits outpass from DB chain ---');
  const arjunAuth = await loginAs('8921578831');
  console.log(`✓ Arjun logged in: roleId=${arjunAuth.user.roleId}, permissions=[${arjunAuth.user.permissions.join(', ')}]`);

  // Verify config comes from DB
  const configRes = await get('/config/all', arjunAuth.token);
  if (!configRes.ok) {
    throw new Error(`Failed to load /config/all: status=${configRes.status}, data=${JSON.stringify(configRes.data)}`);
  }
  const purposeCats = configRes.data.purposeCategories || configRes.data.categories || [];
  console.log(`✓ Loaded dynamic config: ${configRes.data.roles?.length || 0} roles, ${purposeCats.length} categories, ${configRes.data.outpassTypes?.length || 0} outpass types`);
  
  const normalType = configRes.data.outpassTypes.find(t => t.label.includes('Normal'));
  console.log(`  Selected dynamic outpass type: "${normalType.label}" with DB approval chain: [${normalType.approvalChain.join(' -> ')}]`);

  const exitTime = new Date(Date.now() + 30 * 60 * 1000).toISOString();
  const returnTime = new Date(Date.now() + 4 * 60 * 60 * 1000).toISOString();

  const outpassRes = await post(
    '/outpasses',
    {
      destination: 'Thrissur Town',
      purposeCategory: 'Medical',
      purposeText: 'Consultation with doctor',
      type: normalType.label,
      requestedExitAt: exitTime,
      expectedReturnAt: returnTime,
    },
    arjunAuth.token,
  );
  if (!outpassRes.ok) throw new Error(`Outpass creation failed: ${JSON.stringify(outpassRes.data)}`);
  const createdPass = outpassRes.data;
  console.log(`✓ Outpass submitted: ID=${createdPass.id}, Display=${createdPass.displayId}, Status=${createdPass.status}`);
  if (createdPass.status !== 'PENDING_TUTOR') {
    throw new Error(`Expected PENDING_TUTOR at stage 0, got ${createdPass.status}`);
  }

  // -----------------------------------------------------------------
  // Step 3: Tutor approves -> status becomes PENDING_HOD -> HOD approves -> APPROVED
  // -----------------------------------------------------------------
  console.log('\n--- Step 3: Sequential Multi-Stage Approval (Tutor -> HOD) ---');
  const tutorAuth = await loginAs('8921578833');
  console.log(`✓ Tutor logged in: ${tutorAuth.user.name} (Role: ${tutorAuth.user.roleId})`);

  // Tutor approves Stage 0
  const tutorApproveRes = await post(
    `/approvals/${createdPass.id}/decision`,
    { decision: 'APPROVED', comment: 'Approved by tutor for medical visit' },
    tutorAuth.token,
  );
  if (!tutorApproveRes.ok) throw new Error(`Tutor approval failed: ${JSON.stringify(tutorApproveRes.data)}`);
  console.log(`✓ Tutor approved Stage 0. New Status: ${tutorApproveRes.data.status}`);
  if (tutorApproveRes.data.status !== 'PENDING_HOD') {
    throw new Error(`Expected status to advance to PENDING_HOD, got ${tutorApproveRes.data.status}`);
  }

  // HOD logs in
  const hodAuth = await loginAs('8921578832');
  console.log(`✓ HOD logged in: ${hodAuth.user.name} (Role: ${hodAuth.user.roleId})`);

  // HOD approves Stage 1
  const hodApproveRes = await post(
    `/approvals/${createdPass.id}/decision`,
    { decision: 'APPROVED', comment: 'Approved by HOD' },
    hodAuth.token,
  );
  if (!hodApproveRes.ok) throw new Error(`HOD approval failed: ${JSON.stringify(hodApproveRes.data)}`);
  console.log(`✓ HOD approved Stage 1. New Status: ${hodApproveRes.data.status}`);
  if (hodApproveRes.data.status !== 'APPROVED') {
    throw new Error(`Expected final status to be APPROVED, got ${hodApproveRes.data.status}`);
  }

  // Verify approval records
  const finalPass = await prisma.outpassRequest.findUnique({
    where: { id: createdPass.id },
    include: { approvals: true },
  });
  console.log(`✓ Pass successfully approved by complete chain: ${finalPass.approvals.length} approval log records`);

  // -----------------------------------------------------------------
  // Step 4: Changing role in Admin screen changes access without editing any code
  // -----------------------------------------------------------------
  console.log('\n--- Step 4: Role change updates access dynamically without code changes ---');
  
  // Set Arjun to pending (no createOutpass permission)
  console.log('  Admin demotes Arjun to "pending" role...');
  await post(`/admin/users/${arjunUser.id}`, { roleId: 'pending' }, adminAuth.token);

  // Arjun logs in with pending role
  const arjunPendingAuth = await loginAs('8921578831');
  console.log(`  Arjun role is now: ${arjunPendingAuth.user.roleId}, perms: [${arjunPendingAuth.user.permissions.join(', ')}]`);

  // Arjun attempts to create outpass -> should be blocked with 403 Forbidden
  const blockedRes = await post(
    '/outpasses',
    {
      destination: 'Town',
      purposeCategory: 'Personal',
      type: normalType.label,
      requestedExitAt: exitTime,
      expectedReturnAt: returnTime,
    },
    arjunPendingAuth.token,
  );
  console.log(`✓ Outpass creation blocked by backend: status=${blockedRes.status} (${blockedRes.data.message})`);
  if (blockedRes.status !== 403) {
    throw new Error(`Expected 403 Forbidden for pending user, got ${blockedRes.status}`);
  }

  // Admin re-promotes Arjun to student
  console.log('  Admin re-promotes Arjun to "student" role...');
  await post(`/admin/users/${arjunUser.id}`, { roleId: 'student' }, adminAuth.token);
  const arjunStudentAuth = await loginAs('8921578831');
  console.log(`✓ Access restored dynamically: roleId=${arjunStudentAuth.user.roleId}, permissions=[${arjunStudentAuth.user.permissions.join(', ')}]`);

  // -----------------------------------------------------------------
  // Step 5: Safety rules (Self-role edit block & Last-admin deletion block)
  // -----------------------------------------------------------------
  console.log('\n--- Step 5: Safety Rules Enforcement ---');
  
  // Admin tries to change their own role
  const adminUser = await prisma.user.findFirst({ where: { mobile: '8921578838' } });
  const selfEditRes = await post(
    `/admin/users/${adminUser.id}`,
    { roleId: 'student' },
    adminAuth.token,
  );
  console.log(`✓ Self-role modification blocked: status=${selfEditRes.status} (${selfEditRes.data.message})`);
  if (![400, 403].includes(selfEditRes.status)) {
    throw new Error(`Expected 400/403 for self role edit, got ${selfEditRes.status}`);
  }

  // Admin tries to delete the only admin
  const deleteAdminRes = await post(
    `/admin/users/${adminUser.id}/delete`,
    {},
    adminAuth.token,
  );
  console.log(`✓ Last admin deletion blocked: status=${deleteAdminRes.status} (${deleteAdminRes.data.message})`);
  if (![400, 403].includes(deleteAdminRes.status)) {
    throw new Error(`Expected 400/403 for last admin deletion, got ${deleteAdminRes.status}`);
  }

  // -----------------------------------------------------------------
  // Step 6: Outpass Types Restrictions & Emergency Workflow Verification
  // -----------------------------------------------------------------
  console.log('\n--- Step 6: Exactly Two Outpass Types & Emergency Workflow ---');

  // Verify exactly 2 outpass types exist in DB
  const dbTypes = await prisma.outpassTypeConfig.findMany();
  console.log(`  Database outpass types count: ${dbTypes.length}`);
  if (dbTypes.length !== 2) {
    throw new Error(`Expected exactly 2 outpass types in DB, found ${dbTypes.length}`);
  }
  const typeIds = dbTypes.map(t => t.id).sort();
  console.log(`  Database type IDs: [${typeIds.join(', ')}]`);
  if (typeIds[0] !== 'emergency' || typeIds[1] !== 'normal') {
    throw new Error(`Expected ['emergency', 'normal'], got ${JSON.stringify(typeIds)}`);
  }

  // Admin cannot add a 3rd type
  const addTypeRes = await post(
    '/admin/outpass-types',
    { id: 'special', label: 'Special Pass', approvalChain: ['hod'], active: true },
    adminAuth.token,
  );
  console.log(`✓ Admin adding new outpass type blocked: status=${addTypeRes.status} (${addTypeRes.data.message})`);
  if (addTypeRes.status !== 400) {
    throw new Error(`Expected 400 when adding non-allowed outpass type, got ${addTypeRes.status}`);
  }

  // Admin cannot delete existing outpass type
  const deleteTypeRes = await post(
    '/admin/outpass-types/normal/delete',
    {},
    adminAuth.token,
  );
  console.log(`✓ Admin deleting outpass type blocked: status=${deleteTypeRes.status} (${deleteTypeRes.data.message})`);
  if (deleteTypeRes.status !== 400) {
    throw new Error(`Expected 400 when deleting outpass type, got ${deleteTypeRes.status}`);
  }

  // Complete previous active outpass for Arjun so he can submit an emergency one
  await prisma.outpassRequest.updateMany({
    where: { studentUserId: arjunUser.id, status: { notIn: ['REJECTED', 'EXPIRED', 'COMPLETED'] } },
    data: { status: 'COMPLETED' },
  });

  // Emergency submission with short explanation (< 15 chars) -> blocked by backend
  console.log('  Testing emergency submission with short explanation (< 15 chars)...');
  const shortEmergRes = await post(
    '/outpasses',
    {
      destination: 'Hospital',
      purposeCategory: 'Emergency',
      purposeText: 'Headache',
      type: 'emergency',
      requestedExitAt: exitTime,
      expectedReturnAt: returnTime,
    },
    arjunStudentAuth.token,
  );
  console.log(`✓ Short emergency explanation blocked: status=${shortEmergRes.status} (${shortEmergRes.data.message})`);
  if (shortEmergRes.status !== 400) {
    throw new Error(`Expected 400 for short emergency explanation, got ${shortEmergRes.status}`);
  }

  // Emergency submission with valid explanation (>= 15 chars) -> succeeds and goes DIRECT to HOD
  console.log('  Testing emergency submission with valid explanation (>= 15 chars)...');
  const validEmergRes = await post(
    '/outpasses',
    {
      destination: 'Government Hospital',
      purposeCategory: 'Emergency',
      purposeText: 'Severe chest discomfort requiring urgent medical consultation at hospital',
      type: 'emergency',
      requestedExitAt: exitTime,
      expectedReturnAt: returnTime,
    },
    arjunStudentAuth.token,
  );
  if (!validEmergRes.ok) {
    throw new Error(`Emergency outpass creation failed: ${JSON.stringify(validEmergRes.data)}`);
  }
  const emergPass = validEmergRes.data;
  console.log(`✓ Emergency pass created: ID=${emergPass.id}, Status=${emergPass.status}, CurrentStage=${emergPass.currentStageRoleId}`);
  if (emergPass.status !== 'PENDING_HOD') {
    throw new Error(`Expected emergency pass status to be PENDING_HOD directly, got ${emergPass.status}`);
  }
  if (emergPass.currentStageRoleId !== 'hod') {
    throw new Error(`Expected emergency pass currentStageRoleId to be 'hod', got ${emergPass.currentStageRoleId}`);
  }

  // HOD approves the emergency pass directly
  console.log('  HOD approves the emergency pass directly...');
  const hodEmergApproveRes = await post(
    `/approvals/${emergPass.id}/decision`,
    { decision: 'APPROVED', comment: 'Approved emergency request' },
    hodAuth.token,
  );
  if (!hodEmergApproveRes.ok) {
    throw new Error(`HOD approval of emergency failed: ${JSON.stringify(hodEmergApproveRes.data)}`);
  }
  console.log(`✓ Emergency pass approved by HOD. Final Status: ${hodEmergApproveRes.data.status}`);
  if (hodEmergApproveRes.data.status !== 'APPROVED') {
    throw new Error(`Expected emergency pass to be APPROVED, got ${hodEmergApproveRes.data.status}`);
  }

  console.log('\n=====================================================');
  console.log('ALL VERIFICATION CHECKS (INCLUDING EMERGENCY & TYPES) PASSED PERFECTLY!');
  console.log('=====================================================');
}

run()
  .catch(err => {
    console.error('\n❌ Verification Failed:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
