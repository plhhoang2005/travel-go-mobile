// No deployment/configuration is implied by this source. Flags default deny.
import { createItineraryGateway } from './gateway.mjs';
const handle=createItineraryGateway({
 projectUrl:Deno.env.get('SUPABASE_URL'),
 publicKey:Deno.env.get('SUPABASE_ANON_KEY'),
 serviceKey:Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),
 geminiKey:Deno.env.get('GEMINI_API_KEY'),
 enabled:Deno.env.get('TRAVELGO_ITINERARY_ENABLED')==='true',
 realContextAllowed:Deno.env.get('TRAVELGO_ITINERARY_REAL_CONTEXT_ALLOWED')==='true',
 allowAnonymousGuests:Deno.env.get('TRAVELGO_ITINERARY_ALLOW_ANONYMOUS_GUESTS')==='true',
 allowedSubjects:(Deno.env.get('TRAVELGO_ITINERARY_ALLOWED_SUBJECTS')??'').split(',').map(v=>v.trim()).filter(Boolean),
 diagnostic:(event:Record<string,unknown>)=>console.warn(JSON.stringify(event)),
});
Deno.serve(handle);
