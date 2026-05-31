import { z } from "zod";

const canonicalUuidLikeRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const uuidLikeSchema = z.string().trim().regex(canonicalUuidLikeRegex, "Invalid UUID format.");
