import type { FunctionCall, GeminiResponse } from './types';

const BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/';
const IMAGE_MODELS = ['gemini-2.5-flash-image', 'gemini-3-pro-image-preview'];

export interface ToolResult {
  type: 'image' | 'video';
  data?: string;
  mimeType?: string;
  url?: string;
  error?: string;
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

const extractInlineImage = (payload: GeminiResponse): { data: string; mimeType: string } | null => {
  const parts = payload.candidates?.[0]?.content?.parts ?? [];

  for (const part of parts) {
    if ('inline_data' in part) {
      const data = part.inline_data?.data;
      const mimeType = part.inline_data?.mime_type ?? 'image/png';
      if (data) {
        return { data, mimeType };
      }
    }
  }

  return null;
};

export const handleGenerateImage = async (prompt: string, apiKey: string): Promise<ToolResult> => {
  if (!prompt.trim()) {
    return { type: 'image', error: 'Image generation requires a prompt.' };
  }

  let lastError: string | null = null;
  for (const model of IMAGE_MODELS) {
    const url = buildURL(model, apiKey);
    const body = {
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: { responseModalities: ['IMAGE'] },
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
      const inlineImage = extractInlineImage(payload);
      if (inlineImage) {
        return { type: 'image', data: inlineImage.data, mimeType: inlineImage.mimeType };
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
