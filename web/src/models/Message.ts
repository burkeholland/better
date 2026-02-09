export type MessageRole = 'user' | 'model';

export interface Message {
  id: string;
  role: MessageRole;
  content: string;
  createdAt: Date;
  selectedAt: Date | null;
  parentId: string | null;
  mediaURL: string | null;
  mediaMimeType: string | null;
  inputTokens: number | null;
  outputTokens: number | null;
  cachedTokens: number | null;
  thinkingContent: string | null;
}

export type CreateMessageInput = Omit<Message, 'id' | 'createdAt'>;

export type MessageWithMedia = Message & {
  mediaURL: string;
  mediaMimeType: string;
};

export interface TokenCounts {
  inputTokens: number;
  outputTokens: number;
  cachedTokens: number;
}

const generateId = (): string => {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }

  return `msg_${Date.now()}_${Math.random().toString(16).slice(2)}`;
};

const createMessage = (role: MessageRole, content: string, parentId?: string | null): Message => ({
  id: generateId(),
  role,
  content,
  createdAt: new Date(),
  selectedAt: null,
  parentId: parentId ?? null,
  mediaURL: null,
  mediaMimeType: null,
  inputTokens: null,
  outputTokens: null,
  cachedTokens: null,
  thinkingContent: null,
});

export const createUserMessage = (content: string, parentId?: string | null): Message =>
  createMessage('user', content, parentId);

export const createModelMessage = (content: string, parentId?: string | null): Message =>
  createMessage('model', content, parentId);

export const hasMedia = (message: Message): boolean => Boolean(message.mediaURL);

export const hasTokecounts = (message: Message): boolean =>
  message.inputTokens != null || message.outputTokens != null || message.cachedTokens != null;
