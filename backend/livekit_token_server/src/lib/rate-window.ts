const windows = new Map<string, number[]>();

export function enforceInMemoryRateLimit(params: {
  key: string;
  limit: number;
  windowMs: number;
}): { ok: true } | { ok: false; retryInMs: number } {
  const now = Date.now();
  const windowStart = now - params.windowMs;
  const entry = windows.get(params.key) ?? [];
  const recent = entry.filter((ts) => ts > windowStart);

  if (recent.length >= params.limit) {
    const oldestInWindow = recent[0];
    return { ok: false, retryInMs: oldestInWindow + params.windowMs - now };
  }

  recent.push(now);
  windows.set(params.key, recent);
  return { ok: true };
}
