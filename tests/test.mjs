import initHelloModule from '../dist/hello.js';

const mod = await initHelloModule();

let passed = 0;
let failed = 0;

function assert(description, actual, expected) {
  if (actual === expected) {
    console.log(`  PASS  ${description}`);
    passed++;
  } else {
    console.error(`  FAIL  ${description}`);
    console.error(`        expected: ${JSON.stringify(expected)}`);
    console.error(`        actual:   ${JSON.stringify(actual)}`);
    failed++;
  }
}

console.log('Running tests...');

assert('greet returns greeting string', mod.greet('world'), 'Hello, world!');
assert('greet works with different name', mod.greet('Alice'), 'Hello, Alice!');
assert('add returns sum', mod.add(1, 2), 3);
assert('add works with zeros', mod.add(0, 0), 0);
assert('add works with negative numbers', mod.add(-1, 1), 0);

console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
