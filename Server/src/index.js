// Handover AI proxy (Cloudflare Worker).
// The iOS app sends room photos here; this Worker adds the prompts and the
// Gemini API key, calls Gemini, validates the JSON and returns it.
// Photos are never stored.

import {
  CONDITIONS, CLEANLINESS, CHANGES,
  describeSystemPrompt, describeUserPrompt, describeSchema,
  compareSystemPrompt, compareUserPrompt, compareSchema,
} from './prompts.js';

const REGIONS = new Set(['GB', 'IE', 'AU', 'NZ', 'US', 'CA']);
const MAX_BODY_BYTES = 12 * 1024 * 1024;
const MAX_IMAGES = 10;
const GEMINI_BASE = 'https://generativelanguage.googleapis.com/v1beta/models';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'GET' && url.pathname === '/health') {
      return json({ ok: true, model: env.GEMINI_MODEL || null });
    }
    if (request.method !== 'POST') return json({ error: 'Not found.' }, 404);

    if (!env.GEMINI_API_KEY || !env.APP_KEY) {
      return json({ error: 'The AI service is not configured yet.' }, 503);
    }
    if (!timingSafeEqual(request.headers.get('X-App-Key') || '', env.APP_KEY)) {
      return json({ error: 'Unauthorised.' }, 401);
    }

    const length = Number(request.headers.get('Content-Length') || 0);
    if (length > MAX_BODY_BYTES) return json({ error: 'Too many or too large photos. Try fewer photos.' }, 413);

    const deviceID = (request.headers.get('X-Device-ID') || '').slice(0, 64);
    if (!/^[A-Za-z0-9-]{8,64}$/.test(deviceID)) return json({ error: 'Missing device identifier.' }, 400);

    if (!(await withinQuota(env, deviceID))) {
      return json({ error: "You've reached today's AI limit. It resets tomorrow." }, 429);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: 'Invalid request.' }, 400);
    }

    try {
      if (url.pathname === '/v1/describe-room') return json(await describeRoom(body, env));
      if (url.pathname === '/v1/compare-room') return json(await compareRoom(body, env));
      return json({ error: 'Not found.' }, 404);
    } catch (error) {
      const status = error.status || 502;
      return json({ error: error.publicMessage || 'The AI service is busy. Please try again in a moment.' }, status);
    }
  },
};

// MARK: Routes

async function describeRoom(body, env) {
  const region = REGIONS.has(body.region) ? body.region : 'GB';
  const images = cleanImages(body.images);
  if (!images.length) throw publicError('Take at least one photo of the room first.', 400);

  const items = cleanStrings(body.items, 40, 80);
  const result = await callGemini(env, {
    system: describeSystemPrompt(region),
    text: describeUserPrompt({
      roomName: cleanString(body.roomName, 80) || 'Room',
      roomType: cleanString(body.roomType, 40) || 'room',
      furnishing: (cleanString(body.furnishing, 30) || 'unfurnished').toLowerCase(),
      items,
    }),
    images,
    schema: describeSchema,
  });

  return {
    summary: cleanString(result.summary, 600),
    items: (Array.isArray(result.items) ? result.items : []).slice(0, 60).map((item) => ({
      name: cleanString(item.name, 80) || 'Item',
      description: cleanString(item.description, 700),
      condition: oneOf(item.condition, CONDITIONS, 'good'),
      cleanliness: oneOf(item.cleanliness, CLEANLINESS, 'clean'),
    })),
  };
}

async function compareRoom(body, env) {
  const region = REGIONS.has(body.region) ? body.region : 'GB';
  const currency = /^[A-Z]{3}$/.test(body.currency || '') ? body.currency : 'GBP';
  const baseline = cleanImages(body.baselineImages).slice(0, 5);
  const current = cleanImages(body.currentImages).slice(0, 5);
  if (!current.length) throw publicError('Take at least one photo of the room first.', 400);

  const items = (Array.isArray(body.items) ? body.items : []).slice(0, 40).map((item) => ({
    name: cleanString(item.name, 80),
    baselineDescription: cleanString(item.baselineDescription, 500),
    baselineCondition: cleanString(item.baselineCondition, 30),
    baselineCleanliness: cleanString(item.baselineCleanliness, 30),
  })).filter((item) => item.name);

  const result = await callGemini(env, {
    system: compareSystemPrompt(region, currency),
    text: compareUserPrompt({ roomName: cleanString(body.roomName, 80) || 'Room', items, baselineCount: baseline.length, currentCount: current.length }),
    images: [...baseline, ...current],
    schema: compareSchema,
  });

  return {
    summary: cleanString(result.summary, 600),
    items: (Array.isArray(result.items) ? result.items : []).slice(0, 60).map((item) => {
      const change = oneOf(item.change, CHANGES, 'notVisible');
      const chargeable = change === 'cleaning' || change === 'damage' || change === 'missing';
      const deduction = Number(item.suggestedDeduction);
      return {
        name: cleanString(item.name, 80) || 'Item',
        change,
        note: cleanString(item.note, 500),
        description: cleanString(item.description, 700),
        condition: oneOf(item.condition, CONDITIONS, 'good'),
        cleanliness: oneOf(item.cleanliness, CLEANLINESS, 'clean'),
        suggestedDeduction: chargeable && Number.isFinite(deduction) ? Math.max(0, Math.min(Math.round(deduction), 5000)) : 0,
      };
    }),
  };
}

// MARK: Gemini

async function callGemini(env, { system, text, images, schema }) {
  const models = [env.GEMINI_MODEL || 'gemini-3.8-flash', ...String(env.GEMINI_FALLBACK_MODELS || '').split(',')]
    .map((model) => model.trim())
    .filter(Boolean);

  const payload = {
    systemInstruction: { parts: [{ text: system }] },
    contents: [{
      role: 'user',
      parts: [{ text }, ...images.map((data) => ({ inlineData: { mimeType: 'image/jpeg', data } }))],
    }],
    generationConfig: {
      temperature: 0.2,
      responseMimeType: 'application/json',
      responseSchema: schema,
    },
  };

  let lastStatus = 0;
  for (const model of [...new Set(models)]) {
    const response = await fetch(`${GEMINI_BASE}/${encodeURIComponent(model)}:generateContent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': env.GEMINI_API_KEY },
      body: JSON.stringify(payload),
    });
    lastStatus = response.status;
    if (response.ok) {
      const data = await response.json();
      const textOut = (data?.candidates?.[0]?.content?.parts || []).map((part) => part.text || '').join('');
      const parsed = parseJSON(textOut);
      if (parsed) return parsed;
      throw publicError('The AI returned something unexpected. Please try again.', 502);
    }
    // Try the next model when this one is unavailable, retired or overloaded.
    if (![404, 429, 500, 503].includes(response.status)) break;
  }
  console.error('Gemini request failed', lastStatus);
  throw publicError('The AI service is busy. Please try again in a moment.', lastStatus === 429 ? 503 : 502);
}

function parseJSON(text) {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    const start = text.indexOf('{');
    const end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try { return JSON.parse(text.slice(start, end + 1)); } catch { return null; }
    }
    return null;
  }
}

// MARK: Quota

async function withinQuota(env, deviceID) {
  if (!env.QUOTA) return true;
  const limit = Number(env.DAILY_LIMIT || 150);
  const day = new Date().toISOString().slice(0, 10);
  const key = `q:${day}:${deviceID}`;
  const used = Number((await env.QUOTA.get(key)) || 0);
  if (used >= limit) return false;
  await env.QUOTA.put(key, String(used + 1), { expirationTtl: 60 * 60 * 36 });
  return true;
}

// MARK: Helpers

function cleanImages(list) {
  if (!Array.isArray(list)) return [];
  return list
    .filter((item) => typeof item === 'string' && item.length > 100 && item.length < 4_000_000 && /^[A-Za-z0-9+/=\s]+$/.test(item.slice(0, 200)))
    .slice(0, MAX_IMAGES);
}

function cleanString(value, max) {
  if (typeof value !== 'string') return '';
  return value.replace(/[\u0000-\u001f]/g, ' ').trim().slice(0, max);
}

function cleanStrings(list, maxCount, maxLength) {
  if (!Array.isArray(list)) return [];
  return list.map((item) => cleanString(item, maxLength)).filter(Boolean).slice(0, maxCount);
}

function oneOf(value, allowed, fallback) {
  return allowed.includes(value) ? value : fallback;
}

function publicError(message, status) {
  const error = new Error(message);
  error.publicMessage = message;
  error.status = status;
  return error;
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' },
  });
}

export const _test = { parseJSON, cleanImages, oneOf, timingSafeEqual };
