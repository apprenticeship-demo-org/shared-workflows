/**
 * Tests for src/index.js.
 *
 * The CI pipeline runs these via `jest --coverage` and uploads the
 * coverage report to SonarQube. Aim for at least 80% line coverage
 * to pass the quality gate.
 */
const { greet } = require('./index');

describe('greet', () => {
  test('returns expected message for World', () => {
    expect(greet('World')).toBe('Hello, World!');
  });

  test('uses the provided name', () => {
    expect(greet('Alice')).toBe('Hello, Alice!');
  });

  test('returns a string', () => {
    expect(typeof greet('Test')).toBe('string');
  });
});
