export type GeminiRole = 'user' | 'model';

export type GeminiTextPart = {
  text: string;
};

export type GeminiThoughtPart = {
  thought: true;
  text: string;
};

export type GeminiInlineDataPart = {
  inline_data: {
    mime_type: string;
    data: string;
  };
};

export type GeminiFunctionCallPart = {
  functionCall: FunctionCall;
};

export type GeminiPart =
  | GeminiTextPart
  | GeminiThoughtPart
  | GeminiInlineDataPart
  | GeminiFunctionCallPart;

export interface GeminiMessage {
  role: GeminiRole;
  parts: GeminiPart[];
}

export interface GenerationConfig {
  temperature?: number;
  topP?: number;
  topK?: number;
  maxOutputTokens?: number;
  thinkingBudget?: number;
  responseModalities?: string[];
  imageConfig?: {
    aspectRatio?: string;
  };
}

export interface SafetySetting {
  category: string;
  threshold: string;
}

export interface FunctionDeclaration {
  name: string;
  description: string;
  parameters: {
    type: 'object';
    properties: Record<string, { type: string; description?: string }>;
    required?: string[];
  };
}

export interface Tool {
  googleSearch?: {};
  codeExecution?: {};
  urlContext?: {};
  googleSearchRetrieval?: {
    dynamicRetrievalConfig: {
      mode: 'MODE_DYNAMIC';
      dynamicThreshold: number;
    };
  };
  functionDeclarations?: FunctionDeclaration[];
}

export interface FunctionCall {
  name: string;
  args: Record<string, unknown>;
}

export interface GenerateContentRequest {
  contents: GeminiMessage[];
  generationConfig?: GenerationConfig;
  tools?: Tool[];
  safetySettings?: SafetySetting[];
}

export interface UsageMetadata {
  promptTokenCount: number;
  candidatesTokenCount: number;
  cachedContentTokenCount?: number;
}

export interface Candidate {
  content: {
    parts: GeminiPart[];
    role: string;
  };
  finishReason?: string;
}

export interface GeminiResponse {
  candidates?: Candidate[];
  usageMetadata?: UsageMetadata;
  error?: { message: string; code?: number };
}

export type StreamEvent =
  | { type: 'text'; content: string }
  | { type: 'thinking'; content: string }
  | { type: 'imageData'; data: string; mimeType: string }
  | { type: 'functionCall'; name: string; args: FunctionCall['args'] }
  | {
      type: 'usageMetadata';
      inputTokens: number;
      outputTokens: number;
      cachedTokens?: number;
    }
  | { type: 'error'; message: string }
  | { type: 'done' };
