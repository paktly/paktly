export type MemberBalance = { userId: string; netMinor: number };
export type SuggestedSettlement = { fromUserId: string; toUserId: string; amountMinor: number };

export function simplifyDebts(balances: MemberBalance[]): SuggestedSettlement[] {
  const total = balances.reduce((sum, balance) => sum + balance.netMinor, 0);
  if (total !== 0) throw new Error("Member balances must net to zero.");
  const debtors = balances.filter((item) => item.netMinor < 0).map((item) => ({ userId: item.userId, amount: -item.netMinor })).sort(byAmountThenUser);
  const creditors = balances.filter((item) => item.netMinor > 0).map((item) => ({ userId: item.userId, amount: item.netMinor })).sort(byAmountThenUser);
  const result: SuggestedSettlement[] = [];
  let debtorIndex = 0;
  let creditorIndex = 0;
  while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
    const debtor = debtors[debtorIndex]!;
    const creditor = creditors[creditorIndex]!;
    const amountMinor = Math.min(debtor.amount, creditor.amount);
    result.push({ fromUserId: debtor.userId, toUserId: creditor.userId, amountMinor });
    debtor.amount -= amountMinor;
    creditor.amount -= amountMinor;
    if (debtor.amount === 0) debtorIndex += 1;
    if (creditor.amount === 0) creditorIndex += 1;
  }
  return result;
}

function byAmountThenUser(left: { userId: string; amount: number }, right: { userId: string; amount: number }): number {
  return right.amount - left.amount || left.userId.localeCompare(right.userId);
}
