const { PrismaClient } = require('@prisma/client');
const fs = require('fs');
const path = require('path');
const prisma = new PrismaClient();

function replacer(key, value) {
  return typeof value === 'bigint' ? value.toString() : value;
}

async function backup() {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupDir = path.resolve(__dirname, '../../backups/pre-cleanup-' + timestamp);
  fs.mkdirSync(backupDir, { recursive: true });
  const models = [
    'role', 'purposeCategory', 'outpassTypeConfig', 'user', 'student',
    'device', 'otp', 'session', 'outpassRequest', 'approval', 'gate',
    'gateEvent', 'auditLog', 'notification', 'department', 'division',
    'academicYear', 'semester', 'class', 'studentClass', 'tutorClass',
    'rolePermission', 'securityEvent', 'appSetting'
  ];
  const summary = {};
  for (const m of models) {
    if (prisma[m]) {
      const data = await prisma[m].findMany();
      fs.writeFileSync(path.join(backupDir, m + '.json'), JSON.stringify(data, replacer, 2));
      summary[m] = data.length;
    }
  }
  console.log('BACKUP_SAVED_TO:' + backupDir);
  console.log('BACKUP_SUMMARY:' + JSON.stringify(summary));
  await prisma.$disconnect();
}

backup().catch(err => {
  console.error(err);
  process.exit(1);
});
