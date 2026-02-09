import type {
  FunctionDeclaration,
  GenerateContentRequest,
  GeminiResponse,
  StreamEvent,
  Tool,
} from './types';
import { parseSSEStream } from './sseParser';

const BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/';
const FALLBACK_MODELS = ['gemini-2.0-flash', 'gemini-1.5-pro'];

export interface ToolFlags {
  googleSearch?: boolean;
  codeExecution?: boolean;
  urlContext?: boolean;
  imageGeneration?: boolean;
  videoGeneration?: boolean;
}

const IMAGE_FUNCTION_DECLARATION: FunctionDeclaration = {
  name: 'generate_image',
  description: 'Generate an image based on a text prompt',
  parameters: {
    type: 'object',
    properties: {
      prompt: { type: 'string', description: 'The image generation prompt' },
    },
    required: ['prompt'],
  },
};

const VIDEO_FUNCTION_DECLARATION: FunctionDeclaration = {
  name: 'generate_video',
  description: 'Generate a video based on a text prompt',
  parameters: {
    type: 'object',
    properties: {
      prompt: { type: 'string', description: 'The video generation prompt' },
    },
    required: ['prompt'],
  },
};

export class GeminiAPIClient {
  private apiKey: string;

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  // Usage example:
  // const client = new GeminiAPIClient(apiKey);
  // const stream = client.stream(model, request, {
  //   googleSearch: conversation.googleSearchEnabled,
  //   codeExecution: conversation.codeExecutionEnabled,
  //   urlContext: conversation.urlContextEnabled,
  // });
  //
  // for await (const event of stream) {
  //   if (event.type === 'functionCall') {
  //     const result = await handleFunctionCall(event, apiKey);
  //     // Attach result to message
  //   }
  // }
  async generate(
    model: string,
    request: GenerateContentRequest,
    toolFlags: ToolFlags = {}
  ): Promise<GeminiResponse> {
    const url = this.buildURL(`models/${model}:generateContent`);
    const tools = this.buildTools(
      Boolean(toolFlags.googleSearch),
      Boolean(toolFlags.codeExecution),
      Boolean(toolFlags.urlContext),
      Boolean(toolFlags.imageGeneration),
      Boolean(toolFlags.videoGeneration)
    );
    const payload = { ...request, tools };

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        throw await this.parseResponseError(response);
      }

      return (await response.json()) as GeminiResponse;
    } catch (error) {
      throw this.handleError(error);
    }
  }

  async *stream(
    model: string,
    request: GenerateContentRequest,
    toolFlags: ToolFlags = {}
  ): AsyncGenerator<StreamEvent> {
    const url = this.buildURL(`models/${model}:streamGenerateContent`, { alt: 'sse' });
    const tools = this.buildTools(
      Boolean(toolFlags.googleSearch),
      Boolean(toolFlags.codeExecution),
      Boolean(toolFlags.urlContext),
      Boolean(toolFlags.imageGeneration),
      Boolean(toolFlags.videoGeneration)
    );
    const payload = { ...request, tools };

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        const error = await this.parseResponseError(response);
        yield { type: 'error', message: error.message };
        return;
      }

      for await (const event of parseSSEStream(response)) {
        yield event;
      }
    } catch (error) {
      const handled = this.handleError(error);
      yield { type: 'error', message: handled.message };
    }
  }

  async listModels(): Promise<string[]> {
    const url = this.buildURL('models');

    try {
      const response = await fetch(url, { method: 'GET' });

      if (!response.ok) {
        throw await this.parseResponseError(response);
      }

      const data = (await response.json()) as { models?: Array<{ name?: string }> };
      const models = (data.models ?? [])
        .map((model) => model.name)
        .filter((name): name is string => Boolean(name));

      return models.length > 0 ? models : [...FALLBACK_MODELS];
    } catch (error) {
      console.warn('Failed to list Gemini models. Falling back to defaults.', error);
      return [...FALLBACK_MODELS];
    }
  }

  buildURL(endpoint: string, params?: Record<string, string>): string {
    const url = new URL(endpoint, BASE_URL);
    url.searchParams.set('key', this.apiKey);

    if (params) {
      for (const [key, value] of Object.entries(params)) {
        url.searchParams.set(key, value);
      }
    }

    return url.toString();
  }

  handleError(error: unknown): Error {
    if (error instanceof Error) {
      return error;
    }

    return new Error('Unable to reach Gemini right now.');
  }

  private buildTools(
    googleSearchEnabled: boolean,
    codeExecutionEnabled: boolean,
    urlContextEnabled: boolean,
    imageGenerationEnabled: boolean,
    videoGenerationEnabled: boolean
  ): Tool[] {
    const toolList: Tool[] = [];

    if (googleSearchEnabled) {
      toolList.push({ googleSearch: {} });
    }

    if (codeExecutionEnabled) {
      toolList.push({ codeExecution: {} });
    }

    if (urlContextEnabled) {
      toolList.push({ urlContext: {} });
    }

    if (imageGenerationEnabled) {
      toolList.push({ functionDeclarations: [IMAGE_FUNCTION_DECLARATION] });
    }

    if (videoGenerationEnabled) {
      toolList.push({ functionDeclarations: [VIDEO_FUNCTION_DECLARATION] });
    }

    return toolList;
  }

  private async parseResponseError(response: Response): Promise<Error> {
    try {
      const data = (await response.json()) as { error?: { message?: string } };
      const message = data.error?.message?.trim();
      if (message) {
        return new Error(message);
      }
    } catch (error) {
      return new Error(`Gemini API request failed (${response.status}).`);
    }

    return new Error(`Gemini API request failed (${response.status}).`);
  }
}
