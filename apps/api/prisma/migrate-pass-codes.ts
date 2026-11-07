import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const PASS_CODE_CHARS = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

function generateRandomPassCode(length = 6): string {
  let result = '';
  for (let i = 0; i < length; i++) {
    const idx = Math.floor(Math.random() * PASS_CODE_CHARS.length);
    result += PASS_CODE_CHARS[idx];
  }
  return result;
}

async function getUniquePassCode(): Promise<string> {
  while (true) {
    const candidate = generateRandomPassCode(6);
    const exists = await prisma.outpassRequest.findUnique({ where: { passCode: candidate } });
    if (!exists) return candidate;
  }
}

async function migrate() {
  console.log('--- Migrating Outpass Pass Codes ---');
  const allOutpasses = await prisma.outpassRequest.findMany({
    orderBy: { createdAt: 'asc' },
  });

  console.log(`Found ${allOutpasses.length} outpass requests`);

  for (const op of allOutpasses) {
    if (!op.passCode) {
      const code = await getUniquePassCode();
      await prisma.outpassRequest.update({
        where: { id: op.id },
        data: { passCode: code },
      });
      console.log(`Assigned passCode "${code}" to ${op.displayId} (${op.id})`);
    } else {
      console.log(`Outpass ${op.displayId} already has passCode "${op.passCode}"`);
    }
  }

  // Ensure settings minDwellMinutes and qrValidityWindowSeconds exist in appSetting
  const settings = [
    { key: 'minDwellMinutes', value: JSON.stringify(10) },
    { key: 'qrValidityWindowSeconds', value: JSON.stringify(90) },
  ];
  for (const s of settings) {
    await prisma.appSetting.upsert({
      where: { key: s.key },
      update: {},
      create: s,
    });
    console.log(`Ensured setting: ${s.key}`);
  }

  console.log('Migration complete.');
}

migrate()
  .catch((e) => {
    console.error('Migration failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
