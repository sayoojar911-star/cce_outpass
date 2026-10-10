const path = require('path');
const EmbeddedPostgres = require('embedded-postgres').default || require('embedded-postgres');

async function main() {
  const dbDir = path.join(__dirname, '..', '.pgdata');
  console.log('Starting Embedded PostgreSQL on port 5433...');
  console.log('Data directory:', dbDir);

  const pg = new EmbeddedPostgres({
    databaseDir: dbDir,
    user: 'outpass',
    password: 'outpass',
    port: 5433,
    persistent: true,
  });

  try {
    await pg.initialise();
    console.log('Initialized PostgreSQL cluster.');
  } catch (err) {
    console.log('Cluster already initialized or:', err.message);
  }

  await pg.start();
  console.log('PostgreSQL server started successfully on port 5433.');

  try {
    await pg.createDatabase('outpass');
    console.log('Database "outpass" created.');
  } catch (err) {
    console.log('Database "outpass" ready.');
  }

  // Handle termination gracefully
  const shutdown = async () => {
    console.log('Shutting down PostgreSQL...');
    try {
      await pg.stop();
    } catch (_) {}
    process.exit(0);
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);

  console.log('PostgreSQL daemon is ready and listening on localhost:5433.');

  // Keep process running
  setInterval(() => {}, 10000);
}

main().catch((err) => {
  console.error('Failed to start Embedded PostgreSQL:', err);
  process.exit(1);
});
