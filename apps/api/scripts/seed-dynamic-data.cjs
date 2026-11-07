require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('Seeding dynamic configuration collections...');

  // 1. Roles
  const roles = [
    {
      id: 'admin',
      name: 'System Administrator',
      description: 'Full institutional configuration and user management',
      permissions: [
        'createOutpass',
        'approveOutpass',
        'gateScan',
        'manageUsers',
        'manageRoles',
        'manageDepartments',
        'manageOutpassConfig',
        'viewAll',
      ],
      isSystem: true,
      active: true,
    },
    {
      id: 'tutor',
      name: 'Class Tutor',
      description: 'Approves outpass requests for assigned division students',
      permissions: ['approveOutpass'],
      isSystem: false,
      active: true,
    },
    {
      id: 'hod',
      name: 'Head of Department',
      description: 'Authorizes departmental outpass approvals',
      permissions: ['approveOutpass'],
      isSystem: false,
      active: true,
    },
    {
      id: 'guard',
      name: 'Gate Security Guard',
      description: 'Verifies passes and scans QR credentials at campus gates',
      permissions: ['gateScan'],
      isSystem: false,
      active: true,
    },
    {
      id: 'student',
      name: 'Student',
      description: 'Generates and tracks digital gate outpasses',
      permissions: ['createOutpass'],
      isSystem: false,
      active: true,
    },
    {
      id: 'pending',
      name: 'Pending Assignment',
      description: 'New account awaiting admin assignment',
      permissions: [],
      isSystem: true,
      active: true,
    },
  ];

  for (const r of roles) {
    await prisma.role.upsert({
      where: { id: r.id },
      update: {
        name: r.name,
        description: r.description,
        permissions: r.permissions,
        isSystem: r.isSystem,
        active: r.active,
      },
      create: r,
    });
  }
  console.log('Roles seeded.');

  // 2. Purpose Categories
  const categories = ['Medical', 'Academic', 'Personal', 'Official', 'Emergency'];
  for (const cat of categories) {
    const existing = await prisma.purposeCategory.findFirst({ where: { label: cat } });
    if (!existing) {
      await prisma.purposeCategory.create({ data: { label: cat, active: true } });
    }
  }
  console.log('Purpose categories seeded.');

  // 3. Outpass Types
  const types = [
    { label: 'Normal (Tutor -> HOD)', approvalChain: ['tutor', 'hod'] },
    { label: 'Emergency', approvalChain: ['hod'] },
    { label: 'Single Step (Tutor)', approvalChain: ['tutor'] },
  ];
  for (const t of types) {
    const existing = await prisma.outpassTypeConfig.findFirst({ where: { label: t.label } });
    if (existing) {
      await prisma.outpassTypeConfig.update({
        where: { id: existing.id },
        data: { approvalChain: t.approvalChain, active: true },
      });
    } else {
      await prisma.outpassTypeConfig.create({
        data: { label: t.label, approvalChain: t.approvalChain, active: true },
      });
    }
  }
  console.log('Outpass types seeded.');

  // 4. Settings
  const settings = [
    { key: 'collegeName', value: JSON.stringify('Christ College of Engineering, Irinjalakuda') },
    { key: 'minDwellMinutes', value: JSON.stringify(10) },
    { key: 'defaultDurationHours', value: JSON.stringify(3) },
    { key: 'defaultRoleId', value: JSON.stringify('pending') },
    { key: 'allowedStartTime', value: JSON.stringify('06:00') },
    { key: 'allowedEndTime', value: JSON.stringify('21:00') },
    { key: 'admin_bootstrapped', value: JSON.stringify(true) },
  ];
  for (const s of settings) {
    await prisma.appSetting.upsert({
      where: { key: s.key },
      update: { value: s.value },
      create: s,
    });
  }
  console.log('Settings seeded.');

  // 5. Link existing users with roles, departments, tutors
  const cseDept = await prisma.department.findUnique({ where: { code: 'CSE' } });
  const csbsDept = await prisma.department.findUnique({ where: { code: 'CSBS' } });

  // Map users:
  const tutorUser = await prisma.user.findFirst({ where: { mobile: '8921578833' } });
  const hodUser = await prisma.user.findFirst({ where: { mobile: '8921578832' } });

  await prisma.user.updateMany({
    where: { mobile: '8921578838' },
    data: { roleId: 'admin', active: true },
  });

  if (tutorUser) {
    await prisma.user.update({
      where: { id: tutorUser.id },
      data: {
        roleId: 'tutor',
        departmentId: cseDept ? cseDept.id : null,
        active: true,
      },
    });
  }

  if (hodUser) {
    await prisma.user.update({
      where: { id: hodUser.id },
      data: {
        roleId: 'hod',
        departmentId: cseDept ? cseDept.id : null,
        active: true,
      },
    });
    if (cseDept) {
      await prisma.department.update({
        where: { id: cseDept.id },
        data: { hodUserId: hodUser.id, hodId: hodUser.id },
      });
    }
  }

  const arjun = await prisma.user.findFirst({ where: { mobile: '8921578831' } });
  if (arjun) {
    await prisma.user.update({
      where: { id: arjun.id },
      data: {
        roleId: 'student',
        departmentId: cseDept ? cseDept.id : null,
        tutorId: tutorUser ? tutorUser.id : null,
        active: true,
      },
    });
  }

  await prisma.user.updateMany({
    where: { mobile: '8921578834' },
    data: { roleId: 'guard', active: true },
  });

  await prisma.user.updateMany({
    where: { mobile: '9876543219' },
    data: {
      roleId: 'hod',
      departmentId: csbsDept ? csbsDept.id : null,
      active: true,
    },
  });

  console.log('Existing users successfully updated with dynamic roleId and departmentId.');
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
