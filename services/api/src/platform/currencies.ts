const supportedCurrencyCodes = new Set(Intl.supportedValuesOf("currency"));

export function isSupportedCurrency(code: string): boolean {
  return supportedCurrencyCodes.has(code.toUpperCase());
}

export function currencyDisplayName(code: string): string {
  return new Intl.DisplayNames(["en"], { type: "currency" }).of(code.toUpperCase()) ?? code.toUpperCase();
}
