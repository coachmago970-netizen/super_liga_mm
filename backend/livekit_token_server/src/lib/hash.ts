import { createHmac } from "node:crypto";

export function hmacSha256(value: string, pepper: string): string {
  return createHmac("sha256", pepper).update(value).digest("hex");
}
