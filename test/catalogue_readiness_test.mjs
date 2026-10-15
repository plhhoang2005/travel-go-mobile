import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const catalogue = JSON.parse(await readFile(new URL('../docs/phase-2/catalogue/catalogue_readiness_v1.json', import.meta.url), 'utf8'));
const expected = ['ha-noi','ha-long','sa-pa','ninh-binh','hue','da-nang','hoi-an','nha-trang','da-lat','ho-chi-minh','phu-quoc','can-tho'];
function validate(data) {
  assert.equal(data.schemaVersion, 1);
  assert.equal(data.status, 'reference_data_not_deployed');
  assert.equal(data.rights.copiedDescriptions, false);
  assert.equal(data.rights.copiedImages, false);
  assert.equal(data.rights.distributionLicence, 'not_assigned');
  assert.deepEqual(data.destinations.map(d => d.id).sort(), [...expected].sort());
  const sourceIds = new Set();
  for (const source of data.sources) {
    assert.ok(!sourceIds.has(source.id)); sourceIds.add(source.id);
    const url = new URL(source.url);
    assert.equal(url.protocol, 'https:');
    assert.ok(['vietnam.travel', 'www.vietnam.travel'].includes(url.hostname));
    assert.equal(url.username + url.password, '');
    assert.equal(source.checkedAt, data.checkedAt);
    assert.equal(source.publisher, 'Viet Nam National Authority of Tourism');
  }
  const globalPlaces = new Set();
  for (const destination of data.destinations) {
    assert.equal(destination.scope, 'destination_region');
    assert.equal(destination.routingReady, false);
    assert.ok(destination.places.length >= 6);
    const local = new Set();
    for (const place of destination.places) {
      assert.ok(place.id.startsWith(destination.id + '/'));
      assert.ok(!local.has(place.id) && !globalPlaces.has(place.id));
      local.add(place.id); globalPlaces.add(place.id);
      assert.ok(typeof place.name === 'string' && place.name.trim());
      assert.ok(sourceIds.has(place.sourceId));
      assert.equal(place.referenceStatus, 'name_in_official_source');
      assert.equal(place.operationalStatus, 'unknown');
      for (const field of ['coordinates','openingHours','priceVnd','durationMinutes']) assert.equal(place[field], null);
    }
    assert.equal(destination.sample.kind, 'authored_example');
    assert.equal(destination.sample.status, 'not_feasibility_verified');
    assert.ok(destination.sample.warnings.length >= 2);
    assert.deepEqual(destination.sample.days.map(day => day.day), [1, 2, 3]);
    for (const day of destination.sample.days) {
      assert.ok(day.placeIds.length > 0);
      for (const placeId of day.placeIds) assert.ok(local.has(placeId));
    }
  }
  return globalPlaces.size;
}
test('twelve approved destinations, 72 unique sourced places and 12 bounded samples', () => {
  assert.equal(validate(catalogue), 72);
  assert.equal(catalogue.destinations.length, 12);
});
const controls = {
  'missing destination': data => data.destinations.pop(),
  'unsourced place': data => { data.destinations[0].places[0].sourceId = 'invented'; },
  'unknown price silently converted to free': data => { data.destinations[0].places[0].priceVnd = 0; },
  'unverified coordinates invented': data => { data.destinations[0].places[0].coordinates = { lat: 0, lon: 0 }; },
  'cross-destination sample binding': data => { data.destinations[0].sample.days[0].placeIds[0] = data.destinations[1].places[0].id; },
  'duplicate place identity': data => { data.destinations[0].places[1].id = data.destinations[0].places[0].id; },
  'sample falsely marked verified': data => { data.destinations[0].sample.status = 'verified'; },
  'copied source imagery': data => { data.rights.copiedImages = true; },
};
for (const [name, mutate] of Object.entries(controls)) test(`validator rejects ${name}`, () => {
  const changed = structuredClone(catalogue); mutate(changed);
  assert.throws(() => validate(changed));
});
