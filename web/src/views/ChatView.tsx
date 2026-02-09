import { useEffect, useRef, useState } from 'react';
import { Menu, Sparkles, Sliders } from 'lucide-react';
import AdaptiveBackground from '../components/layout/AdaptiveBackground';
import SideMenu from '../components/layout/SideMenu';
import MessageBubble from '../components/chat/MessageBubble';
import MessageInput from '../components/chat/MessageInput';
import BranchNavigator from '../components/chat/BranchNavigator';
import ThinkingIndicator from '../components/chat/ThinkingIndicator';
import GradientIcon from '../components/shared/GradientIcon';
import { Conversation } from '../models/Conversation';
import { Message, createUserMessage, createModelMessage } from '../models/Message';
import { buildGeminiPayload, attachMediaToMessage } from '../logic/messagePayload';
import { GeminiAPIClient } from '../services/gemini/client';
import { handleFunctionCall, handleGenerateImage, handleGenerateVideo } from '../services/gemini/toolHandlers';
import { createMessage as createMessageDoc, listenToMessages } from '../services/firestoreService';
import { uploadFile } from '../services/storageService';
import { getApiKey } from '../state/ApiKeyStore';
import { useAuth } from '../state/AuthContext';
import { useConversations } from '../state/ConversationStore';
import { SettingsView } from './SettingsView';
import { ChatSettingsView } from './ChatSettingsView';

const ChatView: React.FC = () => {
  const { userId } = useAuth();
  const {
    conversations,
    pinnedConversations,
    unpinnedConversations,
    loading: conversationsLoading,
    createConversation,
    saveConversation,
    updateConversation: updateConversationStore,
  } = useConversations();

  const [activeId, setActiveId] = useState<string | null>(null);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  const [messages, setMessages] = useState<Message[]>([]);
  const [messagesLoading, setMessagesLoading] = useState(false);
  const [isGenerating, setIsGenerating] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Track if conversation has been saved to Firestore (for new local-only conversations)
  const [conversationSaved, setConversationSaved] = useState<Set<string>>(new Set());
  
  // Settings State
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [isChatSettingsOpen, setIsChatSettingsOpen] = useState(false);

  const scrollRef = useRef<HTMLDivElement>(null);

  const detectIntent = (text: string): 'text' | 'image' | 'video' => {
    const normalized = text.trim().toLowerCase();

    if (!normalized) {
      return 'text';
    }

    const imagePatterns = [
      /^image\s*:/,
      /^img\s*:/,
      /\b(generate|create|make|draw|render)\b.*\b(image|picture|photo|illustration|art|logo|poster|diagram)\b/,
      /\b(image|picture|photo|illustration|art|logo|poster|diagram)\b.*\b(generate|create|make|draw|render)\b/,
    ];

    const videoPatterns = [
      /^video\s*:/,
      /\b(generate|create|make|render)\b.*\b(video|clip|animation|movie)\b/,
      /\b(video|clip|animation|movie)\b.*\b(generate|create|make|render)\b/,
    ];

    if (videoPatterns.some((pattern) => pattern.test(normalized))) {
      return 'video';
    }

    if (imagePatterns.some((pattern) => pattern.test(normalized))) {
      return 'image';
    }

    return 'text';
  };

  // Set initial active conversation when conversations load
  useEffect(() => {
    if (!conversationsLoading && conversations.length > 0 && !activeId) {
      setActiveId(conversations[0].id);
    }
  }, [conversationsLoading, conversations, activeId]);

  // Listen to messages when active conversation changes
  useEffect(() => {
    if (!userId || !activeId) {
      setMessages([]);
      return;
    }

    // Check if conversation exists in remote (not just local)
    // For brand new local-only conversations, don't try to listen to Firestore yet
    const conversation = conversations.find(c => c.id === activeId);
    if (!conversation) {
      setMessages([]);
      return;
    }

    setMessagesLoading(true);
    
    const unsubscribe = listenToMessages(userId, activeId, (msgs) => {
      setMessages(msgs);
      setMessagesLoading(false);
    });

    return () => unsubscribe();
  }, [userId, activeId, conversationSaved, conversations]);

  // Auto-scroll only when the user sends a message (not on every model update)
  const shouldScrollRef = useRef(false);
  useEffect(() => {
    if (shouldScrollRef.current && scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
      shouldScrollRef.current = false;
    }
  }, [messages]);
  
  const activeConversation = conversations.find(c => c.id === activeId) || null;

  const handleUpdateConversation = async (updates: Partial<Conversation>) => {
    if (!activeConversation) return;
    try {
      await updateConversationStore(activeConversation.id, updates);
    } catch (error) {
      console.error('Failed to update conversation:', error);
    }
  };

  const handleNewChat = () => {
    const newConv = createConversation();
    setActiveId(newConv.id);
    setMessages([]);
    setIsMobileMenuOpen(false);
  };

  const handleSelectConversation = (id: string) => {
    setActiveId(id);
    setIsMobileMenuOpen(false);
  };

  const handleSend = async (text: string, attachment: File | null) => {
    if (isGenerating || isUploading || !activeConversation) return;
    setErrorMessage(null);

    if (!userId) {
      setErrorMessage('Sign in to send messages.');
      return;
    }

    const newUserMsg = createUserMessage(text);

    if (attachment) {
      setIsUploading(true);
      try {
        const downloadURL = await uploadFile(userId, activeConversation.id, newUserMsg.id, attachment);
        newUserMsg.mediaURL = downloadURL;
        newUserMsg.mediaMimeType = attachment.type;
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Failed to upload attachment.';
        setErrorMessage(message);
        setIsUploading(false);
        return;
      }
      setIsUploading(false);
    }

    // Optimistically add user message to UI
    setMessages((prev) => [...prev, newUserMsg]);
    shouldScrollRef.current = true;

    // Save conversation to Firestore if this is the first message
    if (!conversationSaved.has(activeConversation.id)) {
      try {
        // Update title based on first message
        const titleUpdate = text.slice(0, 50) + (text.length > 50 ? '...' : '');
        const conversationToSave = { ...activeConversation, title: titleUpdate };
        await saveConversation(conversationToSave);
        setConversationSaved(prev => new Set(prev).add(activeConversation.id));
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Failed to save conversation.';
        setErrorMessage(message);
        return;
      }
    }

    try {
      await createMessageDoc(userId, activeConversation.id, newUserMsg);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Failed to save message.';
      setErrorMessage(message);
    }

    const apiKey = getApiKey();
    if (!apiKey) {
      setErrorMessage('Add your Gemini API key in settings to continue.');
      return;
    }

    const intent = detectIntent(text);

    setIsGenerating(true);
    const modelMessage = createModelMessage('');
    setMessages((prev) => [...prev, modelMessage]);

    let currentModelMessage: Message = { ...modelMessage };
    let accumulatedText = '';
    let accumulatedThinking = '';

    const updateModelMessage = (updates: Partial<Message>) => {
      currentModelMessage = { ...currentModelMessage, ...updates };
      setMessages((prev) =>
        prev.map((msg) => (msg.id === currentModelMessage.id ? currentModelMessage : msg))
      );
    };

    try {
      if (intent === 'image') {
        const result = await handleGenerateImage(text, apiKey);
        if (result.data && result.mimeType) {
          updateModelMessage(attachMediaToMessage(currentModelMessage, result.data, result.mimeType));
        } else if (result.error) {
          updateModelMessage({ content: result.error });
        }
      } else if (intent === 'video') {
        const result = await handleGenerateVideo(text, apiKey);
        if (result.data && result.mimeType) {
          updateModelMessage(attachMediaToMessage(currentModelMessage, result.data, result.mimeType));
        } else if (result.error) {
          updateModelMessage({ content: result.error });
        }
      } else {
      const payload = await buildGeminiPayload([...messages, newUserMsg], true);
      const client = new GeminiAPIClient(apiKey);
      // Use the conversation's selected model, or fall back to default
      const selectedModel = activeConversation?.modelName || 'gemini-2.0-flash';

      const toolFlags = {
        googleSearch: activeConversation?.googleSearchEnabled,
        codeExecution: activeConversation?.codeExecutionEnabled,
        urlContext: activeConversation?.urlContextEnabled,
        imageGeneration: activeConversation?.imageGenerationEnabled,
        videoGeneration: activeConversation?.videoGenerationEnabled,
      };

      for await (const event of client.stream(selectedModel, { contents: payload }, toolFlags)) {
        if (event.type === 'text') {
          accumulatedText += event.content;
          updateModelMessage({ content: accumulatedText });
        }

        if (event.type === 'thinking') {
          accumulatedThinking += event.content;
          updateModelMessage({ thinkingContent: accumulatedThinking });
        }

        if (event.type === 'usageMetadata') {
          updateModelMessage({
            inputTokens: event.inputTokens,
            outputTokens: event.outputTokens,
            cachedTokens: event.cachedTokens ?? null,
          });
        }

        if (event.type === 'imageData') {
          updateModelMessage(attachMediaToMessage(currentModelMessage, event.data, event.mimeType));
        }

        if (event.type === 'functionCall') {
          const result = await handleFunctionCall({ name: event.name, args: event.args }, apiKey);
          if (result.type === 'image' && result.data && result.mimeType) {
            updateModelMessage(attachMediaToMessage(currentModelMessage, result.data, result.mimeType));
          }
          if (result.error) {
            accumulatedText += `\n\n${result.error}`;
            updateModelMessage({ content: accumulatedText });
          }
        }

        if (event.type === 'error') {
          setErrorMessage(event.message);
          break;
        }

        if (event.type === 'done') {
          break;
        }
      }
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unable to reach Gemini right now.';
      setErrorMessage(message);
    } finally {
      setIsGenerating(false);
    }

    try {
      await createMessageDoc(userId, activeConversation.id, currentModelMessage);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Failed to save response.';
      setErrorMessage(message);
    }
  };

  return (
    <AdaptiveBackground>
      <div className="flex h-screen overflow-hidden">
        {/* Sidebar */}
        <SideMenu 
          conversations={[...pinnedConversations, ...unpinnedConversations]}
          activeConversationId={activeId ?? undefined}
          onSelectConversation={handleSelectConversation}
          onNewChat={handleNewChat}
          onOpenSettings={() => setIsSettingsOpen(true)}
          onOpenParameters={() => setIsChatSettingsOpen(true)}
          isOpen={isMobileMenuOpen}
          onClose={() => setIsMobileMenuOpen(false)}
        />

        {/* Main Chat Area */}
        <div className="flex-1 flex flex-col min-w-0 relative">
          
          {/* Header */}
          <div className="h-16 flex items-center justify-between px-4 lg:px-8 border-b border-black/5 dark:border-white/5 backdrop-blur-sm z-10">
            <div className="flex items-center gap-3 overflow-hidden">
               <button 
                 onClick={() => setIsMobileMenuOpen(true)}
                 className="lg:hidden p-2 -ml-2 text-charcoal dark:text-cream"
               >
                 <Menu size={24} />
               </button>
               <h2 className="text-lg font-semibold text-charcoal dark:text-cream truncate">
                 {activeConversation?.title || 'New Chat'}
               </h2>
               {activeConversation?.modelName && (
                 <div className="hidden sm:block text-xs font-mono text-darkGray/40 dark:text-lightGray/40 bg-black/5 dark:bg-white/5 px-2 py-0.5 rounded">
                    {activeConversation.modelName}
                 </div>
               )}
            </div>
            <button 
               onClick={() => setIsChatSettingsOpen(true)}
               className="p-2 text-darkGray/60 dark:text-lightGray/60 hover:bg-black/5 dark:hover:bg-white/10 rounded-full transition-colors"
               title="Model & Parameters"
               disabled={!activeConversation}
            >
               <Sliders size={20} />
            </button>
          </div>

          {/* Messages */}
          <div 
             ref={scrollRef}
             className="flex-1 overflow-y-auto p-4 lg:p-8 space-y-6 scroll-smooth"
          >
             {errorMessage && (
               <div className="max-w-3xl mx-auto w-full">
                 <div className="rounded-xl bg-red-50 text-red-700 px-4 py-2 text-sm border border-red-100">
                   {errorMessage}
                 </div>
               </div>
             )}
             {conversationsLoading || messagesLoading ? (
                <div className="h-full flex items-center justify-center">
                  <div className="w-8 h-8 border-2 border-lavender border-t-transparent rounded-full animate-spin" />
                </div>
             ) : messages.length === 0 ? (
                 <div className="h-full flex flex-col items-center justify-center text-center opacity-0 animate-fade-in" style={{ animationFillMode: 'forwards' }}>
                     <div className="w-16 h-16 mb-6 rounded-full bg-gradient-bg-light dark:bg-gradient-bg-dark shadow-bubble flex items-center justify-center">
                        <GradientIcon icon={Sparkles} size={32} />
                     </div>
                     <h3 className="text-2xl font-bold text-charcoal dark:text-cream">
                       How can I help?
                     </h3>
                 </div>
             ) : (
                 <div className="max-w-3xl mx-auto w-full pb-4">
                    {messages.map((msg, idx) => (
                        <div key={msg.id} className="group relative">
                           <MessageBubble message={msg} />
                           
                           {/* Branch Navigator (Demo Only - showing on model message as example) */}
                           {msg.role === 'model' && idx === messages.length - 1 && !isGenerating && (
                              <div className="ml-2 mb-4">
                                <BranchNavigator 
                                   currentIndex={0} 
                                   totalCount={1} // Just 1 for demo
                                   onPrevious={() => {}} 
                                   onNext={() => {}} 
                                />
                              </div>
                           )}
                        </div>
                    ))}
                    
                    {isGenerating && (
                        <div className="max-w-[70%]">
                             <ThinkingIndicator />
                        </div>
                    )}
                 </div>
             )}
          </div>

          {/* Input Area */}
          <div className="z-20">
             <MessageInput 
                onSend={handleSend}
                isGenerating={isGenerating}
               isUploading={isUploading}
                onStop={() => setIsGenerating(false)}
                modelName={activeConversation?.modelName || 'gemini-2.0-flash'}
                onModelToggle={(newModel) => handleUpdateConversation({ modelName: newModel })}
             />
          </div>

        </div>

        {/* Global Settings View */}
        <SettingsView 
          isOpen={isSettingsOpen}
          onClose={() => setIsSettingsOpen(false)}
        />

        {/* Chat Settings View */}
        {activeConversation && (
          <ChatSettingsView 
            isOpen={isChatSettingsOpen}
            onClose={() => setIsChatSettingsOpen(false)}
            conversation={activeConversation}
            onUpdate={handleUpdateConversation}
          />
        )}
      </div>
    </AdaptiveBackground>
  );
};

export default ChatView;
