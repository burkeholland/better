import { afterEach, describe, expect, it, vi } from 'vitest';
import { GeminiAPIClient } from './client';
import type { GenerateContentRequest } from './types';

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe('GeminiAPIClient tools', () => {
  it('includes enabled tools and function declarations in generate requests', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(
        new Response(JSON.stringify({ candidates: [] }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        })
      );
    vi.stubGlobal('fetch', fetchMock);

    const client = new GeminiAPIClient('test-key');
    const request: GenerateContentRequest = {
      contents: [{ role: 'user', parts: [{ text: 'Hello' }] }],
    };

    await client.generate('gemini-2.0-flash-exp', request, {
      googleSearch: true,
      codeExecution: true,
      urlContext: true,
    });

    const body = JSON.parse(fetchMock.mock.calls[0]?.[1]?.body as string) as {
      tools?: unknown[];
    };

    expect(body.tools).toEqual([
      { googleSearch: {} },
      { codeExecution: {} },
      { urlContext: {} },
      {
        functionDeclarations: [
          {
            name: 'generate_image',
            description: 'Generate an image based on a text prompt',
            parameters: {
              type: 'object',
              properties: {
                prompt: { type: 'string', description: 'The image generation prompt' },
              },
              required: ['prompt'],
            },
          },
        ],
      },
      {
        functionDeclarations: [
          {
            name: 'generate_video',
            description: 'Generate a video based on a text prompt',
            parameters: {
              type: 'object',
              properties: {
                prompt: { type: 'string', description: 'The video generation prompt' },
              },
              required: ['prompt'],
            },
          },
        ],
      },
    ]);
  });

  it('always includes function declarations when no tools are enabled', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(
        new Response(JSON.stringify({ candidates: [] }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        })
      );
    vi.stubGlobal('fetch', fetchMock);

    const client = new GeminiAPIClient('test-key');
    const request: GenerateContentRequest = {
      contents: [{ role: 'user', parts: [{ text: 'Hello' }] }],
    };

    await client.generate('gemini-2.0-flash-exp', request, {});

    const body = JSON.parse(fetchMock.mock.calls[0]?.[1]?.body as string) as {
      tools?: unknown[];
    };

    expect(body.tools).toEqual([
      {
        functionDeclarations: [
          {
            name: 'generate_image',
            description: 'Generate an image based on a text prompt',
            parameters: {
              type: 'object',
              properties: {
                prompt: { type: 'string', description: 'The image generation prompt' },
              },
              required: ['prompt'],
            },
          },
        ],
      },
      {
        functionDeclarations: [
          {
            name: 'generate_video',
            description: 'Generate a video based on a text prompt',
            parameters: {
              type: 'object',
              properties: {
                prompt: { type: 'string', description: 'The video generation prompt' },
              },
              required: ['prompt'],
            },
          },
        ],
      },
    ]);
  });
});
