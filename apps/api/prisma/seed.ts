import { PrismaClient, Role } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const adminPhone = process.env.ADMIN_PHONE || '8921578838';

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

  // Seed default gate for QR scanning
  await prisma.gate.upsert({
    where: { id: 'main-gate' },
    update: {},
    create: { id: 'main-gate', name: 'Main Gate', directionDefault: 'BOTH' },
  });

  // Seed default settings
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

  console.log('Seed complete:', {
    admin: admin.mobile,
    role: admin.role,
  });
  console.log('');
  console.log('Next: Log in as Admin (phone:', adminPhone, ') with OTP 123456');
  console.log('Then add Tutors, HODs, Guards and Students from the Admin panel.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
