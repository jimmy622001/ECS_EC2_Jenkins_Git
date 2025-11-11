// Simple unit test example

test('1 + 1 equals 2', () => {
  expect(1 + 1).toBe(2);
});

test('Environment variables are loaded correctly', () => {
  const originalEnv = process.env;
  process.env.PORT = '9000';
  
  // Import app code here or test environment variables
  expect(process.env.PORT).toBe('9000');
  
  // Restore original env
  process.env = originalEnv;
});