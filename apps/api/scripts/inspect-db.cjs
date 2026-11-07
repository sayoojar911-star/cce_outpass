const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const users = await prisma.user.findMany({
    select: { id: true, name: true, mobile: true, roleId: true, role: true, departmentId: true, tutorId: true, status: true, active: true }
  });
  console.log('Users (' + users.length + '):');
  for (const u of users) {
    console.log(`  ${u.name} (${u.mobile}) -> roleId: ${u.roleId}, status: ${u.status}, active: ${u.active}`);
  }

  const roles = await prisma.role.findMany();
  console.log('Roles (' + roles.length + '):');
  for (const r of roles) {
    console.log(`  [${r.id}] ${r.name} -> permissions: [${r.permissions.join(', ')}]`);
  }

  const types = await prisma.outpassTypeConfig.findMany();
  console.log('Outpass Types (' + types.length + '):');
  for (const t of types) {
    console.log(`  [${t.id}] "${t.label}" -> chain: [${t.approvalChain.join(', ')}] (active: ${t.active})`);
  }
}

main().finally(() => prisma.$disconnect());
