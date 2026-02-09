import type { FunctionCall, GeminiMessage, GeminiResponse } from './types';

const BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/';
const IMAGE_MODELS = ['gemini-2.5-flash-image', 'gemini-3-pro-image-preview'];

export interface ToolResult {
  type: 'image' | 'video';
  data?: string;
  mimeType?: string;
  url?: string;
  error?: string;
  text?: string;
}

const buildURL = (model: string, apiKey: string): string => {
  const url = new URL(`models/${model}:generateContent`, BASE_URL);
  url.searchParams.set('key', apiKey);
  return url.toString();
};

const parseResponseError = async (response: Response): Promise<string> => {
  try {
    const data = (await response.json()) as { error?: { message?: string } };
    const message = data.error?.message?.trim();
    if (message) {
      return message;
    }
  } catch (error) {
    return `Gemini API request failed (${response.status}).`;
  }

  return `Gemini API request failed (${response.status}).`;
};

const extractResponseContent = (
  payload: GeminiResponse
): { data?: string; mimeType?: string; text?: string } | null => {
  const parts = payload.candidates?.[0]?.content?.parts ?? [];
  let imageData: string | undefined;
  let imageMimeType: string | undefined;
  let text = '';

  for (const part of parts) {
    if ('inline_data' in part) {
      imageData = part.inline_data?.data;
      imageMimeType = part.inline_data?.mime_type ?? 'image/png';
    }
    if ('text' in part && !('thought' in part)) {
      text += part.text;
    }
  }

  if (imageData || text) {
    return { data: imageData, mimeType: imageMimeType, text: text || undefined };
  }

  return null;
};

export const handleGenerateImage = async (
  prompt: string,
  apiKey: string,
  history?: GeminiMessage[]
): Promise<ToolResult> => {
  if (!prompt.trim()) {
    return { type: 'image', error: 'Image generation requires a prompt.' };
  }

  // Use full conversation history for multi-turn image iteration,
  // or a simple single-turn prompt for new image generation.
  const contents: GeminiMessage[] =
    history && history.length > 0
      ? history
      : [{ role: 'user', parts: [{ text: prompt }] }];

  let lastError: string | null = null;
  for (const model of IMAGE_MODELS) {
    const url = buildURL(model, apiKey);
    const body = {
      contents,
      generationConfig: { responseModalities: ['TEXT', 'IMAGE'] },
    };

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });

      if (!response.ok) {
        lastError = await parseResponseError(response);
        continue;
      }

      const payload = (await response.json()) as GeminiResponse;
      const content = extractResponseContent(payload);
      if (content) {
        return {
          type: 'image',
          data: content.data,
          mimeType: content.mimeType,
          text: content.text,
        };
      }

      lastError = 'No image data returned from Gemini.';
    } catch (error) {
      lastError = error instanceof Error ? error.message : 'Unable to generate image.';
    }
  }

  return { type: 'image', error: lastError ?? 'Unable to generate image.' };
};

export const handleGenerateVideo = async (prompt: string, apiKey: string): Promise<ToolResult> => {
  if (!prompt.trim()) {
    return { type: 'video', error: 'Video generation requires a prompt.' };
  }

  void apiKey;
  return { type: 'video', error: 'Video generation not yet implemented.' };
};

export const handleFunctionCall = async (
  functionCall: FunctionCall,
  apiKey: string
): Promise<ToolResult> => {
  if (functionCall.name === 'generate_image') {
    const prompt = typeof functionCall.args.prompt === 'string' ? functionCall.args.prompt : '';
    return handleGenerateImage(prompt, apiKey);
  }

  if (functionCall.name === 'generate_video') {
    const prompt = typeof functionCall.args.prompt === 'string' ? functionCall.args.prompt : '';
    return handleGenerateVideo(prompt, apiKey);
  }

  return {
    type: 'image',
    error: `Unsupported function call: ${functionCall.name}`,
  };
};
