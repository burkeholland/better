import React from 'react';

const ThinkingIndicator: React.FC = () => {
  return (
    <div className="flex items-center gap-1 h-6">
      <div className="w-2 h-2 rounded-full bg-peach animate-bounce [animation-delay:-0.3s]"></div>
      <div className="w-2 h-2 rounded-full bg-lavender animate-bounce [animation-delay:-0.15s]"></div>
      <div className="w-2 h-2 rounded-full bg-skyBlue animate-bounce"></div>
    </div>
  );
};

export default ThinkingIndicator;
