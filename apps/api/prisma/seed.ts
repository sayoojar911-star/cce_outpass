import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding initial database configuration...');

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

  // 2. Purpose Categories
  const categories = ['Medical', 'Academic', 'Personal', 'Official', 'Emergency'];
  for (const cat of categories) {
    const existing = await prisma.purposeCategory.findFirst({ where: { label: cat } });
    if (!existing) {
      await prisma.purposeCategory.create({ data: { label: cat, active: true } });
    }
  }

  // 3. Outpass Types (Strictly exactly two: normal & emergency)
  const types = [
    {
      id: 'normal',
      label: 'Normal (Tutor -> HOD)',
      approvalChain: ['tutor', 'hod'],
      requiresExplanation: false,
      active: true,
    },
    {
      id: 'emergency',
      label: 'Emergency (Direct to HOD)',
      approvalChain: ['hod'],
      requiresExplanation: true,
      active: true,
    },
  ];
  for (const t of types) {
    await prisma.outpassTypeConfig.upsert({
      where: { id: t.id },
      update: {
        label: t.label,
        approvalChain: t.approvalChain,
        requiresExplanation: t.requiresExplanation,
        active: t.active,
      },
      create: t,
    });
  }
  await prisma.outpassTypeConfig.deleteMany({
    where: { id: { notIn: ['normal', 'emergency'] } },
  });

  // 4. Default Settings
  const defaultSettings = [
    { key: 'collegeName', value: JSON.stringify('Christ College of Engineering, Irinjalakuda') },
    { key: 'minDwellMinutes', value: JSON.stringify(10) },
    { key: 'defaultDurationHours', value: JSON.stringify(3) },
    { key: 'defaultRoleId', value: JSON.stringify('pending') },
    { key: 'allowedStartTime', value: JSON.stringify('06:00') },
    { key: 'allowedEndTime', value: JSON.stringify('21:00') },
    { key: 'admin_bootstrapped', value: JSON.stringify(true) },
  ];
  for (const s of defaultSettings) {
    await prisma.appSetting.upsert({
      where: { key: s.key },
      update: { value: s.value },
      create: s,
    });
  }

  // 5. Default Gate
  await prisma.gate.upsert({
    where: { id: 'main-gate' },
    update: {},
    create: { id: 'main-gate', name: 'Main Gate', directionDefault: 'BOTH' },
  });

  // 6. Academic Departments and Divisions
  const departments = [
    { code: 'CSE', name: 'Computer Science and Engineering', divisions: ['A', 'B', 'C', 'D'] },
    { code: 'CSDS', name: 'Computer Science and Engineering (Data Science)', divisions: [] },
    { code: 'CSBS', name: 'Computer Science and Business Systems', divisions: [] },
    { code: 'EC', name: 'Electronics and Communication Engineering', divisions: [] },
    { code: 'EEE', name: 'Electrical and Electronics Engineering', divisions: [] },
    { code: 'ME', name: 'Mechanical Engineering', divisions: [] },
    { code: 'CE', name: 'Civil Engineering', divisions: [] },
    { code: 'VLSI', name: 'VLSI Design and Technology', divisions: [] },
  ];
  for (const d of departments) {
    const dept = await prisma.department.upsert({
      where: { code: d.code },
      update: { name: d.name },
      create: { code: d.code, name: d.name },
    });
    for (const divName of d.divisions) {
      await prisma.division.upsert({
        where: { departmentId_name: { departmentId: dept.id, name: divName } },
        update: {},
        create: { departmentId: dept.id, name: divName },
      });
    }
  }

  // 7. Users
  const adminPhone = process.env.ADMIN_PHONE || '8921578838';
  const admin = await prisma.user.upsert({
    where: { mobile: adminPhone },
    update: { roleId: 'admin', role: 'System Administrator', status: 'ACTIVE', active: true },
    create: {
      name: 'System Administrator',
      roleId: 'admin',
      role: 'System Administrator',
      mobile: adminPhone,
      status: 'ACTIVE',
      active: true,
    },
  });

  const cseDept = await prisma.department.findUnique({ where: { code: 'CSE' } });

  const hod = await prisma.user.upsert({
    where: { mobile: '8921578832' },
    update: { roleId: 'hod', role: 'Head of Department', department: 'CSE', departmentId: cseDept?.id, status: 'ACTIVE', active: true },
    create: {
      name: 'Dr. Priya Menon',
      roleId: 'hod',
      role: 'Head of Department',
      mobile: '8921578832',
      department: 'CSE',
      departmentId: cseDept?.id,
      status: 'ACTIVE',
      active: true,
    },
  });
  if (cseDept) {
    await prisma.department.update({ where: { id: cseDept.id }, data: { hodUserId: hod.id, hodId: hod.id } });
  }

  const tutor = await prisma.user.upsert({
    where: { mobile: '1234567890' },
    update: { roleId: 'tutor', role: 'Class Tutor', department: 'CSE', departmentId: cseDept?.id, year: 2, division: 'D', status: 'ACTIVE', active: true },
    create: {
      name: 'sreedevi',
      roleId: 'tutor',
      role: 'Class Tutor',
      mobile: '1234567890',
      department: 'CSE',
      departmentId: cseDept?.id,
      year: 2,
      division: 'D',
      status: 'ACTIVE',
      active: true,
    },
  });

  const ceDept = await prisma.department.findUnique({ where: { code: 'CE' } });
  await prisma.user.upsert({
    where: { mobile: '9874563210' },
    update: { roleId: 'tutor', role: 'Class Tutor', department: 'CE', departmentId: ceDept?.id, status: 'ACTIVE', active: true },
    create: {
      name: 'ranjima',
      roleId: 'tutor',
      role: 'Class Tutor',
      mobile: '9874563210',
      department: 'CE',
      departmentId: ceDept?.id,
      status: 'ACTIVE',
      active: true,
    },
  });

  const student = await prisma.user.upsert({
    where: { mobile: '8921578831' },
    update: { roleId: 'student', role: 'Student', department: 'CSE', departmentId: cseDept?.id, year: 2, division: 'D', tutorId: tutor.id, status: 'ACTIVE', active: true },
    create: {
      name: 'Arjun K',
      roleId: 'student',
      role: 'Student',
      mobile: '8921578831',
      department: 'CSE',
      departmentId: cseDept?.id,
      year: 2,
      division: 'D',
      tutorId: tutor.id,
      status: 'ACTIVE',
      active: true,
    },
  });
  await prisma.student.upsert({
    where: { userId: student.id },
    update: { tutorId: tutor.id, department: 'CSE', year: 2, division: 'D', semester: 3 },
    create: {
      userId: student.id,
      registerNo: 'CCEK22CS001',
      department: 'CSE',
      year: 2,
      division: 'D',
      semester: 3,
      tutorId: tutor.id,
    },
  });

  const guard = await prisma.user.upsert({
    where: { mobile: '8921578834' },
    update: { roleId: 'guard', role: 'Gate Security Guard', status: 'ACTIVE', active: true },
    create: {
      name: 'Chief Guard Suresh',
      roleId: 'guard',
      role: 'Gate Security Guard',
      mobile: '8921578834',
      status: 'ACTIVE',
      active: true,
    },
  });

  console.log('Database configuration seed complete.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
