import type { GeminiResponse, StreamEvent } from './types';

const extractEventsFromResponse = (payload: GeminiResponse): StreamEvent[] => {
  if (payload.error?.message) {
    return [{ type: 'error', message: payload.error.message }];
  }

  const events: StreamEvent[] = [];

  if (payload.usageMetadata) {
    events.push({
      type: 'usageMetadata',
      inputTokens: payload.usageMetadata.promptTokenCount,
      outputTokens: payload.usageMetadata.candidatesTokenCount,
      cachedTokens: payload.usageMetadata.cachedContentTokenCount,
    });
  }

  const parts = payload.candidates?.[0]?.content?.parts ?? [];

  for (const part of parts) {
    if ('inline_data' in part) {
      const data = part.inline_data?.data;
      const mimeType = part.inline_data?.mime_type;
      if (data && mimeType) {
        events.push({ type: 'imageData', data, mimeType });
      }
      continue;
    }

    if ('functionCall' in part) {
      const name = part.functionCall?.name;
      const args = part.functionCall?.args ?? {};
      if (name) {
        events.push({ type: 'functionCall', name, args });
      }
      continue;
    }

    if ('text' in part && typeof part.text === 'string') {
      if ('thought' in part && part.thought === true) {
        events.push({ type: 'thinking', content: part.text });
      } else {
        events.push({ type: 'text', content: part.text });
      }
    }
  }

  return events;
};

const parsePayload = (payload: string): StreamEvent[] => {
  if (payload === '[DONE]') {
    return [{ type: 'done' }];
  }

  try {
    const parsed = JSON.parse(payload) as GeminiResponse;
    return extractEventsFromResponse(parsed);
  } catch (error) {
    return [
      {
        type: 'error',
        message: 'Received malformed stream data from Gemini.',
      },
    ];
  }
};

export const parseSSEStream = async function* (
  response: Response
): AsyncGenerator<StreamEvent> {
  if (!response.body) {
    yield { type: 'error', message: 'Gemini stream had no response body.' };
    return;
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder('utf-8');
  let buffer = '';

  while (true) {
    const { value, done } = await reader.read();
    buffer += decoder.decode(value ?? new Uint8Array(), { stream: !done });

    const lines = buffer.split(/\r?\n/);
    buffer = lines.pop() ?? '';

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed.startsWith('data:')) {
        continue;
      }

      const payload = trimmed.slice(5).trim();
      const events = parsePayload(payload);

      for (const event of events) {
        yield event;
        if (event.type === 'done') {
          return;
        }
      }
    }

    if (done) {
      const leftover = buffer.trim();
      if (leftover.startsWith('data:')) {
        const payload = leftover.slice(5).trim();
        const events = parsePayload(payload);
        for (const event of events) {
          yield event;
          if (event.type === 'done') {
            return;
          }
        }
      }
      return;
    }
  }
};
