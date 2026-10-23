// Bundle builder and projection validator for TravelGO Discovery Release V2.
// Implements deterministic packaging, public projection filtering, and cross-runtime hash vectors.

import crypto from 'node:crypto';

export function validateAndProjectPublicBundle({ frozenDraft, version, preparedAt }) {
  const blockers = [];
  const warnings = [];

  if (!Number.isInteger(version) || version < 1) {
    blockers.push({ code: 'invalid_version', path: 'version', message: 'Version must be an integer >= 1' });
  }

  const prepDate = new Date(preparedAt);
  if (isNaN(prepDate.getTime())) {
    blockers.push({ code: 'invalid_prepared_at', path: 'preparedAt', message: 'preparedAt must be a valid ISO timestamp' });
  }

  const inventory = (frozenDraft && frozenDraft.inventory) || {};
  const rawDestinations = Array.isArray(inventory.destinations) ? inventory.destinations : [];
  const rawPlaces = Array.isArray(inventory.places) ? inventory.places : [];
  const rawSources = Array.isArray(frozenDraft?.sources) ? frozenDraft.sources : [];
  const rawVisitPlaces = Array.isArray(frozenDraft?.places) ? frozenDraft.places : [];
  const rawPackages = Array.isArray(frozenDraft?.packages) ? frozenDraft.packages : [];

  // Filter ONLY active destinations
  const activeDestinations = [];
  const activeDestIds = new Set();
  const referencedSourceIds = new Set();

  for (const d of rawDestinations) {
    if (d.isActive === false) continue;
    if (!d.id || typeof d.id !== 'string' || d.id.length > 120) {
      blockers.push({ code: 'invalid_destination_id', path: `destinations.${d.id}`, message: 'Destination ID must be string <= 120 chars' });
      continue;
    }
    if (!d.name || typeof d.name !== 'string' || d.name.trim().length === 0 || d.name.length > 180) {
      blockers.push({ code: 'invalid_destination_name', path: `destinations.${d.id}.name`, message: 'Destination name must be 1-180 characters' });
      continue;
    }

    if (Array.isArray(d.sourceRefs)) {
      for (const s of d.sourceRefs) referencedSourceIds.add(String(s));
    }

    activeDestIds.add(d.id);
    activeDestinations.push({
      id: d.id,
      name: d.name.trim(),
      slug: (d.slug || d.id).trim(),
      region: (d.region || '').trim(),
      description: (d.description || '').trim(),
      imageUrl: d.imageUrl || null,
      imageRights: d.imageRights || null,
      sourceRefs: Array.isArray(d.sourceRefs) ? d.sourceRefs : [],
      places: [], // nested places populated below
      sample: null,
    });
  }

  // Sort destinations by ID for determinism
  activeDestinations.sort((a, b) => a.id.localeCompare(b.id));

  // Map destinations for child attachment
  const destMap = new Map(activeDestinations.map(d => [d.id, d]));

  // Filter ONLY active places belonging to an active destination
  const activePlaces = [];
  const activePlaceIds = new Set();

  for (const p of rawPlaces) {
    if (p.isActive === false) continue;
    if (!activeDestIds.has(p.destinationId)) continue; // Orphan or inactive parent excluded

    if (!p.id || typeof p.id !== 'string' || p.id.length > 120) {
      blockers.push({ code: 'invalid_place_id', path: `places.${p.id}`, message: 'Place ID must be string <= 120 chars' });
      continue;
    }
    if (!p.name || typeof p.name !== 'string' || p.name.trim().length === 0 || p.name.length > 180) {
      blockers.push({ code: 'invalid_place_name', path: `places.${p.id}.name`, message: 'Place name must be 1-180 characters' });
      continue;
    }

    // Coordinate pair invariant: BOTH or NEITHER!
    const hasLat = p.latitude !== null && p.latitude !== undefined;
    const hasLng = p.longitude !== null && p.longitude !== undefined;
    if (hasLat !== hasLng) {
      blockers.push({
        code: 'coordinate_pair_mismatch',
        path: `places.${p.id}.coordinates`,
        message: 'Both latitude and longitude must be provided together, or both null'
      });
    } else if (hasLat && hasLng) {
      const lat = Number(p.latitude);
      const lng = Number(p.longitude);
      if (!Number.isFinite(lat) || lat < -90 || lat > 90) {
        blockers.push({ code: 'latitude_out_of_range', path: `places.${p.id}.latitude`, message: 'Latitude must be between -90 and 90' });
      }
      if (!Number.isFinite(lng) || lng < -180 || lng > 180) {
        blockers.push({ code: 'longitude_out_of_range', path: `places.${p.id}.longitude`, message: 'Longitude must be between -180 and 180' });
      }
    }

    if (Array.isArray(p.sourceRefs)) {
      for (const s of p.sourceRefs) referencedSourceIds.add(String(s));
    }

    activePlaceIds.add(p.id);

    const projectedPlace = {
      id: p.id,
      destinationId: p.destinationId,
      name: p.name.trim(),
      slug: (p.slug || p.id).trim(),
      description: (p.description || '').trim(),
      imageUrl: p.imageUrl || null,
      imageRights: p.imageRights || null,
      latitude: hasLat ? Number(p.latitude) : null,
      longitude: hasLng ? Number(p.longitude) : null,
      sourceRefs: Array.isArray(p.sourceRefs) ? p.sourceRefs : [],
    };

    activePlaces.push(projectedPlace);

    const parentDest = destMap.get(p.destinationId);
    if (parentDest) {
      parentDest.places.push(projectedPlace);
    }
  }

  // Sort nested places
  for (const d of activeDestinations) {
    d.places.sort((a, b) => a.id.localeCompare(b.id));
  }

  // Sources projection: only referenced sources
  const projectedSources = [];
  for (const s of rawSources) {
    if (referencedSourceIds.has(String(s.id))) {
      projectedSources.push({
        id: String(s.id),
        title: s.title || '',
        publisher: s.publisher || '',
        url: s.url || '',
        checkedAt: s.checkedAt || null,
      });
    }
  }
  projectedSources.sort((a, b) => a.id.localeCompare(b.id));

  // Visit details places projection: only active places
  const projectedVisitPlaces = [];
  for (const vp of rawVisitPlaces) {
    const pid = vp.placeId || vp.id;
    if (activePlaceIds.has(pid)) {
      projectedVisitPlaces.push(vp);
    }
  }
  projectedVisitPlaces.sort((a, b) => ((a.placeId || a.id) || '').localeCompare((b.placeId || b.id) || ''));

  const bundle = {
    contract: 'travelgo.discovery.release.v2',
    schemaVersion: 2,
    version,
    preparedAt,
    catalogue: {
      sources: projectedSources,
      destinations: activeDestinations,
    },
    visitDetails: {
      sources: projectedSources,
      packages: rawPackages,
      places: projectedVisitPlaces,
    },
  };

  return { bundle, blockers, warnings };
}

export function encodePublicBundle(bundle) {
  const payloadText = JSON.stringify(bundle, null, 2);
  const bytes = Buffer.from(payloadText, 'utf8');
  const sha256 = crypto.createHash('sha256').update(bytes).digest('hex');
  const byteLength = bytes.length;

  return { payloadText, bytes, sha256, byteLength };
}
