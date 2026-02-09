import { describe, expect, it } from 'vitest';

import { getApiKey, hasApiKey, removeApiKey, setApiKey } from '../../state/ApiKeyStore';

describe('ApiKeyStore', () => {
  it('stores and retrieves the api key from localStorage', () => {
    setApiKey('test-key');

    expect(getApiKey()).toBe('test-key');
    expect(hasApiKey()).toBe(true);
  });

  it('removes the api key from localStorage', () => {
    setApiKey('test-key');
    removeApiKey();

    expect(getApiKey()).toBeNull();
    expect(hasApiKey()).toBe(false);
  });
});
