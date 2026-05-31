import { describe, expect, it } from "vitest";
import { buildLiveKitToken } from "../src/lib/livekit.js";

function decodePayload(token: string): Record<string, any> {
  const payload = token.split(".")[1];
  const decoded = Buffer.from(payload, "base64url").toString("utf8");
  return JSON.parse(decoded) as Record<string, any>;
}

describe("buildLiveKitToken", () => {
  it("creates publish-enabled grant", async () => {
    const jwt = await buildLiveKitToken({
      apiKey: "test",
      apiSecret: "secret",
      userId: "u1",
      roomName: "room-a",
      canPublish: true,
      allowScreenShare: true
    });
    const payload = decodePayload(jwt);
    expect(payload.video.roomJoin).toBe(true);
    expect(payload.video.canPublish).toBe(true);
    expect(payload.video.canPublishSources).toEqual(
      expect.arrayContaining(["camera", "microphone", "screen_share", "screen_share_audio"])
    );
  });

  it("creates listen-only grant when publishing is blocked", async () => {
    const jwt = await buildLiveKitToken({
      apiKey: "test",
      apiSecret: "secret",
      userId: "u2",
      roomName: "room-b",
      canPublish: false,
      allowScreenShare: false
    });
    const payload = decodePayload(jwt);
    expect(payload.video.roomJoin).toBe(true);
    expect(payload.video.canPublish).toBe(false);
    expect(payload.video.canPublishSources).toEqual([]);
  });
});
