require('dotenv').config();
const { Client } = require('pg');

async function run() {
  const connectionString = process.env.DATABASE_URL;
  const client = new Client({ connectionString });
  await client.connect();
  console.log('Connected to PostgreSQL database');

  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS "roles" (
        "id" TEXT PRIMARY KEY,
        "name" TEXT NOT NULL,
        "description" TEXT,
        "permissions" TEXT[] NOT NULL DEFAULT '{}',
        "isSystem" BOOLEAN NOT NULL DEFAULT FALSE,
        "active" BOOLEAN NOT NULL DEFAULT TRUE,
        "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS "purpose_categories" (
        "id" TEXT PRIMARY KEY,
        "label" TEXT NOT NULL UNIQUE,
        "active" BOOLEAN NOT NULL DEFAULT TRUE,
        "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS "outpass_types" (
        "id" TEXT PRIMARY KEY,
        "label" TEXT NOT NULL UNIQUE,
        "approvalChain" TEXT[] NOT NULL DEFAULT '{}',
        "active" BOOLEAN NOT NULL DEFAULT TRUE,
        "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      ALTER TABLE "User" ALTER COLUMN "role" DROP DEFAULT;
      ALTER TABLE "User" ALTER COLUMN "role" TYPE TEXT USING "role"::TEXT;
      ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "roleId" TEXT;
      ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "active" BOOLEAN DEFAULT TRUE;
      ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "departmentId" TEXT;
      ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "tutorId" TEXT;
      ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "email" TEXT;

      ALTER TABLE "Department" ADD COLUMN IF NOT EXISTS "hodUserId" TEXT;
      ALTER TABLE "Department" ADD COLUMN IF NOT EXISTS "active" BOOLEAN DEFAULT TRUE;

      ALTER TABLE "OutpassRequest" ALTER COLUMN "type" DROP DEFAULT;
      ALTER TABLE "OutpassRequest" ALTER COLUMN "type" TYPE TEXT USING "type"::TEXT;
      ALTER TABLE "OutpassRequest" ALTER COLUMN "status" DROP DEFAULT;
      ALTER TABLE "OutpassRequest" ALTER COLUMN "status" TYPE TEXT USING "status"::TEXT;
      ALTER TABLE "OutpassRequest" ADD COLUMN IF NOT EXISTS "typeId" TEXT;
      ALTER TABLE "OutpassRequest" ADD COLUMN IF NOT EXISTS "currentStageRoleId" TEXT;
      ALTER TABLE "OutpassRequest" ADD COLUMN IF NOT EXISTS "currentStageIndex" INTEGER DEFAULT 0;
      ALTER TABLE "OutpassRequest" ADD COLUMN IF NOT EXISTS "approvalChain" TEXT[] DEFAULT '{}';
      ALTER TABLE "OutpassRequest" ADD COLUMN IF NOT EXISTS "studentUserId" TEXT;
      ALTER TABLE "OutpassRequest" ALTER COLUMN "studentId" DROP NOT NULL;

      ALTER TABLE "Approval" ADD COLUMN IF NOT EXISTS "stageRoleId" TEXT;
    `);
    console.log('SQL Migration executed successfully.');
  } catch (err) {
    console.error('Migration error:', err);
    throw err;
  } finally {
    await client.end();
  }
}

run();
