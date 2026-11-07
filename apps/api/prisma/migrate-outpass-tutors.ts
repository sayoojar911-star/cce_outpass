import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export async function migrateOutpasses() {
  console.log('--- Migrating Outpass Requests: tutorId, currentStep, and Status Values ---');

  const allRequests = await prisma.outpassRequest.findMany({
    include: {
      studentUser: { select: { id: true, tutorId: true } },
      student: { select: { userId: true, tutorId: true } },
    },
  });

  console.log(`Found ${allRequests.length} total outpass requests to inspect.`);

  let repairedCount = 0;

  for (const req of allRequests) {
    const studentTutorId = req.studentUser?.tutorId || req.student?.tutorId || null;
    let newStatus = req.status;

    // Normalize legacy 'PENDING' status to stage-specific status
    if (req.status === 'PENDING') {
      if (req.currentStageRoleId === 'tutor') {
        newStatus = 'PENDING_TUTOR';
      } else if (req.currentStageRoleId === 'hod') {
        newStatus = 'PENDING_HOD';
      }
    }

    const needsTutorId = !req.tutorId && studentTutorId;
    const needsStatusRepair = newStatus !== req.status;
    const needsCurrentStep = (req as any).currentStep !== req.currentStageIndex;

    if (needsTutorId || needsStatusRepair || needsCurrentStep) {
      await prisma.outpassRequest.update({
        where: { id: req.id },
        data: {
          tutorId: req.tutorId || studentTutorId,
          status: newStatus,
          currentStep: req.currentStageIndex,
        },
      });
      console.log(
        `✓ Repaired outpass ${req.displayId} (${req.id}): tutorId=${req.tutorId || studentTutorId}, status=${newStatus}, currentStep=${req.currentStageIndex}`,
      );
      repairedCount++;
    }
  }

  console.log(`Migration complete: ${repairedCount} outpasses repaired.`);
}

if (require.main === module) {
  migrateOutpasses()
    .catch((err) => {
      console.error('Migration failed:', err);
      process.exit(1);
    })
    .finally(() => prisma.$disconnect());
}
