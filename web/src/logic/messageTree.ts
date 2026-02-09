import { Message, MessageRole } from '../models/Message';

export interface BranchInfo {
  currentIndex: number;
  totalSiblings: number;
  hasPrevious: boolean;
  hasNext: boolean;
}

const getSelectionTime = (message: Message): number =>
  (message.selectedAt ?? message.createdAt).getTime();

const getNextRole = (role: MessageRole): MessageRole => (role === 'user' ? 'model' : 'user');

const sortBySelectionDesc = (a: Message, b: Message): number => {
  const selectionDiff = getSelectionTime(b) - getSelectionTime(a);
  if (selectionDiff !== 0) {
    return selectionDiff;
  }

  const createdDiff = b.createdAt.getTime() - a.createdAt.getTime();
  if (createdDiff !== 0) {
    return createdDiff;
  }

  return a.id.localeCompare(b.id);
};

export const getActiveBranch = (messages: Message[]): Message[] => {
  if (messages.length === 0) {
    return [];
  }

  const roots = messages.filter((message) => message.parentId === null);
  if (roots.length === 0) {
    return [];
  }

  const root = roots.reduce((latest, candidate) =>
    candidate.createdAt > latest.createdAt ? candidate : latest
  );

  const branch: Message[] = [root];
  let current = root;

  while (true) {
    const nextRole = getNextRole(current.role);
    const children = messages.filter(
      (message) => message.parentId === current.id && message.role === nextRole
    );

    if (children.length === 0) {
      break;
    }

    const selected = children.reduce((latest, candidate) =>
      getSelectionTime(candidate) > getSelectionTime(latest) ? candidate : latest
    );

    branch.push(selected);
    current = selected;
  }

  return branch;
};

export const getSiblings = (messages: Message[], messageId: string): Message[] => {
  const message = messages.find((item) => item.id === messageId);
  if (!message) {
    return [];
  }

  return messages
    .filter((item) => item.parentId === message.parentId && item.role === message.role)
    .sort(sortBySelectionDesc);
};

export const getBranchInfo = (messages: Message[], messageId: string): BranchInfo | null => {
  const siblings = getSiblings(messages, messageId);
  if (siblings.length === 0) {
    return null;
  }

  const currentIndex = siblings.findIndex((item) => item.id === messageId);
  if (currentIndex === -1) {
    return null;
  }

  return {
    currentIndex,
    totalSiblings: siblings.length,
    hasPrevious: currentIndex < siblings.length - 1,
    hasNext: currentIndex > 0,
  };
};

export const getMessagesUpTo = (messages: Message[], messageId: string): Message[] => {
  const activeBranch = getActiveBranch(messages);
  const index = activeBranch.findIndex((message) => message.id === messageId);

  if (index <= 0) {
    return [];
  }

  return activeBranch.slice(0, index);
};

export const getSubtreeIds = (messages: Message[], parentId: string): string[] => {
  const childrenByParent = new Map<string, string[]>();

  for (const message of messages) {
    if (message.parentId === null) {
      continue;
    }

    const list = childrenByParent.get(message.parentId) ?? [];
    list.push(message.id);
    childrenByParent.set(message.parentId, list);
  }

  const ids: string[] = [];
  const queue = [...(childrenByParent.get(parentId) ?? [])];

  while (queue.length > 0) {
    const nextId = queue.shift();
    if (!nextId) {
      continue;
    }

    ids.push(nextId);
    const children = childrenByParent.get(nextId);
    if (children) {
      queue.push(...children);
    }
  }

  return ids;
};

export const switchBranch = (
  messages: Message[],
  messageId: string,
  direction: 'previous' | 'next'
): { newSelectedId: string; newSelectedAt: Date } => {
  const siblings = getSiblings(messages, messageId);
  if (siblings.length === 0) {
    return { newSelectedId: messageId, newSelectedAt: new Date() };
  }

  const currentIndex = siblings.findIndex((item) => item.id === messageId);
  if (currentIndex === -1) {
    return { newSelectedId: messageId, newSelectedAt: new Date() };
  }

  const targetIndex = direction === 'previous' ? currentIndex + 1 : currentIndex - 1;
  const target = siblings[targetIndex] ?? siblings[currentIndex];

  return { newSelectedId: target.id, newSelectedAt: new Date() };
};
