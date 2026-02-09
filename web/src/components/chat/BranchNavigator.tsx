import React from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';

interface BranchNavigatorProps {
  currentIndex: number;
  totalCount: number;
  onPrevious: () => void;
  onNext: () => void;
  className?: string;
}

const BranchNavigator: React.FC<BranchNavigatorProps> = ({ 
  currentIndex, 
  totalCount, 
  onPrevious, 
  onNext,
  className = ''
}) => {
  if (totalCount <= 1) return null;

  return (
    <div className={`mt-2 flex items-center gap-2 text-xs font-medium text-darkGray/60 dark:text-lightGray/60 ${className}`}>
      <button 
        onClick={onPrevious}
        disabled={currentIndex === 0}
        className="p-1 rounded-md hover:bg-black/5 dark:hover:bg-white/10 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
        aria-label="Previous version"
      >
        <ChevronLeft size={14} />
      </button>
      
      <span>
        {currentIndex + 1} <span className="opacity-50">of</span> {totalCount}
      </span>

      <button 
        onClick={onNext}
        disabled={currentIndex === totalCount - 1}
        className="p-1 rounded-md hover:bg-black/5 dark:hover:bg-white/10 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
        aria-label="Next version"
      >
        <ChevronRight size={14} />
      </button>
    </div>
  );
};

export default BranchNavigator;
