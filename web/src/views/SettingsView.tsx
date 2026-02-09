import React, { useState, useEffect } from 'react';
import { Dialog, Transition } from '@headlessui/react';
import { X, Check, AlertCircle, LogOut, Key, ExternalLink, User } from 'lucide-react';
import * as ApiKeyStore from '../state/ApiKeyStore';
import { useAuth } from '../state/AuthContext';

interface SettingsViewProps {
  isOpen: boolean;
  onClose: () => void;
}

export const SettingsView: React.FC<SettingsViewProps> = ({ isOpen, onClose }) => {
  const { user, signOut } = useAuth();
  const [apiKey, setApiKey] = useState('');
  const [savedKey, setSavedKey] = useState<string | null>(null);
  const [showKey, setShowKey] = useState(false);
  const [successMsg, setSuccessMsg] = useState('');

  useEffect(() => {
    if (isOpen) {
      const stored = ApiKeyStore.getApiKey();
      setSavedKey(stored);
      setApiKey(stored || '');
      setSuccessMsg('');
    }
  }, [isOpen]);

  const handleSaveKey = () => {
    if (!apiKey.trim()) {
      return;
    }
    ApiKeyStore.setApiKey(apiKey.trim());
    setSavedKey(apiKey.trim());
    setSuccessMsg('API Key saved successfully');
    setTimeout(() => setSuccessMsg(''), 3000);
  };

  const handleRemoveKey = () => {
    ApiKeyStore.removeApiKey();
    setSavedKey(null);
    setApiKey('');
    setSuccessMsg('API Key removed');
    setTimeout(() => setSuccessMsg(''), 3000);
  };

  const handleSignOut = async () => {
    try {
      await signOut();
      onClose();
    } catch (error) {
      console.error("Sign out failed", error);
    }
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
              <Dialog.Panel className="w-full max-w-md transform overflow-hidden rounded-2xl bg-[#1c1c1e] p-6 text-left align-middle shadow-xl transition-all border border-white/10">
                <div className="flex justify-between items-center mb-6">
                  <Dialog.Title
                    as="h3"
                    className="text-lg font-medium leading-6 text-white"
                  >
                    Settings
                  </Dialog.Title>
                  <button
                    onClick={onClose}
                    className="rounded-full p-1 hover:bg-white/10 text-gray-400 hover:text-white transition-colors"
                  >
                    <X className="h-5 w-5" />
                  </button>
                </div>

                {/* Account Section */}
                <div className="space-y-6">
                  {user && (
                    <div className="bg-white/5 rounded-xl p-4 border border-white/5">
                      <h4 className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">Account</h4>
                      <div className="flex items-center gap-3 mb-4">
                        {user.photoURL ? (
                          <img src={user.photoURL} alt={user.displayName || 'User'} className="w-10 h-10 rounded-full" />
                        ) : (
                          <div className="w-10 h-10 rounded-full bg-indigo-500/20 flex items-center justify-center text-indigo-400">
                            <User className="w-5 h-5" />
                          </div>
                        )}
                        <div className="flex-1 overflow-hidden">
                          <p className="text-sm font-medium text-white truncate">{user.displayName || 'User'}</p>
                          <p className="text-xs text-gray-400 truncate">{user.email}</p>
                        </div>
                      </div>
                      <button
                        onClick={handleSignOut}
                        className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 text-sm font-medium rounded-lg transition-colors border border-red-500/10"
                      >
                        <LogOut className="w-4 h-4" />
                        Sign Out
                      </button>
                    </div>
                  )}

                  {/* API Key Section */}
                  <div className="bg-white/5 rounded-xl p-4 border border-white/5">
                    <h4 className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">
                      Gemini API Key
                    </h4>
                    <p className="text-xs text-gray-400 mb-3">
                      Your API key is stored locally in your browser and is never sent to our servers.
                    </p>
                    
                    <div className="flex flex-col gap-2">
                       <div className="relative">
                         <input
                           type={showKey ? "text" : "password"}
                           value={apiKey}
                           onChange={(e) => setApiKey(e.target.value)}
                           placeholder="Enter your API Key"
                           className="w-full bg-black/20 border border-white/10 rounded-lg px-3 py-2 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-indigo-500/50 focus:ring-1 focus:ring-indigo-500/50 pr-10"
                         />
                         <button
                           type="button"
                           onClick={() => setShowKey(!showKey)}
                           className="absolute right-2 top-2.5 text-gray-500 hover:text-gray-300 text-xs uppercase font-medium"
                         >
                           {showKey ? "Hide" : "Show"}
                         </button>
                       </div>

                       <div className="flex gap-2">
                         <button
                           onClick={handleSaveKey}
                           disabled={!apiKey.trim() || apiKey === savedKey}
                           className="flex-1 px-3 py-2 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed text-white text-xs font-medium rounded-lg transition-colors flex items-center justify-center gap-1.5"
                         >
                            <Check className="w-3 h-3" />
                            {savedKey && apiKey === savedKey ? 'Saved' : 'Save Key'}
                         </button>
                         {savedKey && (
                            <button
                              onClick={handleRemoveKey}
                              className="px-3 py-2 bg-white/5 hover:bg-white/10 text-gray-400 hover:text-white text-xs font-medium rounded-lg transition-colors"
                              title="Remove API Key"
                            >
                              <X className="w-4 h-4" />
                            </button>
                         )}
                       </div>
                    </div>
                
                    {successMsg && (
                       <p className="text-xs text-green-400 mt-2 flex items-center gap-1.5 animate-in fade-in slide-in-from-top-1">
                         <Check className="w-3 h-3" /> {successMsg}
                       </p>
                    )}

                    <a
                      href="https://aistudio.google.com/app/apikey"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-1 text-xs text-indigo-400 hover:text-indigo-300 mt-3 hover:underline"
                    >
                      Get an API key <ExternalLink className="w-3 h-3" />
                    </a>
                  </div>

                  {/* About Section */}
                  <div className="text-center pt-2">
                    <p className="text-xs text-gray-500">Better Web v0.1.0</p>
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
