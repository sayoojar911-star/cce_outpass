require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const targetMobile = process.argv[2] || process.env.BOOTSTRAP_ADMIN_PHONE || process.env.BOOTSTRAP_ADMIN_MOBILE;
  if (!targetMobile) {
    console.error('Usage: node scripts/bootstrap-admin.cjs <phone_number>');
    console.error('Or set BOOTSTRAP_ADMIN_PHONE in the environment.');
    process.exit(1);
  }

  const normalized = targetMobile.replace(/\D/g, '').slice(-10);

  // Check if bootstrap was already completed
  const bootstrappedSetting = await prisma.appSetting.findUnique({
    where: { key: 'admin_bootstrapped' },
  });
  if (bootstrappedSetting && JSON.parse(bootstrappedSetting.value) === true) {
    const existingAdminCount = await prisma.user.count({
      where: { roleId: 'admin', active: true },
    });
    if (existingAdminCount > 0) {
      console.error(
        'Bootstrap error: The system has already been bootstrapped with active administrators. ' +
        'Further role changes must be done through the application Admin area by an administrator.',
      );
      process.exit(1);
    }
  }

  let user = await prisma.user.findFirst({
    where: { mobile: normalized },
  });

  if (!user) {
    user = await prisma.user.create({
      data: {
        name: 'System Administrator',
        mobile: normalized,
        roleId: 'admin',
        active: true,
        status: 'ACTIVE',
      },
    });
    console.log(`Created new administrator account for ${normalized} (id: ${user.id}).`);
  } else {
    user = await prisma.user.update({
      where: { id: user.id },
      data: {
        roleId: 'admin',
        active: true,
        status: 'ACTIVE',
      },
    });
    console.log(`Promoted existing user ${user.name} (${normalized}) to System Administrator role.`);
  }

  // Mark bootstrap complete
  await prisma.appSetting.upsert({
    where: { key: 'admin_bootstrapped' },
    update: { value: JSON.stringify(true) },
    create: { key: 'admin_bootstrapped', value: JSON.stringify(true) },
  });

  console.log('Admin bootstrap completed successfully. The one-time bootstrap path is now locked.');
}

main()
  .catch((err) => {
    console.error('Bootstrap failed:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
