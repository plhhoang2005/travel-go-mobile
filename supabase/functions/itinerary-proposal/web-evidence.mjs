// TravelGO: Google Search Grounding normalization for Web Advice (W2)
// Extracts factual citations, normalizes byte-offset segments, and maps into EvidenceRecord & EvidenceClaim.

const DEFAULT_WARNING = 'Thông tin từ Internet, chưa được Admin kiểm duyệt: kiểm tra lại trước khi thực hiện.';

const utf8Encoder = new TextEncoder();
const utf8Decoder = new TextDecoder('utf-8', { fatal: false });

/**
 * Safely slices text using UTF-8 byte offsets (as specified by Google Gemini v1beta).
 */
export function sliceUtf8Bytes(fullText, startIndex = 0, endIndex) {
  if (typeof fullText !== 'string' || fullText.length === 0) return '';
  const bytes = utf8Encoder.encode(fullText);
  const start = Math.max(0, Math.min(Number.isSafeInteger(startIndex) ? startIndex : 0, bytes.length));
  const end = Math.min(Number.isSafeInteger(endIndex) ? endIndex : bytes.length, bytes.length);
  if (end <= start) return '';
  return utf8Decoder.decode(bytes.subarray(start, end));
}

/**
 * Validates a web URI according to TravelGO security rules:
 * Must be HTTPS or HTTP, cannot exceed 2048 chars, no javascript:, data:, file:, etc.
 */
export function isValidWebUri(uri) {
  if (typeof uri !== 'string' || uri.trim().length === 0 || uri.length > 2048) return false;
  try {
    const parsed = new URL(uri.trim());
    return parsed.protocol === 'https:' || parsed.protocol === 'http:';
  } catch {
    return false;
  }
}

/**
 * Computes a deterministic evidence ID from URI or chunk index.
 */
function makeEvidenceId(uri, chunkIndex) {
  try {
    const parsed = new URL(uri);
    const hostPart = parsed.hostname.replace(/[^a-z0-9]/gi, '-').toLowerCase();
    const pathPart = parsed.pathname.replace(/[^a-z0-9]/gi, '-').slice(0, 24).toLowerCase();
    return `web:${hostPart}${pathPart.length > 0 ? '-' + pathPart : ''}-${chunkIndex}`;
  } catch {
    return `web:chunk-${chunkIndex}`;
  }
}

/**
 * Normalizes Google Search Grounding candidate into TravelGO structured evidence & claims.
 *
 * @param {object} params
 * @param {object} params.candidate - Gemini candidate object with content and groundingMetadata
 * @param {string} [params.retrievedAt] - ISO timestamp of retrieval
 * @param {string} [params.destinationName] - Destination context
 * @param {string[]} [params.travelDates] - Trip travel dates
 * @returns {object} { summary, evidence, claims, searchQueries, searchEntryPoint, warnings }
 */
export function normalizeGoogleGrounding({
  candidate,
  retrievedAt,
  destinationName,
  travelDates,
}) {
  const parts = candidate?.content?.parts;
  const summary = Array.isArray(parts)
    ? parts
        .filter(p => p && p.thought !== true && typeof p.text === 'string')
        .map(p => p.text)
        .join('\n')
        .trim()
    : '';

  const effectiveRetrievedAt = typeof retrievedAt === 'string' && Number.isFinite(Date.parse(retrievedAt))
    ? retrievedAt
    : new Date().toISOString();

  const metadata = candidate?.groundingMetadata;
  const warnings = [DEFAULT_WARNING];

  if (!metadata || typeof metadata !== 'object') {
    return {
      summary,
      evidence: [],
      claims: [],
      searchQueries: [],
      searchEntryPoint: null,
      warnings,
    };
  }

  // 1. Extract and sanitize web search queries
  const searchQueries = Array.isArray(metadata.webSearchQueries)
    ? metadata.webSearchQueries
        .filter(q => typeof q === 'string' && q.trim().length > 0)
        .map(q => q.trim())
    : [];

  // 2. Extract and sanitize grounding chunks (sources)
  const evidence = [];
  const chunkIndexToEvidenceId = new Map();
  const rawChunks = Array.isArray(metadata.groundingChunks) ? metadata.groundingChunks : [];

  for (let i = 0; i < rawChunks.length; i++) {
    const chunk = rawChunks[i];
    const web = chunk?.web;
    if (web && typeof web === 'object') {
      const uri = typeof web.uri === 'string' ? web.uri.trim() : '';
      const title = typeof web.title === 'string' ? web.title.trim() : '';
      if (isValidWebUri(uri)) {
        const id = makeEvidenceId(uri, i);
        evidence.push({
          id,
          origin: 'web',
          url: uri,
          sourceUri: uri,
          title: title.length > 0 ? title : uri,
          sourceTitle: title.length > 0 ? title : uri,
          factKey: 'general',
          factValue: title.length > 0 ? title : uri,
          retrievedAt: effectiveRetrievedAt,
          reviewed: false,
        });
        chunkIndexToEvidenceId.set(i, id);
      }
    }
  }

  // 3. Extract and map grounding supports into claims
  const claims = [];
  const rawSupports = Array.isArray(metadata.groundingSupports) ? metadata.groundingSupports : [];

  for (let i = 0; i < rawSupports.length; i++) {
    const support = rawSupports[i];
    const segment = support?.segment;
    const startIndex = segment?.startIndex ?? 0;
    const endIndex = segment?.endIndex;

    const extractedText = sliceUtf8Bytes(summary, startIndex, endIndex);
    const fallbackText = typeof segment?.text === 'string' && segment.text.trim().length > 0
      ? segment.text.trim()
      : extractedText.trim();

    const rawIndices = Array.isArray(support?.groundingChunkIndices) ? support.groundingChunkIndices : [];
    const matchedSourceIds = rawIndices
      .filter(idx => Number.isInteger(idx) && chunkIndexToEvidenceId.has(idx))
      .map(idx => chunkIndexToEvidenceId.get(idx));

    if (matchedSourceIds.length > 0 && fallbackText.length > 0) {
      claims.push({
        id: `claim:web:${i}`,
        kind: 'fact',
        field: 'advice',
        text: fallbackText,
        context: fallbackText,
        evidenceIds: matchedSourceIds,
        sourceIds: matchedSourceIds,
      });
    }
  }

  const searchEntryPoint = metadata.searchEntryPoint?.renderedContent
    ? { renderedContent: metadata.searchEntryPoint.renderedContent }
    : null;

  const trimmedEvidence = evidence.slice(0, 8);
  const allowedEvidenceIds = new Set(trimmedEvidence.map(e => e.id));
  const filteredClaims = claims
    .filter(c => c.evidenceIds.some(id => allowedEvidenceIds.has(id)))
    .slice(0, 10);

  return {
    summary: summary.slice(0, 4000),
    evidence: trimmedEvidence,
    claims: filteredClaims,
    searchQueries: searchQueries.slice(0, 5),
    searchEntryPoint,
    warnings,
  };
}

