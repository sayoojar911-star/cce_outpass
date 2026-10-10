import { PrismaClient, Role } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const adminPhone = process.env.ADMIN_PHONE || '8921578838';

  // 1. Seed Admin User
  const admin = await prisma.user.upsert({
    where: { mobile: adminPhone },
    update: { role: Role.ADMIN, status: 'ACTIVE' },
    create: {
      name: 'System Administrator',
      role: Role.ADMIN,
      mobile: adminPhone,
      status: 'ACTIVE',
    },
  });

  // 2. Seed Default Gate
  await prisma.gate.upsert({
    where: { id: 'main-gate' },
    update: {},
    create: { id: 'main-gate', name: 'Main Gate', directionDefault: 'BOTH' },
  });

  // 3. Seed Default Settings
  const defaultSettings = [
    { key: 'collegeName', value: JSON.stringify('Christ College of Engineering, Irinjalakuda') },
    { key: 'minDwellMinutes', value: JSON.stringify(10) },
    { key: 'categories', value: JSON.stringify(['Medical', 'Personal', 'Official', 'Academic', 'Emergency']) },
  ];
  for (const setting of defaultSettings) {
    await prisma.appSetting.upsert({
      where: { key: setting.key },
      update: {},
      create: setting,
    });
  }

  // 4. Seed Academic Departments and Divisions
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

  // 5. Seed standard role users
  const hod = await prisma.user.upsert({
    where: { mobile: '8921578832' },
    update: { role: Role.HOD, department: 'CSE', status: 'ACTIVE' },
    create: {
      name: 'Dr. Priya Menon',
      role: Role.HOD,
      mobile: '8921578832',
      department: 'CSE',
      status: 'ACTIVE',
    },
  });
  await prisma.department.update({ where: { code: 'CSE' }, data: { hodId: hod.id } });

  const tutor = await prisma.user.upsert({
    where: { mobile: '8921578833' },
    update: { role: Role.TUTOR, department: 'CSE', year: 2, division: 'D', status: 'ACTIVE' },
    create: {
      name: 'Dr. Anand Kumar',
      role: Role.TUTOR,
      mobile: '8921578833',
      department: 'CSE',
      year: 2,
      division: 'D',
      status: 'ACTIVE',
    },
  });

  const student = await prisma.user.upsert({
    where: { mobile: '8921578831' },
    update: { role: Role.STUDENT, department: 'CSE', year: 2, division: 'D', status: 'ACTIVE' },
    create: {
      name: 'Arjun K',
      role: Role.STUDENT,
      mobile: '8921578831',
      department: 'CSE',
      year: 2,
      division: 'D',
      status: 'ACTIVE',
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
    update: { role: Role.GUARD, status: 'ACTIVE' },
    create: {
      name: 'Chief Guard Suresh',
      role: Role.GUARD,
      mobile: '8921578834',
      status: 'ACTIVE',
    },
  });

  console.log('Seed complete:', {
    admin: admin.mobile,
    hod: hod.mobile,
    tutor: tutor.mobile,
    student: student.mobile,
    guard: guard.mobile,
    departments: departments.map(d => d.code),
  });
}

main()
  .catch(e => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
