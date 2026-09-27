// Runs before the test framework loads: isolate e2e tests from live demo data.
process.env.DATABASE_URL =
  'postgresql://outpass:outpass@localhost:5433/outpass_test?schema=public';
process.env.NODE_ENV = 'development';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret';
