import { describe, expect, it, vi } from 'vitest';

import type { Message } from '../../models/Message';
import { attachMediaToMessage, buildGeminiPayload } from '../../logic/messagePayload';

vi.mock('../../services/mediaService', () => ({
  downloadMediaAsBase64: vi.fn(async () => ({
    data: 'base64payload',
    mimeType: 'image/png',
  })),
}));

const createMessage = (overrides: Partial<Message>): Message => ({
  id: overrides.id ?? 'm1',
  role: overrides.role ?? 'user',
  content: overrides.content ?? 'Hello',
  createdAt: overrides.createdAt ?? new Date('2024-01-01T00:00:00.000Z'),
  selectedAt: overrides.selectedAt ?? null,
  parentId: overrides.parentId ?? null,
  mediaURL: overrides.mediaURL ?? null,
  mediaMimeType: overrides.mediaMimeType ?? null,
  inputTokens: overrides.inputTokens ?? null,
  outputTokens: overrides.outputTokens ?? null,
  cachedTokens: overrides.cachedTokens ?? null,
  thinkingContent: overrides.thinkingContent ?? null,
});

describe('buildGeminiPayload', () => {
  it('skips empty messages and preserves text parts', async () => {
    const messages = [
      createMessage({ id: 'm1', content: 'Hello' }),
      createMessage({ id: 'm2', content: '   ' }),
    ];

    const payload = await buildGeminiPayload(messages, false);

    expect(payload).toEqual([
      {
        role: 'user',
        parts: [{ text: 'Hello' }],
      },
    ]);
  });

  it('inlines media before text when includeMedia is true', async () => {
    const messageWithMedia = createMessage({
      id: 'm1',
      role: 'user',
      content: 'Hello',
      mediaURL: 'https://example.com/image.png',
      mediaMimeType: 'image/png',
    });

    const payload = await buildGeminiPayload([messageWithMedia], true);

    expect(payload).toEqual([
      {
        role: 'user',
        parts: [
          {
            inline_data: {
              mime_type: 'image/png',
              data: 'base64payload',
            },
          },
          { text: 'Hello' },
        ],
      },
    ]);
  });
});

describe('attachMediaToMessage', () => {
  it('creates a data url for inline media', () => {
    const message = createMessage({ content: 'Hello' });

    const updated = attachMediaToMessage(message, 'base64payload', 'image/png');

    expect(updated.mediaURL).toBe('data:image/png;base64,base64payload');
    expect(updated.mediaMimeType).toBe('image/png');
  });
});
