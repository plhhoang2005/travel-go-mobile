// CLI to build actual bundle and manifest fixtures from SQL visibility cases.
// Uses actual validateAndProjectPublicBundle and encodePublicBundle from bundle.mjs.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateAndProjectPublicBundle, encodePublicBundle } from '../supabase/functions/admin-publication/bundle.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..');

const inputPath = process.argv[2]
  ? path.resolve(process.argv[2])
  : path.resolve(repoRoot, '.dart_tool/travelgo-visibility/visibility_cases.json');

const outputDir = process.argv[3]
  ? path.resolve(process.argv[3])
  : path.resolve(repoRoot, '.dart_tool/travelgo-visibility');

if (!fs.existsSync(inputPath)) {
  console.error(`Input file not found: ${inputPath}`);
  process.exit(1);
}

fs.mkdirSync(outputDir, { recursive: true });

const rawInput = fs.readFileSync(inputPath, 'utf8').replace(/^\uFEFF/, '').trim();
let casesDoc;
try {
  casesDoc = JSON.parse(rawInput);
} catch (e) {
  console.error(`Failed to parse input JSON from ${inputPath}: ${e.message}`);
  process.exit(1);
}

const caseNames = ['baseline', 'created', 'updated', 'archived'];
const flowFixtures = {
  contract: 'travelgo.flow.fixtures.v1',
  builtAt: new Date().toISOString(),
  cases: {},
};

for (const caseName of caseNames) {
  const caseData = casesDoc[caseName];
  if (!caseData || !caseData.payload) {
    console.error(`Missing case or payload for: ${caseName}`);
    process.exit(1);
  }

  const version = caseData.revision || 1;
  const preparedAt = new Date().toISOString();

  const { bundle, blockers, warnings } = validateAndProjectPublicBundle({
    frozenDraft: caseData.payload,
    version,
    preparedAt,
  });

  if (blockers.length > 0) {
    console.error(`Blockers projecting bundle for case ${caseName}: ${JSON.stringify(blockers)}`);
    process.exit(1);
  }

  const encoded = encodePublicBundle(bundle);

  const manifest = {
    contract: 'travelgo.discovery.manifest.v2',
    schemaVersion: 2,
    version,
    objectKey: `releases/v2/${version}.json`,
    sha256: encoded.sha256,
    byteLength: encoded.byteLength,
    publishedAt: preparedAt,
  };

  const bundleFilePath = path.join(outputDir, `${caseName}_bundle.json`);
  const manifestFilePath = path.join(outputDir, `${caseName}_manifest.json`);

  fs.writeFileSync(bundleFilePath, encoded.payloadText, 'utf8');
  fs.writeFileSync(manifestFilePath, JSON.stringify(manifest, null, 2), 'utf8');

  flowFixtures.cases[caseName] = {
    caseName,
    revision: version,
    destinationId: caseData.destinationId,
    placeId: caseData.placeId,
    manifest,
    bundlePayloadText: encoded.payloadText,
    adminPayload: caseData.payload,
    activeDestinationsCount: bundle.catalogue.destinations.length,
    activePlacesCount: bundle.catalogue.destinations.reduce((acc, d) => acc + (d.places ? d.places.length : 0), 0),
    visitPlacesCount: bundle.visitDetails.places.length,
  };
}

const summaryFilePath = path.join(outputDir, 'flow_fixtures.json');
fs.writeFileSync(summaryFilePath, JSON.stringify(flowFixtures, null, 2), 'utf8');

console.log(JSON.stringify({
  status: 'ok',
  outputDir,
  casesCount: Object.keys(flowFixtures.cases).length,
  summaryFile: summaryFilePath,
}));
