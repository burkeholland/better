const STORAGE_KEY = 'gemini_api_key';

export const getApiKey = (): string | null => {
  if (typeof window === 'undefined') {
    return null;
  }

  return window.localStorage.getItem(STORAGE_KEY);
};

export const setApiKey = (key: string): void => {
  if (typeof window === 'undefined') {
    return;
  }

  window.localStorage.setItem(STORAGE_KEY, key);
};

export const removeApiKey = (): void => {
  if (typeof window === 'undefined') {
    return;
  }

  window.localStorage.removeItem(STORAGE_KEY);
};

export const hasApiKey = (): boolean => Boolean(getApiKey());
