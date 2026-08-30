export type SplitMethod = "EQUAL" | "EXACT" | "PERCENTAGE" | "SHARES" | "ITEMIZED";

export type WeightedShare = { userId: string; value: number };
export type ItemizedShare = { amountMinor: number; participantIds: string[] };

export type SplitInput =
  | { method: "EQUAL"; participantIds: string[] }
  | { method: "EXACT"; shares: WeightedShare[] }
  | { method: "PERCENTAGE"; shares: WeightedShare[] }
  | { method: "SHARES"; shares: WeightedShare[] }
  | { method: "ITEMIZED"; items: ItemizedShare[] };

export type CalculatedShare = { userId: string; amountMinor: number };

export function calculateSplits(totalMinor: number, input: SplitInput): CalculatedShare[] {
  assertMinorUnits(totalMinor);
  if (input.method === "EQUAL") return allocateByWeights(totalMinor, unique(input.participantIds).map((userId) => ({ userId, value: 1 })));
  if (input.method === "EXACT") {
    validateShares(input.shares, true);
    if (input.shares.reduce((sum, share) => sum + share.value, 0) !== totalMinor) throw new Error("Exact splits must equal the expense total.");
    return sortShares(input.shares.map(({ userId, value }) => ({ userId, amountMinor: value })));
  }
  if (input.method === "PERCENTAGE") {
    validateShares(input.shares, true);
    if (input.shares.reduce((sum, share) => sum + share.value, 0) !== 10_000) throw new Error("Percentage splits must total 100%.");
    return allocateByWeights(totalMinor, input.shares);
  }
  if (input.method === "SHARES") {
    validateShares(input.shares, false);
    return allocateByWeights(totalMinor, input.shares);
  }
  const totals = new Map<string, number>();
  if (input.items.length === 0 || input.items.reduce((sum, item) => sum + item.amountMinor, 0) !== totalMinor) throw new Error("Itemized splits must equal the expense total.");
  for (const item of input.items) {
    assertMinorUnits(item.amountMinor);
    for (const share of allocateByWeights(item.amountMinor, unique(item.participantIds).map((userId) => ({ userId, value: 1 })))) {
      totals.set(share.userId, (totals.get(share.userId) ?? 0) + share.amountMinor);
    }
  }
  return sortShares([...totals].map(([userId, amountMinor]) => ({ userId, amountMinor })));
}

export function convertSplits(shares: CalculatedShare[], convertedTotalMinor: number): CalculatedShare[] {
  assertMinorUnits(convertedTotalMinor);
  const originalTotal = shares.reduce((sum, share) => sum + share.amountMinor, 0);
  if (originalTotal <= 0) throw new Error("Splits must have a positive total.");
  return allocateByWeights(convertedTotalMinor, shares.map(({ userId, amountMinor }) => ({ userId, value: amountMinor })));
}

function allocateByWeights(totalMinor: number, shares: WeightedShare[]): CalculatedShare[] {
  validateShares(shares, false);
  const denominator = shares.reduce((sum, share) => sum + share.value, 0);
  const allocations = shares.map((share) => {
    const raw = totalMinor * share.value;
    return { userId: share.userId, amountMinor: Math.floor(raw / denominator), remainder: raw % denominator };
  });
  const remaining = totalMinor - allocations.reduce((sum, share) => sum + share.amountMinor, 0);
  allocations.sort((left, right) => right.remainder - left.remainder || left.userId.localeCompare(right.userId));
  for (let index = 0; index < remaining; index += 1) allocations[index]!.amountMinor += 1;
  return sortShares(allocations.map(({ userId, amountMinor }) => ({ userId, amountMinor })));
}

function validateShares(shares: WeightedShare[], allowZero: boolean): void {
  if (shares.length === 0 || unique(shares.map((share) => share.userId)).length !== shares.length) throw new Error("Split participants must be non-empty and unique.");
  if (shares.some((share) => !Number.isSafeInteger(share.value) || (allowZero ? share.value < 0 : share.value <= 0))) throw new Error("Split values must use valid integer units.");
}

function assertMinorUnits(amount: number): void {
  if (!Number.isSafeInteger(amount) || amount <= 0) throw new Error("Amount must be a positive integer in minor units.");
}

function unique(values: string[]): string[] { return [...new Set(values)]; }
function sortShares(shares: CalculatedShare[]): CalculatedShare[] { return shares.sort((a, b) => a.userId.localeCompare(b.userId)); }
