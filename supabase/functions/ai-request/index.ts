// JWT verification is owned here through the trusted Auth endpoint, not decoded locally.
// Disabled by default; no real private/free-text context is accepted by the core.
import { createGateway } from './gateway.mjs';

const handle = createGateway({
  projectUrl: Deno.env.get('SUPABASE_URL'),
  publicKey: Deno.env.get('SUPABASE_ANON_KEY'),
  serviceKey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),
  geminiKey: Deno.env.get('GEMINI_API_KEY'),
  enabled: Deno.env.get('TRAVELGO_AI_ENABLED') === 'true',
  syntheticOnly: Deno.env.get('TRAVELGO_AI_SYNTHETIC_ONLY') === 'true',
  allowedSubjects: (Deno.env.get('TRAVELGO_AI_ALLOWED_SUBJECTS') ?? '').split(',').filter(Boolean),
});

Deno.serve(handle);
