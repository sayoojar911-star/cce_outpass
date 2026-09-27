import { PrismaClient, Role } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const tutor = await prisma.user.upsert({
    where: { mobile: '9000000001' },
    update: {},
    create: {
      name: 'Dr. Anand Kumar',
      role: Role.TUTOR,
      mobile: '9000000001',
      department: 'CSE',
    },
  });

  const hod = await prisma.user.upsert({
    where: { mobile: '9000000002' },
    update: {},
    create: {
      name: 'Dr. Priya Menon',
      role: Role.HOD,
      mobile: '9000000002',
      department: 'CSE',
    },
  });

  const guard = await prisma.user.upsert({
    where: { mobile: '9000000090' },
    update: {},
    create: {
      name: 'Suresh (Security)',
      role: Role.GUARD,
      mobile: '9000000090',
    },
  });

  const studentData = [
    { name: 'Ananya S', registerNo: 'CCE25CS001', mobile: '9000000010', semester: 3 },
    { name: 'Arjun R', registerNo: 'CCE25CS002', mobile: '9000000011', semester: 3 },
  ];

  for (const s of studentData) {
    const user = await prisma.user.upsert({
      where: { mobile: s.mobile },
      update: {},
      create: { name: s.name, role: Role.STUDENT, mobile: s.mobile, department: 'CSE' },
    });
    await prisma.student.upsert({
      where: { userId: user.id },
      update: { tutorId: tutor.id },
      create: {
        userId: user.id,
        registerNo: s.registerNo,
        department: 'CSE',
        semester: s.semester,
        tutorId: tutor.id,
      },
    });
  }

  // Demo account for manual testing; Firebase phone auth is still required.
  const demo = await prisma.user.upsert({
    where: { mobile: '9074121510' },
    update: {},
    create: {
      name: 'Demo Student',
      role: Role.STUDENT,
      mobile: '9074121510',
      department: 'CSE',
    },
  });
  await prisma.student.upsert({
    where: { userId: demo.id },
    update: { tutorId: tutor.id },
    create: {
      userId: demo.id,
      registerNo: 'CCE25CS100',
      department: 'CSE',
      semester: 3,
      tutorId: tutor.id,
    },
  });

  await prisma.gate.upsert({
    where: { id: 'main-gate' },
    update: {},
    create: { id: 'main-gate', name: 'Main Gate', directionDefault: 'BOTH' },
  });

  console.log('Seeded:', {
    tutor: tutor.mobile,
    hod: hod.mobile,
    guard: guard.mobile,
    students: studentData.map((s) => `${s.registerNo} / ${s.mobile}`).join(', '),
    demo: demo.mobile,
  });
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
