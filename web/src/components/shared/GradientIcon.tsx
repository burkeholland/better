import React from 'react';
import { LucideIcon } from 'lucide-react';

interface GradientIconProps {
  icon: LucideIcon;
  size?: number | string;
  className?: string; // Additional classes for wrapper
  style?: React.CSSProperties;
}

const GradientIcon: React.FC<GradientIconProps> = ({ icon: Icon, size = 24, className = '', style }) => {
  return (
    <div className={`relative flex items-center justify-center ${className}`} style={{ width: size, height: size, ...style }}>
      {/* 
        Technique: SVG Masking or using a background gradient clipped to text doesn't work well on SVGs directly unless used as mask.
        Simpler approach for icons: Render icon with ID for gradient, or use mask-image.
        Here we use mask-image (webkit-mask) for broad support with tailsind utilities or custom styles.
      */}
      <div 
        className="absolute inset-0 bg-gradient-accent"
        style={{
          maskImage: `url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='100%' height='100%' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='...' /></svg>")`, 
          // The above is hard because the path d depends on the icon. 
          // Better approach: Render the icon as a mask.
          WebkitMask: 'var(--icon-svg) no-repeat center / contain',
          mask: 'var(--icon-svg) no-repeat center / contain',
        }}
      />
      {/* 
         Actually, the easiest React way without complex CSS masking for dynamic icons:
         Render the SVG definition once with a linearGradient def, and reference it in 'stroke'.
      */}
      <svg width={size} height={size} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" className="block">
        <defs>
          <linearGradient id="icon-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#FF8A65" />
            <stop offset="50%" stopColor="#CE93D8" />
            <stop offset="100%" stopColor="#81D4FA" />
          </linearGradient>
        </defs>
        {/* We render the Lucide icon but force it to use the gradient */}
        <Icon 
          size={size} 
          stroke="url(#icon-gradient)" 
          color="url(#icon-gradient)" // Fallback/some icons use fill
        />
      </svg>
    </div>
  );
};

// The above wrapper approach with <Icon> inside <svg> might validly fail if <Icon> outputs an <svg> itself (nested svgs are okay but props might clash).
// Lucide icons return an <svg> element.
// Correct approach with Lucide: passing `stroke` or `color` prop.
// Lucide accepts descriptive colors, but 'url(#id)' works for SVG props.

const GradientIconSimple: React.FC<GradientIconProps> = ({ icon: Icon, size = 24, className = '' }) => {
  return (
    <div className={`relative inline-flex items-center justify-center ${className}`}>
      {/* Hidden SVG to define the gradient globally or locally */}
      <svg width="0" height="0" className="absolute">
        <defs>
          <linearGradient id="brand-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#FF8A65" />
            <stop offset="50%" stopColor="#CE93D8" />
            <stop offset="100%" stopColor="#81D4FA" />
          </linearGradient>
        </defs>
      </svg>
      <Icon size={size} stroke="url(#brand-gradient)" />
    </div>
  );
};

export default GradientIconSimple;
