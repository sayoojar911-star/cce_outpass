import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export async function migrateOutpassTypes() {
  console.log('Running idempotent outpass types migration...');

  // 1. Clear legacy outpass type rows to avoid unique constraint on label
  await prisma.outpassTypeConfig.deleteMany({});

  // 2. Insert stable 'normal'
  await prisma.outpassTypeConfig.create({
    data: {
      id: 'normal',
      label: 'Normal (Tutor -> HOD)',
      approvalChain: ['tutor', 'hod'],
      requiresExplanation: false,
      active: true,
    },
  });

  // 3. Insert stable 'emergency'
  await prisma.outpassTypeConfig.create({
    data: {
      id: 'emergency',
      label: 'Emergency (Direct to HOD)',
      approvalChain: ['hod'],
      requiresExplanation: true,
      active: true,
    },
  });

  // 4. Migrate existing outpass requests
  const emergencyMigrated = await prisma.outpassRequest.updateMany({
    where: {
      OR: [
        { type: { contains: 'emergency', mode: 'insensitive' } },
        { typeId: { contains: 'emergency', mode: 'insensitive' } },
      ],
      typeId: { not: 'emergency' },
    },
    data: {
      typeId: 'emergency',
      type: 'Emergency (Direct to HOD)',
    },
  });
  console.log(`Migrated ${emergencyMigrated.count} emergency requests.`);

  const normalMigrated = await prisma.outpassRequest.updateMany({
    where: {
      typeId: { notIn: ['normal', 'emergency'] },
    },
    data: {
      typeId: 'normal',
      type: 'Normal (Tutor -> HOD)',
    },
  });
  console.log(`Migrated ${normalMigrated.count} other requests to normal.`);

  const types = await prisma.outpassTypeConfig.findMany();
  console.log('Active outpass types in DB:', JSON.stringify(types, null, 2));
}

if (require.main === module) {
  migrateOutpassTypes()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('Migration failed:', err);
      process.exit(1);
    })
    .finally(() => prisma.$disconnect());
}
