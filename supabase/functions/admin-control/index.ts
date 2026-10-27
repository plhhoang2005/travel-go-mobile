// Edge Function Entry: admin-control
// Contract: travelgo.admin.v1
import { createAdminControl } from './gateway.mjs';

declare const Deno: {
  env: {
    get(name: string): string | undefined;
  };
  serve(handler: (request: Request) => Promise<Response>): void;
};

const handle = createAdminControl({
  projectUrl: Deno.env.get('SUPABASE_URL'),
  serviceKey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),
});

Deno.serve(handle);
