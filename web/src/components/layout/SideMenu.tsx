import React from 'react';
import { 
  MessageSquare, 
  Settings, 
  User, 
  Pin, 
  Search, 
  Sliders, 
  Plus,
  MoreHorizontal
} from 'lucide-react';
import { Conversation } from '../../models/Conversation';
import GradientIcon from '../shared/GradientIcon';

interface SideMenuProps {
  conversations: Conversation[];
  activeConversationId?: string;
  onSelectConversation: (id: string) => void;
  onNewChat: () => void;
  onOpenSettings: () => void;
  onOpenParameters: () => void;
  className?: string;
  isOpen?: boolean; // Mobile state
  onClose?: () => void; // Mobile close
}

const SideMenu: React.FC<SideMenuProps> = ({
  conversations,
  activeConversationId,
  onSelectConversation,
  onNewChat,
  onOpenSettings,
  onOpenParameters,
  className = '',
  isOpen = false,
  onClose
}) => {
  const pinnedConversations = conversations.filter(c => c.isPinned && !c.isArchived);
  const recentConversations = conversations.filter(c => !c.isPinned && !c.isArchived); // Sort by date in parent

  const ConversationRow = ({ conversation }: { conversation: Conversation }) => {
    const isActive = conversation.id === activeConversationId;
    return (
      <div
        role="button"
        tabIndex={0}
        onClick={() => {
          onSelectConversation(conversation.id);
          if (window.innerWidth < 1024 && onClose) onClose();
        }}
        onKeyDown={(e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            onSelectConversation(conversation.id);
            if (window.innerWidth < 1024 && onClose) onClose();
          }
        }}
        className={`
          flex items-center gap-3 p-3 rounded-xl cursor-pointer transition-all duration-200 group
          ${isActive 
            ? 'bg-white/50 dark:bg-charcoal/50 border border-lavender/50 dark:border-lavender/30 shadow-sm' 
            : 'hover:bg-lavender/20 dark:hover:bg-charcoal/30 border border-transparent'
          }
        `}
      >
        <div className="flex-shrink-0">
          {isActive ? (
             <GradientIcon icon={MessageSquare} size={20} />
          ) : (
            <MessageSquare size={20} className="text-darkGray/60 dark:text-lightGray/60" />
          )}
        </div>
        <div className="flex-1 min-w-0">
          <h3 className={`text-sm font-medium truncate ${isActive ? 'text-charcoal dark:text-cream' : 'text-charcoal/80 dark:text-lightGray/80'}`}>
            {conversation.title || 'New Chat'}
          </h3>
          <p className="text-xs text-darkGray/50 dark:text-lightGray/40 truncate">
            {new Date(conversation.updatedAt).toLocaleDateString()}
          </p>
        </div>
        {conversation.isPinned && <Pin size={14} className="text-peach" />}
      </div>
    );
  };

  return (
    <>
      {/* Mobile Backdrop */}
      {isOpen && (
        <div 
          className="lg:hidden fixed inset-0 bg-black/20 backdrop-blur-sm z-40"
          onClick={onClose}
        />
      )}

      {/* Sidebar Container */}
      <div className={`
        fixed lg:static inset-y-0 left-0 z-50 w-72 flex flex-col
        bg-white/40 dark:bg-offBlack/40 backdrop-blur-xl border-r border-white/20 dark:border-white/10
        transition-transform duration-300 ease-in-out
        ${isOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}
        ${className}
      `}>
        {/* Header */}
        <div className="p-4 pt-12 lg:pt-6 flex flex-col gap-4">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-accent">
                Better
              </h1>
              <p className="text-xs font-medium text-darkGray/60 dark:text-lightGray/60 tracking-wider uppercase mt-1">
                Conversations
              </p>
            </div>
            <button 
              onClick={onNewChat}
              className="p-2 rounded-full bg-white/50 dark:bg-charcoal/50 hover:bg-white dark:hover:bg-charcoal shadow-sm transition-all text-charcoal dark:text-lightGray"
              aria-label="New Chat"
            >
              <Plus size={20} />
            </button>
          </div>

          <div className="relative group">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-darkGray/40" size={16} />
            <input 
              type="text" 
              placeholder="Search..." 
              className="w-full pl-9 pr-3 py-2 rounded-xl bg-white/30 dark:bg-white/5 border border-transparent focus:border-lavender/50 focus:bg-white/50 dark:focus:bg-white/10 outline-none text-sm transition-all"
            />
          </div>
        </div>

        {/* Conversation List */}
        <div className="flex-1 overflow-y-auto px-3 py-2 space-y-6 no-scrollbar">
          {pinnedConversations.length > 0 && (
            <div className="space-y-2">
              <h4 className="px-3 text-xs font-semibold text-darkGray/40 dark:text-lightGray/40 uppercase tracking-wider">
                Pinned
              </h4>
              <div className="space-y-1">
                {pinnedConversations.map(c => <ConversationRow key={c.id} conversation={c} />)}
              </div>
            </div>
          )}

          <div className="space-y-2">
            <h4 className="px-3 text-xs font-semibold text-darkGray/40 dark:text-lightGray/40 uppercase tracking-wider">
              Recent
            </h4>
            <div className="space-y-1">
              {recentConversations.map(c => <ConversationRow key={c.id} conversation={c} />)}
              {conversations.length === 0 && (
                <div className="px-3 py-4 text-center text-sm text-darkGray/40">
                  No conversations yet.
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-white/20 dark:border-white/5 space-y-2 bg-white/10 dark:bg-black/10">
          <button 
            onClick={onOpenParameters}
            className="w-full flex items-center gap-3 p-3 rounded-xl hover:bg-white/40 dark:hover:bg-white/5 transition-colors text-left group"
          >
            <div className="p-2 rounded-lg bg-mint/20 text-sage group-hover:bg-mint/30 transition-colors">
              <Sliders size={18} />
            </div>
            <div className="flex-1">
              <span className="block text-sm font-medium text-charcoal dark:text-lightGray">Parameters</span>
              <span className="block text-xs text-darkGray/60 dark:text-lightGray/50">Model & Controls</span>
            </div>
          </button>
          
          <button 
             onClick={onOpenSettings}
             className="w-full flex items-center gap-3 p-3 rounded-xl hover:bg-white/40 dark:hover:bg-white/5 transition-colors text-left group"
          >
             <div className="p-2 rounded-lg bg-lavender/20 text-lilac group-hover:bg-lavender/30 transition-colors">
               <Settings size={18} />
             </div>
             <span className="flex-1 text-sm font-medium text-charcoal dark:text-lightGray">Settings</span>
          </button>
          
          <div className="pt-2 flex items-center gap-3 px-3">
            <div className="w-8 h-8 rounded-full bg-gradient-user flex items-center justify-center text-white font-bold text-xs shadow-sm">
              <User size={14} />
            </div>
            <div className="flex-1 overflow-hidden">
               <p className="text-sm font-medium truncate text-charcoal dark:text-lightGray">User Account</p>
            </div>
          </div>
        </div>
      </div>
    </>
  );
};

export default SideMenu;
