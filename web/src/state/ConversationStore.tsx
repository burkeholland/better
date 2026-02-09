import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';

import type { Conversation } from '../models/Conversation';
import { createConversation as createConversationModel } from '../models/Conversation';
import {
  createConversation as createConversationFirestore,
  deleteConversation as deleteConversationFirestore,
  listenToConversations,
  updateConversation as updateConversationFirestore,
} from '../services/firestoreService';
import { useAuth } from './AuthContext';

type ConversationStoreState = {
  conversations: Conversation[];
  archivedConversations: Conversation[];
  loading: boolean;
  error: string | null;
  searchQuery: string;
  filteredConversations: Conversation[];
  pinnedConversations: Conversation[];
  unpinnedConversations: Conversation[];
};

type ConversationStoreActions = {
  setSearchQuery: (query: string) => void;
  createConversation: (title?: string) => Conversation;
  saveConversation: (conversation: Conversation) => Promise<void>;
  updateConversation: (id: string, updates: Partial<Conversation>) => Promise<void>;
  deleteConversation: (id: string) => Promise<void>;
  pinConversation: (id: string) => Promise<void>;
  unpinConversation: (id: string) => Promise<void>;
  archiveConversation: (id: string) => Promise<void>;
  unarchiveConversation: (id: string) => Promise<void>;
  refreshConversations: () => void;
};

type ConversationStoreValue = ConversationStoreState & ConversationStoreActions;

type ConversationStoreProviderProps = {
  children: ReactNode;
};

const ConversationStoreContext = createContext<ConversationStoreValue | null>(null);

const DEFAULT_DEBOUNCE_MS = 300;

const useDebouncedValue = <T,>(value: T, delay: number): T => {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timer = window.setTimeout(() => setDebouncedValue(value), delay);
    return () => window.clearTimeout(timer);
  }, [value, delay]);

  return debouncedValue;
};

const sortConversations = (items: Conversation[]): Conversation[] =>
  [...items].sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());

const mergeConversations = (local: Conversation[], remote: Conversation[]): Conversation[] => {
  const merged = new Map<string, Conversation>();

  for (const conversation of local) {
    merged.set(conversation.id, conversation);
  }

  for (const conversation of remote) {
    merged.set(conversation.id, conversation);
  }

  return Array.from(merged.values());
};

const shouldTouchConversation = (updates: Partial<Conversation>): boolean =>
  'title' in updates ||
  'systemInstruction' in updates ||
  'modelName' in updates ||
  'temperature' in updates ||
  'topP' in updates ||
  'topK' in updates ||
  'maxOutputTokens' in updates ||
  'thinkingBudget' in updates ||
  'googleSearchEnabled' in updates ||
  'codeExecutionEnabled' in updates ||
  'urlContextEnabled' in updates ||
  'imageGenerationEnabled' in updates ||
  'videoGenerationEnabled' in updates ||
  'isPinned' in updates ||
  'isArchived' in updates;

const upsertConversation = (items: Conversation[], updated: Conversation): Conversation[] => {
  const remaining = items.filter((item) => item.id !== updated.id);
  return sortConversations([...remaining, updated]);
};

const updateConversationInList = (
  items: Conversation[],
  id: string,
  updates: Partial<Conversation>
): Conversation[] => {
  let changed = false;

  const next = items.map((conversation) => {
    if (conversation.id !== id) {
      return conversation;
    }

    changed = true;
    return { ...conversation, ...updates };
  });

  return changed ? sortConversations(next) : items;
};

export const ConversationStoreProvider = ({ children }: ConversationStoreProviderProps) => {
  const { userId } = useAuth();
  const [remoteConversations, setRemoteConversations] = useState<Conversation[]>([]);
  const [localConversations, setLocalConversations] = useState<Conversation[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQueryState] = useState('');
  const [refreshToken, setRefreshToken] = useState(0);

  const localRef = useRef(localConversations);
  const remoteRef = useRef(remoteConversations);

  useEffect(() => {
    localRef.current = localConversations;
  }, [localConversations]);

  useEffect(() => {
    remoteRef.current = remoteConversations;
  }, [remoteConversations]);

  useEffect(() => {
    if (!userId) {
      setRemoteConversations([]);
      setLocalConversations([]);
      setLoading(false);
      return;
    }

    setLoading(true);

    const unsubscribe = listenToConversations(userId, (conversations) => {
      setRemoteConversations(conversations);
      setLoading(false);
      setError(null);
    });

    return () => unsubscribe();
  }, [userId, refreshToken]);

  const setSearchQuery = useCallback((query: string) => {
    setSearchQueryState(query);
  }, []);

  const debouncedQuery = useDebouncedValue(searchQuery, DEFAULT_DEBOUNCE_MS);

  const mergedConversations = useMemo(
    () => sortConversations(mergeConversations(localConversations, remoteConversations)),
    [localConversations, remoteConversations]
  );

  const activeConversations = useMemo(
    () => mergedConversations.filter((conversation) => !conversation.isArchived),
    [mergedConversations]
  );

  const archivedConversations = useMemo(
    () => sortConversations(mergedConversations.filter((conversation) => conversation.isArchived)),
    [mergedConversations]
  );

  const pinnedConversations = useMemo(
    () => sortConversations(activeConversations.filter((conversation) => conversation.isPinned)),
    [activeConversations]
  );

  const unpinnedConversations = useMemo(
    () => sortConversations(activeConversations.filter((conversation) => !conversation.isPinned)),
    [activeConversations]
  );

  const filteredConversations = useMemo(() => {
    const normalizedQuery = debouncedQuery.trim().toLowerCase();
    if (!normalizedQuery) {
      return activeConversations;
    }

    return activeConversations.filter((conversation) =>
      conversation.title.toLowerCase().includes(normalizedQuery)
    );
  }, [activeConversations, debouncedQuery]);

  const createConversation = useCallback((title?: string): Conversation => {
    const conversation = createConversationModel(title);
    setLocalConversations((prev) => upsertConversation(prev, conversation));
    return conversation;
  }, []);

  const saveConversation = useCallback(
    async (conversation: Conversation): Promise<void> => {
      if (!userId) {
        throw new Error('User must be signed in to save conversations.');
      }

      setError(null);

      try {
        await createConversationFirestore(userId, conversation);
        setLocalConversations((prev) => prev.filter((item) => item.id !== conversation.id));
        setRemoteConversations((prev) => upsertConversation(prev, conversation));
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to save conversation.';
        setError(message);
        throw err;
      }
    },
    [userId]
  );

  const updateConversation = useCallback(
    async (id: string, updates: Partial<Conversation>): Promise<void> => {
      const shouldTouch = updates.updatedAt === undefined && shouldTouchConversation(updates);
      const nextUpdates = shouldTouch ? { ...updates, updatedAt: new Date() } : updates;

      setLocalConversations((prev) => updateConversationInList(prev, id, nextUpdates));
      setRemoteConversations((prev) => updateConversationInList(prev, id, nextUpdates));

      if (!userId) {
        return;
      }

      const isLocalOnly = localRef.current.some((conversation) => conversation.id === id);
      if (isLocalOnly) {
        return;
      }

      setError(null);

      try {
        await updateConversationFirestore(userId, id, nextUpdates);
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to update conversation.';
        setError(message);
        throw err;
      }
    },
    [userId]
  );

  const deleteConversation = useCallback(
    async (id: string): Promise<void> => {
      if (!userId) {
        throw new Error('User must be signed in to delete conversations.');
      }

      if (!window.confirm('Delete this conversation? This cannot be undone.')) {
        return;
      }

      const previousLocal = localRef.current;
      const previousRemote = remoteRef.current;

      setLocalConversations((prev) => prev.filter((conversation) => conversation.id !== id));
      setRemoteConversations((prev) => prev.filter((conversation) => conversation.id !== id));

      setError(null);

      try {
        await deleteConversationFirestore(userId, id);
      } catch (err) {
        setLocalConversations(previousLocal);
        setRemoteConversations(previousRemote);
        const message = err instanceof Error ? err.message : 'Failed to delete conversation.';
        setError(message);
        throw err;
      }
    },
    [userId]
  );

  const pinConversation = useCallback(
    async (id: string): Promise<void> =>
      updateConversation(id, { isPinned: true, updatedAt: new Date() }),
    [updateConversation]
  );

  const unpinConversation = useCallback(
    async (id: string): Promise<void> =>
      updateConversation(id, { isPinned: false, updatedAt: new Date() }),
    [updateConversation]
  );

  const archiveConversation = useCallback(
    async (id: string): Promise<void> =>
      updateConversation(id, { isArchived: true, updatedAt: new Date() }),
    [updateConversation]
  );

  const unarchiveConversation = useCallback(
    async (id: string): Promise<void> =>
      updateConversation(id, { isArchived: false, updatedAt: new Date() }),
    [updateConversation]
  );

  const refreshConversations = useCallback(() => {
    setRefreshToken((prev) => prev + 1);
  }, []);

  const value = useMemo<ConversationStoreValue>(
    () => ({
      conversations: mergedConversations,
      archivedConversations,
      loading,
      error,
      searchQuery,
      filteredConversations,
      pinnedConversations,
      unpinnedConversations,
      setSearchQuery,
      createConversation,
      saveConversation,
      updateConversation,
      deleteConversation,
      pinConversation,
      unpinConversation,
      archiveConversation,
      unarchiveConversation,
      refreshConversations,
    }),
    [
      mergedConversations,
      archivedConversations,
      loading,
      error,
      searchQuery,
      filteredConversations,
      pinnedConversations,
      unpinnedConversations,
      setSearchQuery,
      createConversation,
      saveConversation,
      updateConversation,
      deleteConversation,
      pinConversation,
      unpinConversation,
      archiveConversation,
      unarchiveConversation,
      refreshConversations,
    ]
  );

  return (
    <ConversationStoreContext.Provider value={value}>
      {children}
    </ConversationStoreContext.Provider>
  );
};

export const useConversations = (): ConversationStoreValue => {
  const context = useContext(ConversationStoreContext);
  if (!context) {
    throw new Error('useConversations must be used within ConversationStoreProvider');
  }
  return context;
};
