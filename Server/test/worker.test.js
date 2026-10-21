import { test } from 'node:test';
import assert from 'node:assert/strict';
import worker, { _test } from '../src/index.js';

const env = { GEMINI_API_KEY: 'g-key', APP_KEY: 'app-secret', GEMINI_MODEL: 'model-a', GEMINI_FALLBACK_MODELS: 'model-b' };
const image = 'A'.repeat(400);
const headers = { 'Content-Type': 'application/json', 'X-App-Key': 'app-secret', 'X-Device-ID': '3F2504E0-4F89-11D3-9A0C-0305E82C3301' };

function geminiReply(obj) {
  return new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify(obj) }] } }] }), { status: 200 });
}

test('rejects a wrong app key', async () => {
  const res = await worker.fetch(new Request('https://x/v1/describe-room', { method: 'POST', headers: { ...headers, 'X-App-Key': 'nope' }, body: '{}' }), env);
  assert.equal(res.status, 401);
});

test('describe-room normalises the model output', async () => {
  let sent;
  globalThis.fetch = async (url, init) => { sent = { url, body: JSON.parse(init.body), headers: init.headers }; return geminiReply({ summary: 'Clean room.', items: [{ name: 'Walls', description: 'White emulsion.', condition: 'good', cleanliness: 'clean' }, { name: 'Sofa', description: 'Grey fabric.', condition: 'weird', cleanliness: 'dirty' }] }); };
  const res = await worker.fetch(new Request('https://x/v1/describe-room', { method: 'POST', headers, body: JSON.stringify({ region: 'GB', roomName: 'Living room', roomType: 'Living room', furnishing: 'Furnished', items: ['Walls'], images: [image] }) }), env);
  assert.equal(res.status, 200);
  const data = await res.json();
  assert.equal(data.items.length, 2);
  assert.equal(data.items[1].condition, 'good');
  assert.match(sent.url, /model-a:generateContent$/);
  assert.equal(sent.headers['x-goog-api-key'], 'g-key');
  assert.equal(sent.body.contents[0].parts.length, 2);
  assert.equal(sent.body.generationConfig.responseMimeType, 'application/json');
});

test('compare-room falls back to the next model and zeroes non-chargeable deductions', async () => {
  const calls = [];
  globalThis.fetch = async (url) => {
    calls.push(url);
    if (url.includes('model-a')) return new Response('{}', { status: 404 });
    return geminiReply({ summary: 'One stain.', items: [
      { name: 'Flooring', change: 'damage', note: 'Stain.', description: 'Stained.', condition: 'poor', cleanliness: 'clean', suggestedDeduction: 120.4 },
      { name: 'Walls', change: 'fairWear', note: 'Scuffs.', description: 'Scuffed.', condition: 'fair', cleanliness: 'clean', suggestedDeduction: 50 },
    ] });
  };
  const res = await worker.fetch(new Request('https://x/v1/compare-room', { method: 'POST', headers, body: JSON.stringify({ region: 'GB', currency: 'GBP', roomName: 'Lounge', items: [{ name: 'Flooring', baselineDescription: 'Grey carpet', baselineCondition: 'Good', baselineCleanliness: 'Clean' }], baselineImages: [image], currentImages: [image] }) }), env);
  assert.equal(res.status, 200);
  const data = await res.json();
  assert.equal(calls.length, 2);
  assert.equal(data.items[0].suggestedDeduction, 120);
  assert.equal(data.items[1].suggestedDeduction, 0);
});

test('requires photos', async () => {
  const res = await worker.fetch(new Request('https://x/v1/describe-room', { method: 'POST', headers, body: JSON.stringify({ region: 'GB', images: [] }) }), env);
  assert.equal(res.status, 400);
});

test('quota blocks after the daily limit', async () => {
  const store = new Map();
  const kv = { get: async (k) => store.get(k) ?? null, put: async (k, v) => { store.set(k, v); } };
  globalThis.fetch = async () => geminiReply({ summary: '', items: [] });
  const limited = { ...env, QUOTA: kv, DAILY_LIMIT: '1' };
  const make = () => new Request('https://x/v1/describe-room', { method: 'POST', headers, body: JSON.stringify({ images: [image] }) });
  assert.equal((await worker.fetch(make(), limited)).status, 200);
  assert.equal((await worker.fetch(make(), limited)).status, 429);
});

test('parseJSON recovers fenced output', () => {
  assert.deepEqual(_test.parseJSON('```json\n{"a":1}\n```'), { a: 1 });
});
