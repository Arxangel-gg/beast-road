// Beast Road — TURN credential minter.
//
// Cloudflare's TURN service does not issue long-lived credentials. A backend
// holds a TURN Key and mints short-lived ones on request, which is the correct
// shape: the key never reaches a player's machine, and a credential that leaks
// expires by itself.
//
// That backend is this, and it is deliberately the smallest thing that can do
// the job — no state, no database, no dependencies. It exists because the game
// runs in a browser and a browser cannot keep a secret.
//
// Deploy: see tools/turn-worker/README.md
// Secrets: TURN_KEY_ID, TURN_KEY_API_TOKEN

const TTL_SECONDS = 86400;          // A day. Longer than any session.
const CACHE_SECONDS = 3600;         // Mint once an hour, not once a player.

export default {
  async fetch(request, env, ctx) {
    // The game is served from a page; a browser will preflight this.
    const cors = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    };
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }
    if (request.method !== "GET") {
      return new Response("GET only", { status: 405, headers: cors });
    }

    if (!env.TURN_KEY_ID || !env.TURN_KEY_API_TOKEN) {
      // Said plainly rather than returning an empty list: a game that quietly
      // falls back to STUN looks like it works until it meets a player behind
      // a strict router, which is the failure this whole service prevents.
      return new Response(
        JSON.stringify({ error: "TURN_KEY_ID and TURN_KEY_API_TOKEN are not set" }),
        { status: 500, headers: { ...cors, "Content-Type": "application/json" } });
    }

    // Credentials are cached at the edge for an hour. Every player asking for
    // their own would be thousands of pointless API calls and no more secure:
    // they all get the same TTL and the same relay either way.
    const cacheKey = new Request(new URL("/ice", request.url).toString(), request);
    const cache = caches.default;
    const hit = await cache.match(cacheKey);
    if (hit) return new Response(hit.body, { status: 200, headers: { ...cors, "Content-Type": "application/json" } });

    const minted = await fetch(
      `https://rtc.live.cloudflare.com/v1/turn/keys/${env.TURN_KEY_ID}/credentials/generate-ice-servers`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${env.TURN_KEY_API_TOKEN}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ ttl: TTL_SECONDS }),
      });

    if (!minted.ok) {
      const detail = await minted.text();
      return new Response(
        JSON.stringify({ error: "could not mint credentials", status: minted.status, detail: detail.slice(0, 400) }),
        { status: 502, headers: { ...cors, "Content-Type": "application/json" } });
    }

    const body = await minted.text();
    const response = new Response(body, {
      status: 200,
      headers: {
        ...cors,
        "Content-Type": "application/json",
        "Cache-Control": `public, max-age=${CACHE_SECONDS}`,
      },
    });
    ctx.waitUntil(cache.put(cacheKey, response.clone()));
    return response;
  },
};
