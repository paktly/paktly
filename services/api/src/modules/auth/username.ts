export const USERNAME_PATTERN = /^[a-z0-9](?:[a-z0-9_]{1,28}[a-z0-9])$/;

export function normalizeUsername(value: string): string {
  return value.trim().toLowerCase().replace(/\s+/g, "_");
}

export function isValidUsername(value: string): boolean {
  return USERNAME_PATTERN.test(value);
}
