const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const student = await prisma.user.findFirst({
    where: { roleId: 'student' },
    include: { student: true },
  });
  console.log('STUDENT:', JSON.stringify(student, null, 2));
}

main().finally(() => prisma.$disconnect());
