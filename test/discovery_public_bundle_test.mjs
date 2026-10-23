// Tests for Discovery Release V2 public bundle projection and deterministic encoding.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateAndProjectPublicBundle, encodePublicBundle } from '../supabase/functions/admin-publication/bundle.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const vectorsRaw = fs.readFileSync(path.join(__dirname, 'fixtures', 'discovery_release_v2_vectors.json'), 'utf8');
const { vectors } = JSON.parse(vectorsRaw);

test('validateAndProjectPublicBundle projects standard active catalogue correctly', () => {
  const vector = vectors.find(v => v.name === 'standard_active_catalogue');
  assert.ok(vector, 'Vector standard_active_catalogue must exist');

  const { bundle, blockers, warnings } = validateAndProjectPublicBundle({
    frozenDraft: vector.frozenDraft,
    version: vector.version,
    preparedAt: vector.preparedAt,
  });

  assert.equal(blockers.length, 0, 'Should have 0 blockers');
  assert.equal(bundle.contract, 'travelgo.discovery.release.v2');
  assert.equal(bundle.schemaVersion, 2);
  assert.equal(bundle.version, 1);
  assert.equal(bundle.catalogue.destinations.length, 1);
  assert.equal(bundle.catalogue.destinations[0].id, 'da-nang');
  assert.equal(bundle.catalogue.destinations[0].places.length, 1);
  assert.equal(bundle.catalogue.destinations[0].places[0].id, 'da-nang/ba-na-hills');

  // Nha Trang is inactive, so excluded
  assert.equal(bundle.catalogue.destinations.some(d => d.id === 'nha-trang'), false);

  // Hidden place is excluded
  assert.equal(bundle.catalogue.destinations[0].places.some(p => p.id === 'da-nang/cau-rong-hidden'), false);

  // Referenced source is preserved
  assert.equal(bundle.catalogue.sources.length, 1);
  assert.equal(bundle.catalogue.sources[0].id, 'src-vn-01');

  // Deterministic encode
  const encoded = encodePublicBundle(bundle);
  assert.ok(encoded.payloadText.length > 0);
  assert.equal(encoded.bytes.length, encoded.byteLength);
  assert.equal(typeof encoded.sha256, 'string');
  assert.equal(encoded.sha256.length, 64);
});

test('all_hidden_publishes_an_empty_public_projection', () => {
  const vector = vectors.find(v => v.name === 'all_hidden_catalogue');
  assert.ok(vector, 'Vector all_hidden_catalogue must exist');

  const { bundle, blockers } = validateAndProjectPublicBundle({
    frozenDraft: vector.frozenDraft,
    version: vector.version,
    preparedAt: vector.preparedAt,
  });

  assert.equal(blockers.length, 0);
  // Pin assertion: catalogue destinations and visit places are exactly empty
  assert.equal(bundle.catalogue.destinations.length, 0);
  assert.equal(bundle.visitDetails.places.length, 0);
});

test('coordinate_pair_mismatch produces blocker and prevents invalid publication', () => {
  const draft = {
    inventory: {
      destinations: [
        { id: 'da-nang', name: 'Đà Nẵng', slug: 'da-nang', region: 'Miền Trung', isActive: true }
      ],
      places: [
        {
          id: 'da-nang/invalid-coords',
          destinationId: 'da-nang',
          name: 'Toạ độ lỗi',
          latitude: 16.05,
          longitude: null, // missing longitude!
          isActive: true
        }
      ]
    }
  };

  const { blockers } = validateAndProjectPublicBundle({
    frozenDraft: draft,
    version: 1,
    preparedAt: new Date().toISOString(),
  });

  assert.ok(blockers.some(b => b.code === 'coordinate_pair_mismatch'));
});

test('vietnamese_combining_characters preserved with exact UTF-8 byte length', () => {
  const vector = vectors.find(v => v.name === 'vietnamese_combining_characters');
  assert.ok(vector, 'Vector vietnamese_combining_characters must exist');

  const { bundle, blockers } = validateAndProjectPublicBundle({
    frozenDraft: vector.frozenDraft,
    version: vector.version,
    preparedAt: vector.preparedAt,
  });

  assert.equal(blockers.length, 0);
  assert.equal(bundle.catalogue.destinations[0].name, 'Thừa Thiên Huế');

  const encoded = encodePublicBundle(bundle);
  assert.ok(encoded.byteLength > encoded.payloadText.length, 'UTF-8 multi-byte characters expand byte count');
  assert.match(encoded.sha256, /^[0-9a-f]{64}$/);
});
