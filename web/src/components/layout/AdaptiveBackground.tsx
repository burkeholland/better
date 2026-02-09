import React from 'react';

interface AdaptiveBackgroundProps {
  children: React.ReactNode;
}

const AdaptiveBackground: React.FC<AdaptiveBackgroundProps> = ({ children }) => {
  return (
    <div className="min-h-screen w-full bg-gradient-bg-light dark:bg-gradient-bg-dark text-charcoal dark:text-lightGray transition-colors duration-300">
      {/* Optional: Add a subtle texture or noise if desired, but sticking to gradient for now */}
      {children}
    </div>
  );
};

export default AdaptiveBackground;
