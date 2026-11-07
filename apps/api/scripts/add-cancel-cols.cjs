const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  await prisma.$executeRawUnsafe(`
    ALTER TABLE "OutpassRequest" 
    ADD COLUMN IF NOT EXISTS "cancelledAt" TIMESTAMP(3),
    ADD COLUMN IF NOT EXISTS "cancelledBy" TEXT,
    ADD COLUMN IF NOT EXISTS "cancelReason" TEXT;
  `);
  console.log('Successfully ensured cancelledAt, cancelledBy, and cancelReason columns exist on OutpassRequest.');
}

main().catch(console.error).finally(() => prisma.$disconnect());
