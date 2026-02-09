import React, { useEffect, useState } from 'react';
import { Message, hasMedia, hasTokecounts } from '../../models/Message';
import MarkdownRenderer from '../shared/MarkdownRenderer';
import { ChevronDown, ChevronRight, FileText, ImageOff } from 'lucide-react';
import { isRelativeStoragePath, resolveStorageURL } from '../../services/mediaService';

interface MessageBubbleProps {
  message: Message;
}

const MessageBubble: React.FC<MessageBubbleProps> = ({ message }) => {
  const isUser = message.role === 'user';
  const [isThinkingExpanded, setIsThinkingExpanded] = useState(false);
  const [lightboxURL, setLightboxURL] = useState<string | null>(null);
  const [imageError, setImageError] = useState(false);
  const [resolvedMediaURL, setResolvedMediaURL] = useState<string | null>(null);
  const [mediaLoading, setMediaLoading] = useState(false);

  // Resolve Storage paths to download URLs
  useEffect(() => {
    if (!hasMedia(message) || !message.mediaURL) {
      setResolvedMediaURL(null);
      return;
    }

    const url = message.mediaURL;

    // Full download URL (with token) - use directly, no SDK calls needed
    if (url.startsWith('https://firebasestorage.googleapis.com') && url.includes('token=')) {
      setResolvedMediaURL(url);
      return;
    }

    // Data URL (base64) - use directly
    if (url.startsWith('data:')) {
      setResolvedMediaURL(url);
      return;
    }

    // Other https URLs (shouldn't happen but handle gracefully)
    if (url.startsWith('http://') || url.startsWith('https://')) {
      setResolvedMediaURL(url);
      return;
    }

    // Relative Storage path - need to resolve (legacy data)
    if (isRelativeStoragePath(url)) {
      setMediaLoading(true);
      resolveStorageURL(url)
        .then((resolved) => {
          setResolvedMediaURL(resolved);
          setMediaLoading(false);
        })
        .catch((error) => {
          console.warn('Failed to resolve media URL:', error);
          setResolvedMediaURL(null);
          setMediaLoading(false);
        });
      return;
    }

    // Invalid URL (file:// etc) - show as unavailable
    console.warn('Unsupported media URL format:', url.substring(0, 50));
    setResolvedMediaURL(null);
  }, [message]);

  // Reset image error when URL changes
  useEffect(() => {
    setImageError(false);
  }, [resolvedMediaURL]);

  useEffect(() => {
    if (!lightboxURL) return;
    const handler = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setLightboxURL(null);
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [lightboxURL]);

  // Formatting token counts
  const formatTokens = (metrics: { inputTokens: number | null, outputTokens: number | null, cachedTokens: number | null }) => {
    const parts = [];
    if (metrics.inputTokens) parts.push(`${metrics.inputTokens} in`);
    if (metrics.outputTokens) parts.push(`${metrics.outputTokens} out`);
    if (metrics.cachedTokens) parts.push(`${metrics.cachedTokens} cached`);
    return parts.join(' • ');
  };

  const getFilename = (url: string): string => {
    try {
      const withoutQuery = url.split('?')[0];
      const lastSegment = withoutQuery.split('/').pop();
      if (!lastSegment || lastSegment.startsWith('data:')) {
        return 'document.pdf';
      }
      return decodeURIComponent(lastSegment);
    } catch (error) {
      return 'document.pdf';
    }
  };

  return (
    <div className={`flex w-full mb-6 ${isUser ? 'justify-end' : 'justify-start'}`}>
      <div 
        className={`relative max-w-[85%] lg:max-w-[70%] transition-all ${
           isUser 
             ? 'rounded-[22px] bg-gradient-user shadow-bubble text-offBlack' 
             : 'text-left'
        }`}
      >
        {/* User Content */}
        {isUser && (
           <div className="px-5 py-3.5">
              {/* Media Attachments for User */}
              {hasMedia(message) && (
                 <div className="mb-2">
                    {message.mediaMimeType?.startsWith('image/') ? (
                       mediaLoading ? (
                         <div className="rounded-xl w-64 h-40 bg-black/10 border border-white/20 flex items-center justify-center">
                           <div className="w-6 h-6 border-2 border-white/40 border-t-transparent rounded-full animate-spin" />
                         </div>
                       ) : resolvedMediaURL && !imageError ? (
                         <img 
                           src={resolvedMediaURL} 
                           alt="attachment" 
                           className="rounded-xl w-64 h-auto object-cover border border-white/20 cursor-pointer"
                           onClick={() => setLightboxURL(resolvedMediaURL)}
                           onError={() => setImageError(true)}
                         />
                       ) : (
                         <div className="rounded-xl w-64 h-40 bg-black/10 border border-white/20 flex flex-col items-center justify-center text-white/60">
                           <ImageOff size={32} className="mb-2 opacity-50" />
                           <span className="text-xs">Image unavailable</span>
                         </div>
                       )
                    ) : ( 
                        <a
                          href={resolvedMediaURL || undefined}
                          target="_blank"
                          rel="noreferrer"
                          className="flex items-center gap-2 p-2 bg-white/30 rounded-lg max-w-[200px]"
                        >
                          <FileText size={20} className="opacity-70" />
                          <span className="text-xs truncate opacity-80">
                            {getFilename(message.mediaURL || '')}
                          </span>
                        </a>
                    )}
                 </div>
              )}
              <div className="whitespace-pre-wrap leading-relaxed">
                  {message.content}
              </div>
           </div>
        )}

        {/* Model Content */}
        {!isUser && (
           <div className="pl-2 pr-4">
              {/* Thinking Block */}
              {message.thinkingContent && (
                  <div className="mb-4">
                      <button 
                        onClick={() => setIsThinkingExpanded(!isThinkingExpanded)}
                        className="flex items-center gap-1.5 text-xs font-semibold text-sage hover:text-sage/80 transition-colors uppercase tracking-wide mb-2"
                      >
                          {isThinkingExpanded ? <ChevronDown size={14} /> : <ChevronRight size={14} />}
                          Thinking Process
                      </button>
                      
                      {isThinkingExpanded && (
                          <div className="pl-3 border-l-2 border-sage/30">
                              <p className="text-sm italic text-sage/90 leading-relaxed whitespace-pre-wrap">
                                  {message.thinkingContent}
                              </p>
                          </div>
                      )}
                  </div>
              )}

              {/* Main Response */}
              <div className="markdown-content">
                 <MarkdownRenderer content={message.content} />
              </div>

              {/* Media for Model (Generated images if any, usually internal to markdown or separate part, assuming separate logic or embedded) */}
              {hasMedia(message) && (
                <div className="mt-4">
                  {message.mediaMimeType?.startsWith('image/') ? (
                    mediaLoading ? (
                      <div className="rounded-xl max-w-sm h-40 bg-black/5 dark:bg-white/5 border border-black/10 dark:border-white/10 flex items-center justify-center">
                        <div className="w-6 h-6 border-2 border-lavender border-t-transparent rounded-full animate-spin" />
                      </div>
                    ) : resolvedMediaURL && !imageError ? (
                      <img
                        src={resolvedMediaURL}
                        alt="Generated"
                        className="rounded-xl max-w-sm h-auto shadow-sm cursor-pointer"
                        onClick={() => setLightboxURL(resolvedMediaURL)}
                        onError={() => setImageError(true)}
                      />
                    ) : (
                      <div className="rounded-xl max-w-sm h-40 bg-black/5 dark:bg-white/5 border border-black/10 dark:border-white/10 flex flex-col items-center justify-center text-darkGray/50 dark:text-lightGray/50">
                        <ImageOff size={32} className="mb-2 opacity-50" />
                        <span className="text-xs">Image unavailable</span>
                      </div>
                    )
                  ) : message.mediaMimeType?.startsWith('video/') ? (
                    mediaLoading ? (
                      <div className="rounded-xl max-w-sm h-40 bg-black/5 dark:bg-white/5 border border-black/10 dark:border-white/10 flex items-center justify-center">
                        <div className="w-6 h-6 border-2 border-lavender border-t-transparent rounded-full animate-spin" />
                      </div>
                    ) : resolvedMediaURL ? (
                      <video
                        src={resolvedMediaURL}
                        controls
                        className="rounded-xl max-w-sm h-auto shadow-sm"
                      />
                    ) : (
                      <div className="rounded-xl max-w-sm h-40 bg-black/5 dark:bg-white/5 border border-black/10 dark:border-white/10 flex flex-col items-center justify-center text-darkGray/50 dark:text-lightGray/50">
                        <ImageOff size={32} className="mb-2 opacity-50" />
                        <span className="text-xs">Video unavailable</span>
                      </div>
                    )
                  ) : (
                    <a
                      href={resolvedMediaURL || undefined}
                      target="_blank"
                      rel="noreferrer"
                      className="flex items-center gap-2 p-2 bg-white/30 rounded-lg max-w-[240px]"
                    >
                      <FileText size={20} className="opacity-70" />
                      <span className="text-xs truncate opacity-80">
                        {getFilename(message.mediaURL || '')}
                      </span>
                    </a>
                  )}
                </div>
              )}

              {/* Footer / Tokens */}
              {hasTokecounts(message) && (
                  <div className="mt-2 flex items-center gap-2 select-none group">
                     <div className="flex gap-0.5">
                         <div className="w-1 h-1 rounded-full bg-peach group-hover:scale-125 transition-transform" />
                         <div className="w-1 h-1 rounded-full bg-mint group-hover:scale-125 transition-transform delay-75" />
                         <div className="w-1 h-1 rounded-full bg-skyBlue group-hover:scale-125 transition-transform delay-150" />
                     </div>
                     <span className="text-[10px] text-darkGray/40 dark:text-lightGray/40 font-mono">
                         {formatTokens(message)}
                     </span>
                  </div>
              )}
           </div>
        )}
      </div>
      {lightboxURL && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-6"
          onClick={() => setLightboxURL(null)}
          role="presentation"
        >
          <img
            src={lightboxURL}
            alt="Attachment"
            className="max-h-full max-w-full rounded-2xl shadow-xl"
            onClick={(event) => event.stopPropagation()}
          />
        </div>
      )}
    </div>
  );
};

export default MessageBubble;
