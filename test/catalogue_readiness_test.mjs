import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const catalogue = JSON.parse(await readFile(new URL('../docs/phase-2/catalogue/catalogue_readiness_v1.json', import.meta.url), 'utf8'));
const expected = ['ha-noi','ha-long','sa-pa','ninh-binh','hue','da-nang','hoi-an','nha-trang','da-lat','ho-chi-minh','phu-quoc','can-tho'];
const sourcePublishers = new Map([
  ['vietnam.travel', 'Viet Nam National Authority of Tourism'],
  ['www.vietnam.travel', 'Viet Nam National Authority of Tourism'],
  ['sapanapro.com', 'SAPANAPRO'],
  ['danangfantasticity.com', 'Da Nang Tourism Promotion Center'],
  ['halongbay.com.vn', 'Ha Long Bay Management Board'],
]);
function nonblank(value) {
  assert.ok(typeof value === 'string' && value.trim());
}
function calendarDate(value) {
  assert.ok(typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value));
  const parsed = new Date(`${value}T00:00:00Z`);
  assert.ok(Number.isFinite(parsed.getTime()));
  assert.equal(parsed.toISOString().slice(0, 10), value);
}
function stringList(value, minLength = 0) {
  assert.ok(Array.isArray(value));
  assert.ok(value.length >= minLength);
  value.forEach(nonblank);
}
function reviewStatus(sample, sourceIds) {
  if (sample.editorialReview === undefined) return 'pending';
  const review = sample.editorialReview;
  assert.ok(review && typeof review === 'object' && !Array.isArray(review));
  assert.ok(['pending', 'reviewed_with_conditions'].includes(review.status));
  stringList(review.sourceIds);
  assert.equal(new Set(review.sourceIds).size, review.sourceIds.length);
  for (const id of review.sourceIds) assert.ok(sourceIds.has(id));
  stringList(review.conditions);
  stringList(review.reviewNotes);
  if (review.status === 'pending') {
    assert.equal(review.reviewedAt, null);
    assert.equal(review.sourceIds.length, 0);
    assert.equal(review.conditions.length, 0);
  } else {
    calendarDate(review.reviewedAt);
    assert.ok(review.sourceIds.length > 0);
    assert.ok(review.conditions.length > 0);
    assert.ok(review.reviewNotes.length > 0);
  }
  return review.status;
}
function validate(data) {
  assert.equal(data.schemaVersion, 1);
  assert.equal(data.status, 'reference_data_not_deployed');
  calendarDate(data.checkedAt);
  assert.equal(data.rights.copiedDescriptions, false);
  assert.equal(data.rights.copiedImages, false);
  assert.equal(data.rights.distributionLicence, 'not_assigned');
  assert.deepEqual(data.destinations.map(d => d.id).sort(), [...expected].sort());
  const sourceIds = new Set();
  for (const source of data.sources) {
    nonblank(source.id); nonblank(source.title); nonblank(source.publisher);
    assert.ok(!sourceIds.has(source.id)); sourceIds.add(source.id);
    const url = new URL(source.url);
    assert.equal(url.protocol, 'https:');
    assert.ok(sourcePublishers.has(url.hostname));
    assert.equal(url.username + url.password, '');
    assert.ok(url.port === '' || url.port === '443');
    calendarDate(source.checkedAt);
    if (['vietnam.travel', 'www.vietnam.travel'].includes(url.hostname)) {
      assert.equal(source.checkedAt, data.checkedAt);
    }
    assert.equal(source.publisher, sourcePublishers.get(url.hostname));
  }
  const globalPlaces = new Set();
  const sampleIds = new Set();
  for (const destination of data.destinations) {
    nonblank(destination.name);
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
    nonblank(destination.sample.id);
    assert.ok(destination.sample.id.startsWith(destination.id + '/'));
    assert.ok(!sampleIds.has(destination.sample.id));
    sampleIds.add(destination.sample.id);
    stringList(destination.sample.warnings, 2);
    reviewStatus(destination.sample, sourceIds);
    assert.ok(Array.isArray(destination.sample.days) && destination.sample.days.length > 0);
    for (const [index, day] of destination.sample.days.entries()) {
      assert.equal(day.day, index + 1);
      stringList(day.placeIds, 1);
      assert.equal(new Set(day.placeIds).size, day.placeIds.length);
      for (const placeId of day.placeIds) assert.ok(local.has(placeId));
    }
  }
  return globalPlaces.size;
}
test('twelve approved destinations, 72 unique sourced places and 12 bounded samples', () => {
  assert.equal(validate(catalogue), 72);
  assert.equal(catalogue.destinations.length, 12);
});
test('published inventory explicitly withholds all twelve candidate schedules', () => {
  for (const destination of catalogue.destinations) {
    assert.ok(Object.hasOwn(destination.sample, 'editorialReview'));
    assert.equal(reviewStatus(destination.sample, new Set(catalogue.sources.map(s => s.id))), 'pending');
    assert.deepEqual(destination.sample.days.map(day => day.day), [1, 2, 3]);
    assert.ok(destination.sample.editorialReview.reviewNotes.length > 0);
  }
});
test('legacy inventory without editorialReview is pending, not published', () => {
  const legacy = structuredClone(catalogue);
  for (const destination of legacy.destinations) delete destination.sample.editorialReview;
  assert.equal(validate(legacy), 72);
  assert.equal(reviewStatus(legacy.destinations[0].sample, new Set()), 'pending');
});
test('conditional editorial review does not verify feasibility (synthetic fixture only)', () => {
  const conditional = structuredClone(catalogue);
  conditional.destinations[0].sample.editorialReview = {
    status: 'reviewed_with_conditions', reviewedAt: '2026-10-15', sourceIds: ['hn'],
    conditions: ['Synthetic test condition; not travel evidence.'],
    reviewNotes: ['Synthetic parser fixture; not approval to publish this real sample.'],
  };
  assert.equal(validate(conditional), 72);
  assert.equal(conditional.destinations[0].sample.status, 'not_feasibility_verified');
});
test('sample structure permits two days and one or three places per day', () => {
  const changed = structuredClone(catalogue);
  const ids = changed.destinations[0].places.map(p => p.id);
  changed.destinations[0].sample.days = [
    { day: 1, placeIds: ids.slice(0, 1) }, { day: 2, placeIds: ids.slice(1, 4) },
  ];
  assert.equal(validate(changed), 72);
});
const pendingReview = () => ({
  status: 'pending', reviewedAt: null, sourceIds: [], conditions: [], reviewNotes: [],
});
const conditionalReview = () => ({
  status: 'reviewed_with_conditions', reviewedAt: '2026-10-15', sourceIds: ['hn'],
  conditions: ['Test only'], reviewNotes: ['Test only'],
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
  'non-HTTPS source': data => { data.sources[0].url = 'http://vietnam.travel/place'; },
  'unapproved source host': data => { data.sources[0].url = 'https://vietnam.travel.evil.test/place'; },
  'source credentials': data => { data.sources[0].url = 'https://user:secret@vietnam.travel/place'; },
  'nonstandard source port': data => { data.sources[0].url = 'https://vietnam.travel:8443/place'; },
  'invalid source calendar date': data => { data.sources[0].checkedAt = '2026-02-30'; },
  'invalid inventory date': data => { data.checkedAt = '2026-13-01'; },
  'duplicate source ID': data => { data.sources[1].id = data.sources[0].id; },
  'source publisher mismatch': data => { data.sources[0].publisher = 'Invented'; },
  'blank source title': data => { data.sources[0].title = ' '; },
  'invalid catalogue version': data => { data.schemaVersion = 2; },
  'duplicate sample identity': data => { data.destinations[1].sample.id = data.destinations[0].sample.id; },
  'repeated place within a day': data => { data.destinations[0].sample.days[0].placeIds.push(data.destinations[0].sample.days[0].placeIds[0]); },
  'nonconsecutive days': data => { data.destinations[0].sample.days[0].day = 2; },
  'null editorial marker': data => { data.destinations[0].sample.editorialReview = null; },
  'array editorial marker': data => { data.destinations[0].sample.editorialReview = []; },
  'unknown editorial status': data => { data.destinations[0].sample.editorialReview = { ...pendingReview(), status: 'verified' }; },
  'pending marker with reviewed date': data => { data.destinations[0].sample.editorialReview = { ...pendingReview(), reviewedAt: '2026-10-15' }; },
  'pending marker with publication conditions': data => { data.destinations[0].sample.editorialReview = { ...pendingReview(), conditions: ['Open'] }; },
  'pending marker with sources': data => { data.destinations[0].sample.editorialReview = { ...pendingReview(), sourceIds: ['hn'] }; },
  'conditional review without sources': data => { data.destinations[0].sample.editorialReview = { ...conditionalReview(), sourceIds: [] }; },
  'conditional review with invented source': data => { data.destinations[0].sample.editorialReview = { ...conditionalReview(), sourceIds: ['invented'] }; },
  'conditional review with duplicate sources': data => { data.destinations[0].sample.editorialReview = { ...conditionalReview(), sourceIds: ['hn', 'hn'] }; },
  'conditional review with nonexistent date': data => { data.destinations[0].sample.editorialReview = { ...conditionalReview(), reviewedAt: '2026-02-30' }; },
  'conditional review without conditions': data => { data.destinations[0].sample.editorialReview = { ...conditionalReview(), conditions: [] }; },
  'conditional review without notes': data => { data.destinations[0].sample.editorialReview = { ...conditionalReview(), reviewNotes: [] }; },
  'blank review note': data => { data.destinations[0].sample.editorialReview = { ...conditionalReview(), reviewNotes: [' '] }; },
  'wrong review list type': data => { data.destinations[0].sample.editorialReview = { ...pendingReview(), sourceIds: 'hn' }; },
};
for (const [name, mutate] of Object.entries(controls)) test(`validator rejects ${name}`, () => {
  const changed = structuredClone(catalogue); mutate(changed);
  assert.throws(() => validate(changed));
});
