export interface Conversation {
  id: string;
  title: string;
  createdAt: Date;
  updatedAt: Date;
  isPinned: boolean;
  isArchived: boolean;
  systemInstruction: string | null;
  modelName: string;
  temperature: number;
  topP: number;
  topK: number;
  maxOutputTokens: number;
  thinkingBudget: number | null;
  googleSearchEnabled: boolean;
  codeExecutionEnabled: boolean;
  urlContextEnabled: boolean;
  imageGenerationEnabled: boolean;
  videoGenerationEnabled: boolean;
}

export type NewConversationInput = Omit<Conversation, 'id' | 'createdAt' | 'updatedAt'>;

const DEFAULT_TITLE = 'New Chat';
const DEFAULT_MODEL_NAME = 'gemini-flash-latest';

const generateId = (): string => {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }

  return `conv_${Date.now()}_${Math.random().toString(16).slice(2)}`;
};

export const createConversation = (title: string = DEFAULT_TITLE): Conversation => ({
  id: generateId(),
  title,
  createdAt: new Date(),
  updatedAt: new Date(),
  isPinned: false,
  isArchived: false,
  systemInstruction: null,
  modelName: DEFAULT_MODEL_NAME,
  temperature: 1.0,
  topP: 0.95,
  topK: 40,
  maxOutputTokens: 8192,
  thinkingBudget: null,
  googleSearchEnabled: false,
  codeExecutionEnabled: false,
  urlContextEnabled: false,
  imageGenerationEnabled: false,
  videoGenerationEnabled: false,
});

const THINKING_MODEL_PATTERNS: RegExp[] = [/pro/i, /thinking/i];

export const isThinkingModel = (modelName: string): boolean =>
  THINKING_MODEL_PATTERNS.some((pattern) => pattern.test(modelName));

export const getDefaultConversationSettings = (): Partial<Conversation> => {
  return {
    modelName: DEFAULT_MODEL_NAME,
    temperature: 1.0,
    topP: 0.95,
    topK: 40,
    maxOutputTokens: 8192,
    thinkingBudget: null,
    googleSearchEnabled: false,
    codeExecutionEnabled: false,
    urlContextEnabled: false,
    imageGenerationEnabled: false,
    videoGenerationEnabled: false,
    systemInstruction: null
  };
};
