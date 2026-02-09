import React, { useEffect, useState } from 'react';
import { Combobox, Transition } from '@headlessui/react';
import { Check, ChevronsUpDown, Loader2 } from 'lucide-react';
import { GeminiAPIClient } from '../../services/gemini/client';
import clsx from 'clsx';

interface ModelPickerProps {
  selected: string;
  onChange: (model: string) => void;
  apiKey: string | null;
}

export const ModelPicker: React.FC<ModelPickerProps> = ({ selected, onChange, apiKey }) => {
  const [query, setQuery] = useState('');
  const [models, setModels] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const fetchModels = async () => {
      setLoading(true);
      try {
        const client = new GeminiAPIClient(apiKey || '');
        // If no API key, we can't really list models, but client handles it by returning fallback
        // However, if the user hasn't set an API key yet, we probably shouldn't try, 
        // or just use the hardcoded list directly.
        // The client currently throws/warns and returns fallback if valid key defaults.
        const modelList = await client.listModels();
        // Strip "models/" prefix for display/matching if present
        const cleanModels = modelList.map(m => m.replace(/^models\//, ''));
        setModels(cleanModels);
      } catch (error) {
        console.error('Failed to fetch models:', error);
        setModels(['gemini-2.0-flash', 'gemini-1.5-pro']);
      } finally {
        setLoading(false);
      }
    };

    fetchModels();
  }, [apiKey]);

  const filteredModels =
    query === ''
      ? models
      : models.filter((model) =>
          model.toLowerCase().includes(query.toLowerCase())
        );

  // Clean the selected value for display (strip models/)
  const displaySelected = selected.replace(/^models\//, '');

  return (
    <div className="w-full">
      <Combobox value={displaySelected} onChange={onChange}>
        <div className="relative mt-1">
          <div className="relative w-full cursor-default overflow-hidden rounded-xl bg-white/10 text-left shadow-md focus:outline-none focus-visible:ring-2 focus-visible:ring-white/75 focus-visible:ring-offset-2 focus-visible:ring-offset-teal-300 sm:text-sm border border-white/10 backdrop-blur-md">
            <Combobox.Input
              className="w-full border-none py-3 pl-4 pr-10 text-sm leading-5 text-gray-900 dark:text-gray-100 bg-transparent focus:ring-0 placeholder-gray-500"
              displayValue={(model: string) => model}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Select a model..."
            />
            <Combobox.Button className="absolute inset-y-0 right-0 flex items-center pr-2">
              {loading ? (
                <Loader2 className="h-4 w-4 animate-spin text-gray-400" />
              ) : (
                <ChevronsUpDown
                  className="h-5 w-5 text-gray-400"
                  aria-hidden="true"
                />
              )}
            </Combobox.Button>
          </div>
          <Transition
            as={React.Fragment}
            leave="transition ease-in duration-100"
            leaveFrom="opacity-100"
            leaveTo="opacity-0"
            afterLeave={() => setQuery('')}
          >
            <Combobox.Options className="absolute mt-1 max-h-60 w-full overflow-auto rounded-md bg-[#1c1c1e] py-1 text-base shadow-lg ring-1 ring-black/5 focus:outline-none sm:text-sm z-50 border border-white/10">
              {filteredModels.length === 0 && query !== '' ? (
                <div className="relative cursor-default select-none py-2 px-4 text-gray-400">
                  Nothing found.
                </div>
              ) : (
                filteredModels.map((model) => (
                  <Combobox.Option
                    key={model}
                    className={({ active }) =>
                      clsx(
                        'relative cursor-pointer select-none py-2 pl-4 pr-4 transition-colors duration-200',
                        active ? 'bg-white/10 text-white' : 'text-gray-300',
                        displaySelected === model && !active ? 'bg-white/5 text-white' : ''
                      )
                    }
                    value={model}
                  >
                    {({ selected, active }) => (
                      <div className="flex items-center justify-between">
                        <span
                          className={clsx(
                            'block truncate',
                            selected ? 'font-medium' : 'font-normal'
                          )}
                        >
                          {model}
                        </span>
                        {selected ? (
                          <span className={clsx('flex items-center pl-3', active ? 'text-white' : 'text-teal-400')}>
                            <Check className="h-4 w-4" aria-hidden="true" />
                          </span>
                        ) : null}
                      </div>

                    )}
                  </Combobox.Option>
                ))
              )}
            </Combobox.Options>
          </Transition>
        </div>
      </Combobox>
    </div>
  );
};
