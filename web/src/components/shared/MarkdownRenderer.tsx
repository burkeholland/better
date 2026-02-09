import React from 'react';
import ReactMarkdown from 'react-markdown';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { vscDarkPlus, atomDark } from 'react-syntax-highlighter/dist/esm/styles/prism';
import remarkGfm from 'remark-gfm';

interface MarkdownRendererProps {
  content: string;
}

const MarkdownRenderer: React.FC<MarkdownRendererProps> = ({ content }) => {
  return (
    <ReactMarkdown
      remarkPlugins={[remarkGfm]}
      components={{
        code({ node, className, children, ...props }) {
          const match = /language-(\w+)/.exec(className || '');
          const isInline = !match;
          
          if (isInline) {
             return (
               <code className="bg-black/5 dark:bg-white/10 rounded px-1 py-0.5 text-sm font-mono text-charcoal dark:text-cream" {...props}>
                 {children}
               </code>
             );
          }

          return (
            <div className="rounded-lg overflow-hidden my-3 shadow-sm border border-black/5 dark:border-white/5">
                <div className="bg-charcoal px-3 py-1.5 flex justify-between items-center border-b border-white/10">
                    <span className="text-xs text-lightGray/60 font-mono">{match?.[1] || 'text'}</span>
                </div>
                <SyntaxHighlighter
                  style={vscDarkPlus as any} // Forced cast due to types
                  language={match?.[1]}
                  PreTag="div"
                  customStyle={{ margin: 0, borderRadius: 0, padding: '1rem', fontSize: '0.9rem' }}
                  {...(props as any)}
                >
                  {String(children).replace(/\n$/, '')}
                </SyntaxHighlighter>
            </div>
          );
        },
        p: ({ children }) => <p className="mb-3 last:mb-0 leading-relaxed text-charcoal dark:text-cream/90">{children}</p>,
        ul: ({ children }) => <ul className="list-disc pl-5 mb-3 text-charcoal dark:text-cream/90 space-y-1">{children}</ul>,
        ol: ({ children }) => <ol className="list-decimal pl-5 mb-3 text-charcoal dark:text-cream/90 space-y-1">{children}</ol>,
        li: ({ children }) => <li className="pl-1 leading-relaxed">{children}</li>,
        h1: ({ children }) => <h1 className="text-2xl font-bold mb-4 mt-6 text-charcoal dark:text-cream">{children}</h1>,
        h2: ({ children }) => <h2 className="text-xl font-bold mb-3 mt-5 text-charcoal dark:text-cream">{children}</h2>,
        h3: ({ children }) => <h3 className="text-lg font-semibold mb-2 mt-4 text-charcoal dark:text-cream">{children}</h3>,
        blockquote: ({ children }) => (
          <blockquote className="border-l-4 border-lavender pl-4 py-1 my-3 bg-black/5 dark:bg-white/5 rounded-r italic text-darkGray dark:text-lightGray/80">
            {children}
          </blockquote>
        ),
        a: ({ children, href }) => (
            <a href={href} className="text-skyBlue hover:underline break-words" target="_blank" rel="noopener noreferrer">
                {children}
            </a>
        ),
        table: ({ children }) => (
            <div className="overflow-x-auto my-4 border border-black/10 dark:border-white/10 rounded-lg">
                <table className="min-w-full divide-y divide-black/10 dark:divide-white/10 bg-white/50 dark:bg-white/5">{children}</table>
            </div>
        ),
        th: ({ children }) => <th className="px-3 py-2 text-left text-xs font-semibold uppercase tracking-wider bg-black/5 dark:bg-white/10">{children}</th>,
        td: ({ children }) => <td className="px-3 py-2 text-sm border-t border-black/5 dark:border-white/5">{children}</td>,
      }}
    >
      {content}
    </ReactMarkdown>
  );
};

export default MarkdownRenderer;
