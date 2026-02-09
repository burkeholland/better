import { afterEach, describe, expect, it, vi } from 'vitest';
import { handleFunctionCall, handleGenerateImage } from './toolHandlers';

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe('toolHandlers', () => {
  it('returns inline image data from Gemini', async () => {
    const responseBody = {
      candidates: [
        {
          content: {
            parts: [
              {
                inline_data: {
                  mime_type: 'image/png',
                  data: 'base64payload',
                },
              },
            ],
          },
        },
      ],
    };

    const fetchMock = vi
      .fn()
      .mockResolvedValue(
        new Response(JSON.stringify(responseBody), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        })
      );
    vi.stubGlobal('fetch', fetchMock);

    const result = await handleGenerateImage('A cat in a hat', 'test-key');

    expect(result).toEqual({
      type: 'image',
      data: 'base64payload',
      mimeType: 'image/png',
    });
  });

  it('routes generate_video function calls to the video handler', async () => {
    const result = await handleFunctionCall(
      { name: 'generate_video', args: { prompt: 'A short clip' } },
      'test-key'
    );

    expect(result).toEqual({
      type: 'video',
      error: 'Video generation not yet implemented.',
    });
  });
});
