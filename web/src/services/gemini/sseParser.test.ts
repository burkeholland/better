import { describe, expect, it } from 'vitest';
import { parseSSEStream } from './sseParser';
import type { StreamEvent } from './types';

const collectEvents = async (iterator: AsyncGenerator<StreamEvent>): Promise<StreamEvent[]> => {
  const events: StreamEvent[] = [];
  for await (const event of iterator) {
    events.push(event);
  }
  return events;
};

const createResponse = (chunks: string[]): Response => {
  const encoder = new TextEncoder();
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      for (const chunk of chunks) {
        controller.enqueue(encoder.encode(chunk));
      }
      controller.close();
    },
  });

  return new Response(stream);
};

describe('parseSSEStream', () => {
  it('parses regular text chunks', async () => {
    const response = createResponse([
      'data: {"candidates":[{"content":{"parts":[{"text":"Hello"}]}}]}\n\n',
      'data: [DONE]\n\n',
    ]);

    const events = await collectEvents(parseSSEStream(response));

    expect(events).toEqual([
      { type: 'text', content: 'Hello' },
      { type: 'done' },
    ]);
  });

  it('parses thinking content', async () => {
    const response = createResponse([
      'data: {"candidates":[{"content":{"parts":[{"thought":true,"text":"Thinking"}]}}]}\n\n',
      'data: [DONE]\n\n',
    ]);

    const events = await collectEvents(parseSSEStream(response));

    expect(events).toEqual([
      { type: 'thinking', content: 'Thinking' },
      { type: 'done' },
    ]);
  });

  it('parses usage metadata', async () => {
    const response = createResponse([
      'data: {"usageMetadata":{"promptTokenCount":1,"candidatesTokenCount":2,"cachedContentTokenCount":3}}\n\n',
      'data: [DONE]\n\n',
    ]);

    const events = await collectEvents(parseSSEStream(response));

    expect(events).toEqual([
      { type: 'usageMetadata', inputTokens: 1, outputTokens: 2, cachedTokens: 3 },
      { type: 'done' },
    ]);
  });

  it('parses function call events', async () => {
    const response = createResponse([
      'data: {"candidates":[{"content":{"parts":[{"functionCall":{"name":"generate_image","args":{"prompt":"cat"}}}]}}]}\n\n',
      'data: [DONE]\n\n',
    ]);

    const events = await collectEvents(parseSSEStream(response));

    expect(events).toEqual([
      { type: 'functionCall', name: 'generate_image', args: { prompt: 'cat' } },
      { type: 'done' },
    ]);
  });

  it('handles [DONE] terminator', async () => {
    const response = createResponse(['data: [DONE]\n\n']);

    const events = await collectEvents(parseSSEStream(response));

    expect(events).toEqual([{ type: 'done' }]);
  });

  it('buffers partial lines across chunks', async () => {
    const response = createResponse([
      'data: {"candidates":[{"content":{"parts":[{"text":"Hel',
      'lo"}]}}]}\n\n',
      'data: [DONE]\n\n',
    ]);

    const events = await collectEvents(parseSSEStream(response));

    expect(events).toEqual([
      { type: 'text', content: 'Hello' },
      { type: 'done' },
    ]);
  });

  it('handles malformed JSON gracefully', async () => {
    const response = createResponse([
      'data: {invalid json}\n\n',
      'data: [DONE]\n\n',
    ]);

    const events = await collectEvents(parseSSEStream(response));

    expect(events).toEqual([
      { type: 'error', message: 'Received malformed stream data from Gemini.' },
      { type: 'done' },
    ]);
  });
});
