import { Message, hasMedia } from '../models/Message';
import { downloadMediaAsBase64, isWebAccessibleURL } from '../services/mediaService';

export type GeminiRole = 'user' | 'model';

export type GeminiPart =
  | {
      inline_data: {
        mime_type: string;
        data: string;
      };
    }
  | {
      text: string;
    };

export interface GeminiMessage {
  role: GeminiRole;
  parts: GeminiPart[];
}

const buildInlineData = (mimeType: string, data: string): GeminiPart => ({
  inline_data: {
    mime_type: mimeType,
    data,
  },
});

export const buildGeminiPayload = async (
  messages: Message[],
  includeMedia: boolean
): Promise<GeminiMessage[]> => {
  const payload: GeminiMessage[] = [];

  for (const message of messages) {
    const parts: GeminiPart[] = [];

    // Only include media if URL is web-accessible (skip local file:// paths from iOS)
    if (includeMedia && hasMedia(message) && message.mediaURL && message.mediaMimeType) {
      if (isWebAccessibleURL(message.mediaURL)) {
        try {
          const { data, mimeType } = await downloadMediaAsBase64(
            message.mediaURL,
            message.mediaMimeType
          );
          parts.push(buildInlineData(mimeType, data));
        } catch (error) {
          // Silently skip media that can't be downloaded
          console.warn('Skipping media attachment:', error);
        }
      }
    }

    if (message.content.trim().length > 0) {
      parts.push({ text: message.content });
    }

    if (parts.length === 0) {
      continue;
    }

    payload.push({
      role: message.role,
      parts,
    });
  }

  return payload;
};

export const attachMediaToMessage = (
  message: Message,
  mediaData: string,
  mediaMimeType: string
): Message => ({
  ...message,
  mediaURL: `data:${mediaMimeType};base64,${mediaData}`,
  mediaMimeType,
});
