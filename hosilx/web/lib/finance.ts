export type Entry = { kind: string; amount: number | string; currency: string; planned?: boolean };

/** Valyutalar aralashtirilmaydi: har bir valyuta alohida hisoblanadi. Rejalashtirilganlar kirmaydi. */
export function totalsByCurrency(entries: Entry[]): Record<string, { inc: number; exp: number }> {
  const totals: Record<string, { inc: number; exp: number }> = {};
  for (const e of entries) {
    if (e.planned) continue;
    totals[e.currency] ??= { inc: 0, exp: 0 };
    if (e.kind === "income") totals[e.currency].inc += Number(e.amount);
    else totals[e.currency].exp += Number(e.amount);
  }
  return totals;
}
