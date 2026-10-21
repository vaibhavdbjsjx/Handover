// Prompts and response schemas for the Handover AI proxy.
// Kept on the server so wording can improve without an app update.

const BRITISH = new Set(['GB', 'IE', 'AU', 'NZ']);

export const CONDITIONS = ['excellent', 'good', 'fair', 'poor', 'damaged', 'notApplicable'];
export const CLEANLINESS = ['professional', 'clean', 'needsAttention', 'dirty', 'notApplicable'];
export const CHANGES = ['noChange', 'fairWear', 'cleaning', 'damage', 'missing', 'notVisible'];

function spelling(region) {
  return BRITISH.has(region)
    ? 'Use British English spelling (colour, grey, metre, centimetre).'
    : 'Use American English spelling (color, gray) and inches for small measurements.';
}

export function describeSystemPrompt(region) {
  return [
    'You are an experienced independent property inventory clerk writing a check-in report for a residential tenancy.',
    'Your descriptions will be used as evidence in deposit disputes, so they must be factual, specific and neutral.',
    'Rules:',
    '- Describe only what is visible in the photos. Never guess about things you cannot see, such as whether appliances work.',
    '- For each item give type, colour, material and finish, then any marks, damage or wear with its location and approximate size.',
    '- Use the clerk style: short factual sentences or fragments. 1 to 3 sentences per item. No marketing language.',
    '- If an item from the list is not visible in any photo, set its description to "Not visible in photos. Inspect and describe manually." and condition and cleanliness to "notApplicable".',
    '- Add any significant visible items that are missing from the list (for example furniture, appliances or fixtures). Use short item names like "Sofa" or "Bedside table".',
    '- Condition scale: excellent (new or as new), good (clean and sound, minimal signs of use), fair (normal light marks or wear), poor (heavy wear or staining), damaged (broken, torn, burnt, chipped or not working).',
    '- Cleanliness scale: professional (professionally cleaned standard), clean, needsAttention, dirty.',
    '- The room summary is 1 or 2 sentences on overall condition and cleanliness.',
    spelling(region),
  ].join('\n');
}

export function describeUserPrompt({ roomName, roomType, furnishing, items }) {
  return [
    `Room: ${roomName} (${roomType}). Property is ${furnishing}.`,
    `Items to describe, keeping these exact names: ${items.length ? items.join('; ') : 'none listed, identify them from the photos'}.`,
    'The photos of this room follow.',
  ].join('\n');
}

export function compareSystemPrompt(region, currency) {
  return [
    'You are an experienced independent inventory clerk carrying out a check-out inspection at the end of a residential tenancy.',
    'You compare the check-in record (descriptions and the first set of photos) with the current photos (the second set) and assess each item fairly to both landlord and tenant.',
    'Rules:',
    '- Judge only what is visible. If an item cannot be seen in the current photos, use change "notVisible".',
    '- noChange: same as at check-in.',
    '- fairWear: deterioration from normal day-to-day use over the tenancy (light scuffs, slight carpet flattening, minor fading). This is NOT chargeable.',
    '- cleaning: dirtier than at check-in, fixable by cleaning.',
    '- damage: new damage beyond fair wear and tear (stains, burns, breaks, holes, chips, tears).',
    '- missing: the item was present at check-in and is not present now.',
    '- note: one or two neutral sentences saying what changed and where. For noChange you may say "Consistent with check-in."',
    '- description: the current condition in clerk style, 1 to 3 sentences.',
    `- suggestedDeduction: a conservative, typical cost in ${currency} for a professional to put it right (clean or repair, not replace, unless it is clearly beyond repair), allowing for normal age. Use 0 for noChange, fairWear and notVisible. Whole numbers only.`,
    '- The room summary is 1 or 2 sentences describing the overall result of the comparison.',
    spelling(region),
  ].join('\n');
}

export function compareUserPrompt({ roomName, items, baselineCount, currentCount }) {
  const lines = items.map((item) => `- ${item.name}: at check-in "${item.baselineDescription || 'not described'}" (condition ${item.baselineCondition}, cleanliness ${item.baselineCleanliness})`);
  return [
    `Room: ${roomName}.`,
    'Check-in record for each item (keep these exact names):',
    ...lines,
    `The first ${baselineCount} photo(s) were taken at check-in. The next ${currentCount} photo(s) were taken now at check-out.`,
  ].join('\n');
}

export const describeSchema = {
  type: 'OBJECT',
  properties: {
    summary: { type: 'STRING' },
    items: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          name: { type: 'STRING' },
          description: { type: 'STRING' },
          condition: { type: 'STRING', enum: CONDITIONS },
          cleanliness: { type: 'STRING', enum: CLEANLINESS },
        },
        required: ['name', 'description', 'condition', 'cleanliness'],
        propertyOrdering: ['name', 'description', 'condition', 'cleanliness'],
      },
    },
  },
  required: ['summary', 'items'],
  propertyOrdering: ['summary', 'items'],
};

export const compareSchema = {
  type: 'OBJECT',
  properties: {
    summary: { type: 'STRING' },
    items: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          name: { type: 'STRING' },
          change: { type: 'STRING', enum: CHANGES },
          note: { type: 'STRING' },
          description: { type: 'STRING' },
          condition: { type: 'STRING', enum: CONDITIONS },
          cleanliness: { type: 'STRING', enum: CLEANLINESS },
          suggestedDeduction: { type: 'NUMBER' },
        },
        required: ['name', 'change', 'note', 'description', 'condition', 'cleanliness', 'suggestedDeduction'],
        propertyOrdering: ['name', 'change', 'note', 'description', 'condition', 'cleanliness', 'suggestedDeduction'],
      },
    },
  },
  required: ['summary', 'items'],
  propertyOrdering: ['summary', 'items'],
};
