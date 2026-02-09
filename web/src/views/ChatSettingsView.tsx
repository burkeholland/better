import React, { useState, useEffect } from 'react';
import { Dialog, Transition, Switch } from '@headlessui/react';
import { X, RotateCcw, Search, Terminal, Link, Sparkles, Image, Video } from 'lucide-react';
import { Conversation, getDefaultConversationSettings } from '../models/Conversation';
import { ModelPicker } from '../components/settings/ModelPicker';
import { ParameterControls } from '../components/settings/ParameterControls';
import * as ApiKeyStore from '../state/ApiKeyStore';
import clsx from 'clsx';

interface ChatSettingsViewProps {
  isOpen: boolean;
  onClose: () => void;
  conversation: Conversation;
  onUpdate: (updates: Partial<Conversation>) => void;
}

export const ChatSettingsView: React.FC<ChatSettingsViewProps> = ({
  isOpen,
  onClose,
  conversation,
  onUpdate,
}) => {
  const [localSettings, setLocalSettings] = useState<Partial<Conversation>>({});
  const apiKey = ApiKeyStore.getApiKey();

  useEffect(() => {
    if (isOpen) {
      setLocalSettings({
        modelName: conversation.modelName,
        temperature: conversation.temperature,
        topP: conversation.topP,
        topK: conversation.topK,
        maxOutputTokens: conversation.maxOutputTokens,
        thinkingBudget: conversation.thinkingBudget,
        googleSearchEnabled: conversation.googleSearchEnabled,
        codeExecutionEnabled: conversation.codeExecutionEnabled,
        urlContextEnabled: conversation.urlContextEnabled,
        imageGenerationEnabled: conversation.imageGenerationEnabled,
        videoGenerationEnabled: conversation.videoGenerationEnabled,
        systemInstruction: conversation.systemInstruction,
      });
    }
  }, [isOpen, conversation]);

  const handleChange = (key: keyof Conversation, value: any) => {
    setLocalSettings((prev) => ({ ...prev, [key]: value }));
  };

  const handleSave = () => {
    onUpdate(localSettings);
    onClose();
  };

  const handleReset = () => {
     // Keep the current system instruction if it's set? Usually reset means reset parameters.
     // But let's reset to defaults excluding system instruction maybe?
     // For now, full reset to defaults for everything except ID/Title.
     const defaults = getDefaultConversationSettings();
     setLocalSettings({
        ...defaults,
        // Optional: Preserve system instruction if desired, but "Reset defaults" usually implies everything
        systemInstruction: localSettings.systemInstruction 
     });
  };

  return (
    <Transition appear show={isOpen} as={React.Fragment}>
      <Dialog as="div" className="relative z-50" onClose={onClose}>
        <Transition.Child
          as={React.Fragment}
          enter="ease-out duration-300"
          enterFrom="opacity-0"
          enterTo="opacity-100"
          leave="ease-in duration-200"
          leaveFrom="opacity-100"
          leaveTo="opacity-0"
        >
          <div className="fixed inset-0 bg-black/60 backdrop-blur-sm" />
        </Transition.Child>

        <div className="fixed inset-0 overflow-y-auto">
          <div className="flex min-h-full items-center justify-center p-4 text-center">
            <Transition.Child
              as={React.Fragment}
              enter="ease-out duration-300"
              enterFrom="opacity-0 scale-95"
              enterTo="opacity-100 scale-100"
              leave="ease-in duration-200"
              leaveFrom="opacity-100 scale-100"
              leaveTo="opacity-0 scale-95"
            >
              <Dialog.Panel className="w-full max-w-2xl transform overflow-hidden rounded-2xl bg-[#1c1c1e] text-left align-middle shadow-xl transition-all border border-white/10 flex flex-col max-h-[90vh]">
                {/* Header */}
                <div className="flex justify-between items-center p-6 border-b border-white/10 bg-[#1c1c1e]/50 backdrop-blur sticky top-0 z-10">
                  <div>
                    <Dialog.Title as="h3" className="text-lg font-medium leading-6 text-white">
                      Chat Settings
                    </Dialog.Title>
                    <p className="text-sm text-gray-400 mt-1">Configure model and parameters for this conversation</p>
                  </div>
                  <button
                    onClick={onClose}
                    className="rounded-full p-2 hover:bg-white/10 text-gray-400 hover:text-white transition-colors"
                  >
                    <X className="h-5 w-5" />
                  </button>
                </div>

                {/* Content */}
                <div className="p-6 overflow-y-auto custom-scrollbar space-y-8">
                  
                  {/* Model Section */}
                  <section>
                     <h4 className="text-sm font-medium text-gray-400 uppercase tracking-wider mb-4 flex items-center gap-2">
                       <Sparkles className="w-4 h-4" /> Model
                     </h4>
                     <ModelPicker 
                        selected={localSettings.modelName || ''}
                        onChange={(val) => handleChange('modelName', val)}
                        apiKey={apiKey}
                     />
                  </section>

                  {/* Tools Section */}
                  <section>
                    <h4 className="text-sm font-medium text-gray-400 uppercase tracking-wider mb-4">Tools</h4>
                    <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-5 gap-4">
                      
                      <ToolToggle
                        label="Google Search"
                        description="Access real-time information"
                        icon={Search}
                        checked={!!localSettings.googleSearchEnabled}
                        onChange={(val) => handleChange('googleSearchEnabled', val)}
                        color="text-blue-400"
                        bgColor="bg-blue-500"
                      />

                      <ToolToggle
                         label="Code Execution"
                         description="Run Python code"
                         icon={Terminal}
                         checked={!!localSettings.codeExecutionEnabled}
                         onChange={(val) => handleChange('codeExecutionEnabled', val)}
                         color="text-yellow-400"
                         bgColor="bg-yellow-500"
                      />

                      <ToolToggle
                        label="URL Context"
                        description="Read web pages"
                        icon={Link}
                        checked={!!localSettings.urlContextEnabled}
                        onChange={(val) => handleChange('urlContextEnabled', val)}
                        color="text-purple-400"
                        bgColor="bg-purple-500"
                       />

                      <ToolToggle
                        label="Image Generation"
                        description="Generate images on request"
                        icon={Image}
                        checked={!!localSettings.imageGenerationEnabled}
                        onChange={(val) => handleChange('imageGenerationEnabled', val)}
                        color="text-rose-300"
                        bgColor="bg-rose-400"
                      />

                      <ToolToggle
                        label="Video Generation"
                        description="Generate videos on request"
                        icon={Video}
                        checked={!!localSettings.videoGenerationEnabled}
                        onChange={(val) => handleChange('videoGenerationEnabled', val)}
                        color="text-emerald-300"
                        bgColor="bg-emerald-400"
                      />
                    </div>
                  </section>

                  {/* Parameters Section */}
                  <section>
                    <h4 className="text-sm font-medium text-gray-400 uppercase tracking-wider mb-4">Generation Parameters</h4>
                    <ParameterControls
                       temperature={localSettings.temperature ?? 1}
                       topP={localSettings.topP ?? 0.95}
                       topK={localSettings.topK ?? 40}
                       maxOutputTokens={localSettings.maxOutputTokens ?? 8192}
                       thinkingBudget={localSettings.thinkingBudget ?? null}
                       modelName={localSettings.modelName || ''}
                       onChange={handleChange}
                    />
                  </section>

                   {/* System Instruction */}
                   <section>
                     <h4 className="text-sm font-medium text-gray-400 uppercase tracking-wider mb-4">System Instruction</h4>
                     <textarea
                       value={localSettings.systemInstruction || ''}
                       onChange={(e) => handleChange('systemInstruction', e.target.value)}
                       placeholder="Enter a system instruction to guide the model's behavior..."
                       className="w-full h-32 bg-black/20 border border-white/10 rounded-xl px-4 py-3 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-indigo-500/50 focus:ring-1 focus:ring-indigo-500/50 resize-y"
                     />
                   </section>

                </div>

                {/* Footer */}
                <div className="p-6 border-t border-white/10 bg-[#1c1c1e] flex justify-between items-center sticky bottom-0 z-10">
                   <button
                     onClick={handleReset}
                     className="px-4 py-2 text-sm font-medium text-gray-400 hover:text-white flex items-center gap-2 hover:bg-white/5 rounded-lg transition-colors"
                   >
                     <RotateCcw className="w-4 h-4" /> Reset Defaults
                   </button>
                   <div className="flex gap-3">
                     <button
                       onClick={onClose}
                       className="px-4 py-2 text-sm font-medium text-gray-300 hover:text-white hover:bg-white/5 rounded-lg transition-colors"
                     >
                       Cancel
                     </button>
                     <button
                       onClick={handleSave}
                       className="px-6 py-2 bg-gradient-to-r from-indigo-600 to-indigo-500 hover:from-indigo-500 hover:to-indigo-400 text-white text-sm font-medium rounded-lg shadow-lg shadow-indigo-500/20 transition-all transform hover:scale-[1.02] active:scale-[0.98]"
                     >
                       Apply Changes
                     </button>
                   </div>
                </div>

              </Dialog.Panel>
            </Transition.Child>
          </div>
        </div>
      </Dialog>
    </Transition>
  );
};

interface ToolToggleProps {
  label: string;
  description: string;
  icon: any;
  checked: boolean;
  onChange: (checked: boolean) => void;
  color: string;
  bgColor: string;
}

const ToolToggle: React.FC<ToolToggleProps> = ({
  label, description, icon: Icon, checked, onChange, color, bgColor
}) => (
  <div onClick={() => onChange(!checked)} className={clsx(
    "relative cursor-pointer rounded-xl p-4 border transition-all duration-200",
    checked ? `border-${bgColor.replace('bg-', '')}/50 bg-${bgColor.replace('bg-', '')}/10` : "border-white/5 bg-white/5 hover:bg-white/10"
  )}>
    <div className="flex items-start justify-between mb-2">
      <div className={clsx("p-2 rounded-lg", checked ? "bg-white/10" : "bg-white/5")}>
         <Icon className={clsx("w-5 h-5", checked ? color : "text-gray-400")} />
      </div>
      <Switch
        checked={checked}
        onChange={onChange}
        className={clsx(
          checked ? bgColor : 'bg-gray-700',
          'relative inline-flex h-5 w-9 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus-visible:ring-2  focus-visible:ring-white/75'
        )}
      >
        <span className="sr-only">Enable {label}</span>
        <span
          aria-hidden="true"
          className={clsx(
            checked ? 'translate-x-4' : 'translate-x-0',
            'pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow-lg ring-0 transition duration-200 ease-in-out'
          )}
        />
      </Switch>
    </div>
    <div>
      <h5 className={clsx("text-sm font-medium mb-0.5", checked ? "text-white" : "text-gray-300")}>{label}</h5>
      <p className="text-xs text-gray-500">{description}</p>
    </div>
  </div>
);
