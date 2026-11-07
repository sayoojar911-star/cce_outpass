const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const users = await prisma.user.findMany({
    select: { id: true, name: true, mobile: true, role: true, roleId: true, status: true, active: true }
  });
  const counts = {
    User: await prisma.user.count(),
    Student: await prisma.student.count(),
    Role: await prisma.role.count(),
    Department: await prisma.department.count(),
    Division: await prisma.division.count(),
    PurposeCategory: await prisma.purposeCategory.count(),
    OutpassTypeConfig: await prisma.outpassTypeConfig.count(),
    AppSetting: await prisma.appSetting.count(),
    Gate: await prisma.gate.count(),
    OutpassRequest: await prisma.outpassRequest.count(),
    GateEvent: await prisma.gateEvent.count(),
    AuditLog: await prisma.auditLog.count(),
    Notification: await prisma.notification.count(),
    SecurityEvent: await prisma.securityEvent.count()
  };
  console.log('TABLE_COUNTS:' + JSON.stringify(counts));
  console.log('ADMIN_ACCOUNTS:' + JSON.stringify(users.filter(u => u.roleId === 'admin')));
  await prisma.$disconnect();
}
main().catch(err => {
  console.error(err);
  process.exit(1);
});
