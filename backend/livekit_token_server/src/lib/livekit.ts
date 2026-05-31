import { AccessToken } from "livekit-server-sdk";
import { TrackSource } from "@livekit/protocol";

export type BuildLiveKitTokenParams = {
  apiKey: string;
  apiSecret: string;
  userId: string;
  displayName?: string | null;
  roomName: string;
  canPublish: boolean;
  allowScreenShare: boolean;
};

export async function buildLiveKitToken(params: BuildLiveKitTokenParams): Promise<string> {
  const accessToken = new AccessToken(params.apiKey, params.apiSecret, {
    identity: params.userId,
    name: params.displayName ?? params.userId,
    ttl: "1h"
  });

  accessToken.addGrant({
    roomJoin: true,
    room: params.roomName,
    canPublish: params.canPublish,
    canSubscribe: true,
    canPublishData: params.canPublish,
    canPublishSources: params.canPublish
      ? params.allowScreenShare
      ? [
          TrackSource.CAMERA,
          TrackSource.MICROPHONE,
          TrackSource.SCREEN_SHARE,
          TrackSource.SCREEN_SHARE_AUDIO
        ]
      : [TrackSource.CAMERA, TrackSource.MICROPHONE]
      : []
  });

  return accessToken.toJwt();
}
