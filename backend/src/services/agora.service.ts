import { RtcTokenBuilder, RtcRole } from 'agora-access-token';
import { config } from '../config';
import { v4 as uuid } from 'uuid';

const TOKEN_TTL_SECONDS = 3600; // 1 hour

export const generateRtcToken = (channelName: string, uid: number): string => {
  const expiresAt = Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS;
  return RtcTokenBuilder.buildTokenWithUid(
    config.agora.appId,
    config.agora.appCertificate,
    channelName,
    uid,
    RtcRole.PUBLISHER,
    expiresAt
  );
};

export const generateChannelId = (): string => `call_${uuid().replace(/-/g, '')}`;

export const getAgoraAppId = (): string => config.agora.appId;
