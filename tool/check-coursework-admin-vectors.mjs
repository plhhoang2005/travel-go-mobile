import fs from 'node:fs';
import assert from 'node:assert/strict';

const actual = JSON.parse(fs.readFileSync(process.argv[2], 'utf8').replace(/^\uFEFF/, ''));
const expected = JSON.parse(fs.readFileSync(new URL('../test/fixtures/coursework_admin_account_vectors.json', import.meta.url), 'utf8').replace(/^\uFEFF/, ''));
assert.deepEqual(actual, expected, 'Actual local SQL responses must match shared Dart/Node vectors');
console.log(`SQL vectors PASS: ${actual.vectors.length} operations/readbacks`);
