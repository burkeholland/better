import {
  collection,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  orderBy,
  where,
  query,
  setDoc,
  updateDoc,
  deleteDoc,
  writeBatch,
  Timestamp,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
  SnapshotOptions,
  Unsubscribe,
  getFirestore,
} from 'firebase/firestore';

import { Conversation } from '../models/Conversation';
import { Message } from '../models/Message';

type ConversationFirestore = Omit<Conversation, 'id' | 'createdAt' | 'updatedAt'> & {
  createdAt: Timestamp;
  updatedAt: Timestamp;
};

type MessageFirestore = Omit<Message, 'id' | 'createdAt' | 'selectedAt'> & {
  createdAt: Timestamp;
  selectedAt: Timestamp | null;
};

const db = getFirestore();

const serializeConversation = (conversation: Conversation): ConversationFirestore => ({
  title: conversation.title,
  createdAt: Timestamp.fromDate(conversation.createdAt),
  updatedAt: Timestamp.fromDate(conversation.updatedAt),
  isPinned: conversation.isPinned,
  isArchived: conversation.isArchived,
  systemInstruction: conversation.systemInstruction,
  modelName: conversation.modelName,
  temperature: conversation.temperature,
  topP: conversation.topP,
  topK: conversation.topK,
  maxOutputTokens: conversation.maxOutputTokens,
  thinkingBudget: conversation.thinkingBudget,
  googleSearchEnabled: conversation.googleSearchEnabled,
  codeExecutionEnabled: conversation.codeExecutionEnabled,
  urlContextEnabled: conversation.urlContextEnabled,
  imageGenerationEnabled: conversation.imageGenerationEnabled,
  videoGenerationEnabled: conversation.videoGenerationEnabled,
});

const serializeConversationUpdates = (
  updates: Partial<Conversation>
): Partial<ConversationFirestore> => {
  const mapped: Partial<ConversationFirestore> = {};

  if (updates.title !== undefined) mapped.title = updates.title;
  if (updates.createdAt !== undefined) {
    mapped.createdAt = Timestamp.fromDate(updates.createdAt);
  }
  if (updates.updatedAt !== undefined) {
    mapped.updatedAt = Timestamp.fromDate(updates.updatedAt);
  }
  if (updates.isPinned !== undefined) mapped.isPinned = updates.isPinned;
  if (updates.isArchived !== undefined) mapped.isArchived = updates.isArchived;
  if (updates.systemInstruction !== undefined) mapped.systemInstruction = updates.systemInstruction;
  if (updates.modelName !== undefined) mapped.modelName = updates.modelName;
  if (updates.temperature !== undefined) mapped.temperature = updates.temperature;
  if (updates.topP !== undefined) mapped.topP = updates.topP;
  if (updates.topK !== undefined) mapped.topK = updates.topK;
  if (updates.maxOutputTokens !== undefined) mapped.maxOutputTokens = updates.maxOutputTokens;
  if (updates.thinkingBudget !== undefined) mapped.thinkingBudget = updates.thinkingBudget;
  if (updates.googleSearchEnabled !== undefined) {
    mapped.googleSearchEnabled = updates.googleSearchEnabled;
  }
  if (updates.codeExecutionEnabled !== undefined) {
    mapped.codeExecutionEnabled = updates.codeExecutionEnabled;
  }
  if (updates.urlContextEnabled !== undefined) {
    mapped.urlContextEnabled = updates.urlContextEnabled;
  }
  if (updates.imageGenerationEnabled !== undefined) {
    mapped.imageGenerationEnabled = updates.imageGenerationEnabled;
  }
  if (updates.videoGenerationEnabled !== undefined) {
    mapped.videoGenerationEnabled = updates.videoGenerationEnabled;
  }

  return mapped;
};

const deserializeConversation = (
  snapshot: QueryDocumentSnapshot<ConversationFirestore>,
  options: SnapshotOptions
): Conversation => {
  const data = snapshot.data(options);

  return {
    id: snapshot.id,
    title: data.title,
    createdAt: data.createdAt?.toDate() ?? new Date(),
    updatedAt: data.updatedAt?.toDate() ?? new Date(),
    isPinned: data.isPinned,
    isArchived: data.isArchived,
    systemInstruction: data.systemInstruction ?? null,
    modelName: data.modelName,
    temperature: data.temperature,
    topP: data.topP,
    topK: data.topK,
    maxOutputTokens: data.maxOutputTokens,
    thinkingBudget: data.thinkingBudget ?? null,
    googleSearchEnabled: data.googleSearchEnabled ?? false,
    codeExecutionEnabled: data.codeExecutionEnabled ?? false,
    urlContextEnabled: data.urlContextEnabled ?? false,
    imageGenerationEnabled: data.imageGenerationEnabled ?? false,
    videoGenerationEnabled: data.videoGenerationEnabled ?? false,
  };
};

const conversationConverter: FirestoreDataConverter<Conversation, ConversationFirestore> = {
  toFirestore: (conversation: Conversation): ConversationFirestore =>
    serializeConversation(conversation),
  fromFirestore: (snapshot: QueryDocumentSnapshot<ConversationFirestore>, options: SnapshotOptions) =>
    deserializeConversation(snapshot, options),
};

const serializeMessage = (message: Message): MessageFirestore => ({
  role: message.role,
  content: message.content,
  createdAt: Timestamp.fromDate(message.createdAt),
  selectedAt: message.selectedAt ? Timestamp.fromDate(message.selectedAt) : null,
  parentId: message.parentId,
  mediaURL: message.mediaURL,
  mediaMimeType: message.mediaMimeType,
  inputTokens: message.inputTokens,
  outputTokens: message.outputTokens,
  cachedTokens: message.cachedTokens,
  thinkingContent: message.thinkingContent,
});

const serializeMessageUpdates = (updates: Partial<Message>): Partial<MessageFirestore> => {
  const mapped: Partial<MessageFirestore> = {};

  if (updates.role !== undefined) mapped.role = updates.role;
  if (updates.content !== undefined) mapped.content = updates.content;
  if (updates.createdAt !== undefined) mapped.createdAt = Timestamp.fromDate(updates.createdAt);
  if (updates.selectedAt !== undefined) {
    mapped.selectedAt = updates.selectedAt ? Timestamp.fromDate(updates.selectedAt) : null;
  }
  if (updates.parentId !== undefined) mapped.parentId = updates.parentId;
  if (updates.mediaURL !== undefined) mapped.mediaURL = updates.mediaURL;
  if (updates.mediaMimeType !== undefined) mapped.mediaMimeType = updates.mediaMimeType;
  if (updates.inputTokens !== undefined) mapped.inputTokens = updates.inputTokens;
  if (updates.outputTokens !== undefined) mapped.outputTokens = updates.outputTokens;
  if (updates.cachedTokens !== undefined) mapped.cachedTokens = updates.cachedTokens;
  if (updates.thinkingContent !== undefined) mapped.thinkingContent = updates.thinkingContent;

  return mapped;
};

const deserializeMessage = (
  snapshot: QueryDocumentSnapshot<MessageFirestore>,
  options: SnapshotOptions
): Message => {
  const data = snapshot.data(options);

  return {
    id: snapshot.id,
    role: data.role,
    content: data.content,
    createdAt: data.createdAt?.toDate() ?? new Date(),
    selectedAt: data.selectedAt?.toDate() ?? null,
    parentId: data.parentId ?? null,
    mediaURL: data.mediaURL ?? null,
    mediaMimeType: data.mediaMimeType ?? null,
    inputTokens: data.inputTokens ?? null,
    outputTokens: data.outputTokens ?? null,
    cachedTokens: data.cachedTokens ?? null,
    thinkingContent: data.thinkingContent ?? null,
  };
};

const messageConverter: FirestoreDataConverter<Message, MessageFirestore> = {
  toFirestore: (message: Message): MessageFirestore => serializeMessage(message),
  fromFirestore: (snapshot: QueryDocumentSnapshot<MessageFirestore>, options: SnapshotOptions) =>
    deserializeMessage(snapshot, options),
};

export const conversationsPath = (userId: string) =>
  collection(db, 'users', userId, 'conversations').withConverter(conversationConverter);

export const conversationPath = (userId: string, conversationId: string) =>
  doc(db, 'users', userId, 'conversations', conversationId).withConverter(conversationConverter);

export const messagesPath = (userId: string, conversationId: string) =>
  collection(db, 'users', userId, 'conversations', conversationId, 'messages').withConverter(
    messageConverter
  );

export const messagePath = (userId: string, conversationId: string, messageId: string) =>
  doc(db, 'users', userId, 'conversations', conversationId, 'messages', messageId).withConverter(
    messageConverter
  );

const deleteMessagesInCollection = async (userId: string, conversationId: string): Promise<void> => {
  const messagesRef = messagesPath(userId, conversationId);
  const snapshot = await getDocs(messagesRef);

  if (snapshot.empty) {
    return;
  }

  let batch = writeBatch(db);
  let pending = 0;

  for (const messageDoc of snapshot.docs) {
    batch.delete(messageDoc.ref);
    pending += 1;

    if (pending >= 500) {
      await batch.commit();
      batch = writeBatch(db);
      pending = 0;
    }
  }

  if (pending > 0) {
    await batch.commit();
  }
};

export const createConversation = async (
  userId: string,
  conversation: Conversation
): Promise<void> => {
  try {
    await setDoc(conversationPath(userId, conversation.id), conversation);
  } catch (error) {
    throw new Error(`Failed to create conversation: ${String(error)}`);
  }
};

export const updateConversation = async (
  userId: string,
  conversationId: string,
  updates: Partial<Conversation>
): Promise<void> => {
  try {
    const mappedUpdates = serializeConversationUpdates(updates);
    await updateDoc(conversationPath(userId, conversationId), mappedUpdates);
  } catch (error) {
    throw new Error(`Failed to update conversation: ${String(error)}`);
  }
};

export const deleteConversation = async (userId: string, conversationId: string): Promise<void> => {
  try {
    await deleteMessagesInCollection(userId, conversationId);
    await deleteDoc(conversationPath(userId, conversationId));
    // TODO: delete any related media files in Storage when media deletion is available.
  } catch (error) {
    throw new Error(`Failed to delete conversation: ${String(error)}`);
  }
};

export const deleteAllMessages = async (
  userId: string,
  conversationId: string
): Promise<void> => deleteMessagesInCollection(userId, conversationId);

export const listenToConversations = (
  userId: string,
  callback: (conversations: Conversation[]) => void
): Unsubscribe => {
  const conversationsRef = conversationsPath(userId);
  const ordered = query(conversationsRef, orderBy('updatedAt', 'desc'));

  return onSnapshot(
    ordered,
    (snapshot) => {
      callback(snapshot.docs.map((docSnapshot) => docSnapshot.data()));
    },
    (error) => {
      console.error('Failed to listen to conversations', error);
    }
  );
};

export const listenToArchivedConversations = (
  userId: string,
  callback: (conversations: Conversation[]) => void
): Unsubscribe => {
  const conversationsRef = conversationsPath(userId);
  const archived = query(
    conversationsRef,
    where('isArchived', '==', true),
    orderBy('updatedAt', 'desc')
  );

  return onSnapshot(
    archived,
    (snapshot) => {
      callback(snapshot.docs.map((docSnapshot) => docSnapshot.data()));
    },
    (error) => {
      console.error('Failed to listen to archived conversations', error);
    }
  );
};

export const touchConversation = async (
  userId: string,
  conversationId: string
): Promise<void> =>
  updateConversation(userId, conversationId, { updatedAt: new Date() });

export const getConversation = async (
  userId: string,
  conversationId: string
): Promise<Conversation | null> => {
  try {
    const snapshot = await getDoc(conversationPath(userId, conversationId));
    return snapshot.exists() ? snapshot.data() : null;
  } catch (error) {
    console.error('Failed to get conversation', error);
    return null;
  }
};

export const createMessage = async (
  userId: string,
  conversationId: string,
  message: Message
): Promise<void> => {
  try {
    await setDoc(messagePath(userId, conversationId, message.id), message);
  } catch (error) {
    throw new Error(`Failed to create message: ${String(error)}`);
  }
};

export const updateMessage = async (
  userId: string,
  conversationId: string,
  messageId: string,
  updates: Partial<Message>
): Promise<void> => {
  try {
    const mappedUpdates = serializeMessageUpdates(updates);
    await updateDoc(messagePath(userId, conversationId, messageId), mappedUpdates);
  } catch (error) {
    throw new Error(`Failed to update message: ${String(error)}`);
  }
};

export const deleteMessage = async (
  userId: string,
  conversationId: string,
  messageId: string
): Promise<void> => {
  try {
    await deleteDoc(messagePath(userId, conversationId, messageId));
  } catch (error) {
    throw new Error(`Failed to delete message: ${String(error)}`);
  }
};

export const deleteMessagesInSubtree = async (
  userId: string,
  conversationId: string,
  parentId: string
): Promise<void> => {
  try {
    const messagesRef = messagesPath(userId, conversationId);
    const snapshot = await getDocs(messagesRef);

    if (snapshot.empty) {
      return;
    }

    const childrenByParent = new Map<string | null, string[]>();

    for (const messageDoc of snapshot.docs) {
      const message = messageDoc.data();
      const key = message.parentId ?? null;
      const list = childrenByParent.get(key) ?? [];
      list.push(message.id);
      childrenByParent.set(key, list);
    }

    const idsToDelete: string[] = [];
    const queue = [...(childrenByParent.get(parentId) ?? [])];

    while (queue.length > 0) {
      const nextId = queue.shift();
      if (!nextId) {
        continue;
      }

      idsToDelete.push(nextId);
      const children = childrenByParent.get(nextId) ?? [];
      queue.push(...children);
    }

    if (idsToDelete.length === 0) {
      return;
    }

    let batch = writeBatch(db);
    let pending = 0;

    for (const id of idsToDelete) {
      batch.delete(messagePath(userId, conversationId, id));
      pending += 1;

      if (pending >= 500) {
        await batch.commit();
        batch = writeBatch(db);
        pending = 0;
      }
    }

    if (pending > 0) {
      await batch.commit();
    }
  } catch (error) {
    throw new Error(`Failed to delete message subtree: ${String(error)}`);
  }
};

export const listenToMessages = (
  userId: string,
  conversationId: string,
  callback: (messages: Message[]) => void
): Unsubscribe => {
  const messagesRef = messagesPath(userId, conversationId);
  const ordered = query(messagesRef, orderBy('createdAt', 'asc'));

  return onSnapshot(
    ordered,
    (snapshot) => {
      callback(snapshot.docs.map((docSnapshot) => docSnapshot.data()));
    },
    (error) => {
      console.error('Failed to listen to messages', error);
    }
  );
};

export const getMessage = async (
  userId: string,
  conversationId: string,
  messageId: string
): Promise<Message | null> => {
  try {
    const snapshot = await getDoc(messagePath(userId, conversationId, messageId));
    return snapshot.exists() ? snapshot.data() : null;
  } catch (error) {
    console.error('Failed to get message', error);
    return null;
  }
};
