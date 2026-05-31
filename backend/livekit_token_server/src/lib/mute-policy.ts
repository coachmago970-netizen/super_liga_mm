export function isMuteStillActive(expiresAt: string | null, now = Date.now()): boolean {
  if (!expiresAt) return true;
  const parsed = new Date(expiresAt);
  if (Number.isNaN(parsed.getTime())) return false;
  return parsed.getTime() > now;
}
