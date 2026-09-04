export type IntentHint = "CREATE_PLAN" | "CREATE_EXPENSE" | "INVITE_PERSON" | null;

export function deterministicIntent(prompt: string): IntentHint {
  const normalized = prompt.toLowerCase().replace(/[^a-z0-9@.$€£¥\s_-]/g, " ").replace(/\s+/g, " ").trim();
  if (/\b(create|start|make|set up|setup)\b.{0,36}\b(plan|trip|group|goal)\b/.test(normalized)) return "CREATE_PLAN";
  if (/\b(create|start|make|set up|setup|add)\b.{0,48}\b(saving|savings)\s+(plan|goal)\b/.test(normalized)) return "CREATE_PLAN";
  if (/\b(add|set|put)\b.{0,24}(?:[$€£¥]\s*\d|\b\d+(?:[.,]\d{1,2})?\s*(?:usd|eur|gbp|jpy|dollars?|euros?|pounds?)\b).{0,24}\b(?:to|into|as|for)\s+(?:a\s+)?savings?\s+for\b/.test(normalized)) return "CREATE_PLAN";
  if (/\b(save|saved|saving|contribute|contributed|contribution|deposit|deposited|transfer|transferred|settle|settled)\b/.test(normalized)) return null;
  if (/\b(invite|bring|add)\b.{0,60}(@|\bto\b.{0,30}\b(plan|trip|group)\b)/.test(normalized) && !hasMoney(normalized)) return "INVITE_PERSON";
  if (hasMoney(normalized) || /\b(paid|spent|cost|expense|dinner|lunch|breakfast|taxi|uber|hotel|tickets?)\b/.test(normalized)) return "CREATE_EXPENSE";
  return null;
}

export function deterministicPlanId(
  prompt: string,
  plans: Iterable<{ id: string; name: string }>,
  contextPlanId?: string
): string | undefined {
  const normalized = normalize(prompt);
  const matches = [...plans].filter((plan) => normalized.includes(normalize(plan.name)));
  if (matches.length === 1) return matches[0]!.id;
  return matches.length === 0 ? contextPlanId : undefined;
}

function hasMoney(value: string): boolean {
  return /(?:[$€£¥]\s*\d|\b\d+(?:[.,]\d{1,2})?\s*(?:usd|eur|gbp|jpy|dollars?|euros?|pounds?)\b)/.test(value);
}

function normalize(value: string): string {
  return value.toLowerCase().normalize("NFKD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]+/g, " ").trim();
}
