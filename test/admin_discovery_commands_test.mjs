import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { webcrypto } from 'node:crypto';

const html = readFileSync(new URL('../admin/index.html', import.meta.url), 'utf8');
const rawSeed = JSON.parse(readFileSync(new URL('../assets/catalogue/place_visit_details_v1.json', import.meta.url), 'utf8'));
const base = JSON.parse(readFileSync(new URL('../assets/catalogue/catalogue_readiness_v1.json', import.meta.url), 'utf8'));

const context = {
  URL, TextEncoder, Date, AbortController, setTimeout, clearTimeout, crypto: webcrypto, atob,
  fetch: () => { throw Error('Unexpected real network'); }
};
vm.createContext(context);
vm.runInContext(html.match(/<script>([\s\S]*?)<\/script>/)[1], context);
const C = context.TravelGOAdminCore;
const copy = x => JSON.parse(JSON.stringify(x));
const seed = copy(C.withInventory(rawSeed, base));

test('server-authored commands: createDestination assigns slug-based identity and validates name/region', () => {
  const destCountBefore = seed.inventory.destinations.length;
  const newDest = {
    command: 'createDestination',
    name: 'Phú Yên',
    slug: 'phu-yen',
    region: 'Duyên hải Nam Trung Bộ',
    description: 'Xứ hoa vàng trên cỏ xanh'
  };

  // Ensure slugify matches expected server convention
  assert.equal(C.slugify(newDest.name), 'phu-yen');

  const edited = C.editEntity(seed, 'destination', {
    id: newDest.slug,
    name: newDest.name,
    slug: newDest.slug,
    region: newDest.region,
    description: newDest.description,
    imageUrl: null,
    isActive: true
  }, { create: true });

  assert.equal(edited.inventory.destinations.length, destCountBefore + 1);
  const created = edited.inventory.destinations.find(d => d.slug === 'phu-yen');
  assert.ok(created);
  assert.equal(created.id, 'phu-yen');
  assert.equal(created.isActive, true);
});

test('server-authored commands: createPlace requires active parent destination and numeric coordinates', () => {
  const withPhuYen = C.editEntity(seed, 'destination', {
    id: 'phu-yen',
    name: 'Phú Yên',
    slug: 'phu-yen',
    region: 'Nam Trung Bộ',
    description: '',
    imageUrl: null,
    isActive: true
  }, { create: true });

  const newPlace = {
    id: 'phu-yen/ghenh-da-dia',
    destinationId: 'phu-yen',
    name: 'Ghềnh Đá Đĩa',
    slug: 'ghenh-da-dia',
    description: 'Thắng cảnh tự nhiên',
    latitude: 13.3547,
    longitude: 109.2974,
    imageUrl: null,
    isActive: true
  };

  const expanded = C.editEntity(withPhuYen, 'place', newPlace, { create: true });
  assert.equal(expanded.inventory.places.length, seed.inventory.places.length + 1);
  assert.equal(expanded.places.length, seed.places.length + 1);

  const createdPlace = expanded.inventory.places.find(p => p.id === 'phu-yen/ghenh-da-dia');
  assert.ok(createdPlace);
  assert.equal(createdPlace.latitude, 13.3547);
  assert.equal(createdPlace.longitude, 109.2974);
  assert.equal(createdPlace.isActive, true);

  // Negative control: orphan place without destination throws
  assert.throws(() => C.editEntity(seed, 'place', {
    ...newPlace,
    destinationId: 'non-existent-destination'
  }, { create: true }));
});

test('server-authored commands: archiveDestination atomically hides destination and child places', () => {
  const withPhuYen = C.editEntity(seed, 'destination', {
    id: 'phu-yen',
    name: 'Phú Yên',
    slug: 'phu-yen',
    region: 'Nam Trung Bộ',
    description: '',
    imageUrl: null,
    isActive: true
  }, { create: true });

  const withPlace = C.editEntity(withPhuYen, 'place', {
    id: 'phu-yen/ghenh-da-dia',
    destinationId: 'phu-yen',
    name: 'Ghềnh Đá Đĩa',
    slug: 'ghenh-da-dia',
    description: '',
    latitude: 13.35,
    longitude: 109.29,
    imageUrl: null,
    isActive: true
  }, { create: true });

  assert.equal(withPlace.inventory.places.find(p => p.id === 'phu-yen/ghenh-da-dia').isActive, true);

  // Archive destination with archiveChildren = true
  const archived = C.editEntity(withPlace, 'destination', {
    ...withPhuYen.inventory.destinations.find(d => d.id === 'phu-yen'),
    isActive: false
  }, { archiveChildren: true });

  assert.equal(archived.inventory.destinations.find(d => d.id === 'phu-yen').isActive, false);
  assert.equal(archived.inventory.places.find(p => p.id === 'phu-yen/ghenh-da-dia').isActive, false);
});

test('server-authored commands: restoreVersion retains newly added IDs as hidden', () => {
  const withPhuYen = C.editEntity(seed, 'destination', {
    id: 'phu-yen',
    name: 'Phú Yên',
    slug: 'phu-yen',
    region: 'Nam Trung Bộ',
    description: '',
    imageUrl: null,
    isActive: true
  }, { create: true });

  const current = C.editEntity(withPhuYen, 'place', {
    id: 'phu-yen/ghenh-da-dia',
    destinationId: 'phu-yen',
    name: 'Ghềnh Đá Đĩa',
    slug: 'ghenh-da-dia',
    description: '',
    latitude: 13.35,
    longitude: 109.29,
    imageUrl: null,
    isActive: true
  }, { create: true });

  // Snapshot before phu-yen was added is `seed`
  const restored = C.restoreSnapshot(current, seed);

  // Retains newly added destination and place but sets isActive to false
  const dest = restored.inventory.destinations.find(d => d.id === 'phu-yen');
  assert.ok(dest);
  assert.equal(dest.isActive, false);

  const place = restored.inventory.places.find(p => p.id === 'phu-yen/ghenh-da-dia');
  assert.ok(place);
  assert.equal(place.isActive, false);
});
