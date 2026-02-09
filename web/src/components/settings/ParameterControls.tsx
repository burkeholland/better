import React from 'react';
import Slider from 'rc-slider';
import 'rc-slider/assets/index.css';
import { HelpCircle, Info, X } from 'lucide-react';
import { isThinkingModel } from '../../models/Conversation';

interface ParameterControlsProps {
  temperature: number;
  topP: number;
  topK: number;
  maxOutputTokens: number;
  thinkingBudget: number | null;
  modelName: string;
  onChange: (param: string, value: number | null) => void;
}

interface ControlProps {
  label: string;
  description: string;
  value: number;
  min: number;
  max: number;
  step?: number;
  suffix?: string;
  onChange: (val: number) => void;
  disabled?: boolean;
}

const ControlItem: React.FC<ControlProps> = ({ 
  label, description, value, min, max, step = 1, suffix = '', onChange, disabled 
}) => (
  <div className="flex flex-col gap-2 py-2">
    <div className="flex justify-between items-center">
      <div className="flex items-center gap-2 group relative">
        <label className="text-sm font-medium text-gray-300">{label}</label>
        <div className="relative">
          <Info className="w-3 h-3 text-gray-500 cursor-help" />
          <div className="absolute left-0 bottom-full mb-2 hidden group-hover:block w-48 p-2 bg-black/90 text-xs text-gray-300 rounded shadow-lg z-10 pointer-events-none">
            {description}
          </div>
        </div>
      </div>
      <span className="text-xs font-mono text-gray-400 bg-white/5 px-2 py-0.5 rounded">
        {value}{suffix}
      </span>
    </div>
    <div className="px-1">
      <Slider
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(val) => !disabled && onChange(val as number)}
        disabled={disabled}
        trackStyle={{ backgroundColor: 'var(--color-accent-blue, #60a5fa)', height: 4 }}
        railStyle={{ backgroundColor: 'rgba(255,255,255,0.1)', height: 4 }}
        handleStyle={{
          borderColor: 'var(--color-accent-blue, #60a5fa)',
          height: 16,
          width: 16,
          marginTop: -6,
          backgroundColor: '#fff',
          opacity: 1,
          boxShadow: '0 2px 4px rgba(0,0,0,0.2)'
        }}
      />
    </div>
  </div>
);

export const ParameterControls: React.FC<ParameterControlsProps> = ({
  temperature,
  topP,
  topK,
  maxOutputTokens,
  thinkingBudget,
  modelName,
  onChange,
}) => {
  const isThinking = isThinkingModel(modelName);

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-x-8 gap-y-6">
        <ControlItem
          label="Temperature"
          description="Controls randomness. Higher values mean more creative and unexpected responses. Lower values are more deterministic."
          value={temperature}
          min={0}
          max={2}
          step={0.1}
          onChange={(val) => onChange('temperature', val)}
        />
        
        <ControlItem
          label="Top P"
          description="Nucleus sampling. Takes the smallest set of tokens whose cumulative probability exceeds P. 0.95 is usually good."
          value={topP}
          min={0}
          max={1}
          step={0.05}
          onChange={(val) => onChange('topP', val)}
        />

        <ControlItem
          label="Top K"
          description="Limits the token selection pool to the top K most likely tokens. Lower values make text less random."
          value={topK}
          min={1}
          max={100}
          step={1}
          onChange={(val) => onChange('topK', val)}
        />

        <ControlItem
          label="Max Output Tokens"
          description="The maximum number of tokens to include in the response. One token is roughly 4 characters."
          value={maxOutputTokens}
          min={256}
          max={8192}
          step={256}
          onChange={(val) => onChange('maxOutputTokens', val)}
        />
      </div>

      {isThinking && (
        <div className="border-t border-white/10 pt-4 mt-4">
           <div className="flex justify-between items-center mb-2">
            <div className="flex items-center gap-2">
              <label className="text-sm font-medium text-purple-300">Thinking Budget</label>
              <span className="text-xs text-purple-500/80 bg-purple-500/10 px-1.5 py-0.5 rounded border border-purple-500/20">Thinking Models</span>
            </div>
            
            {thinkingBudget !== null ? (
               <button 
                 onClick={() => onChange('thinkingBudget', null)}
                 className="flex items-center gap-1 text-xs text-red-300 hover:text-red-200"
               >
                 <X className="w-3 h-3" /> Disable
               </button>
            ) : (
              <span className="text-xs text-gray-500">Disabled (Auto)</span>
            )}
           </div>
           
           <div className={thinkingBudget === null ? 'opacity-50 pointer-events-none grayscale' : ''}>
             <ControlItem
                label=""
                description="Token budget for internal reasoning before generating the final response."
                value={thinkingBudget ?? 1024}
                min={1024}
                max={32768}
                step={1024}
                onChange={(val) => onChange('thinkingBudget', val)}
              />
           </div>
           {thinkingBudget === null && (
             <div className="text-center mt-2">
               <button 
                onClick={() => onChange('thinkingBudget', 4096)}
                className="text-xs text-purple-400 hover:text-purple-300 border border-purple-500/30 rounded px-3 py-1 bg-purple-500/10"
               >
                 Enable Thinking Budget
               </button>
             </div>
           )}
        </div>
      )}
    </div>
  );
};
