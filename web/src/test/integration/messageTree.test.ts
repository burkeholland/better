import { afterEach, describe, expect, it, vi } from 'vitest';

import { Message } from '../../models/Message';
import {
  getActiveBranch,
  getBranchInfo,
  getMessagesUpTo,
  getSiblings,
  getSubtreeIds,
  switchBranch,
} from '../../logic/messageTree';

const baseTime = new Date('2024-01-01T00:00:00.000Z');

const addMinutes = (date: Date, minutes: number): Date =>
  new Date(date.getTime() + minutes * 60 * 1000);

const createMessage = (
  id: string,
  role: Message['role'],
  parentId: string | null,
  createdAtOffset: number,
  selectedAtOffset?: number
): Message => ({
  id,
  role,
  content: `${role}-${id}`,
  createdAt: addMinutes(baseTime, createdAtOffset),
  selectedAt: selectedAtOffset === undefined ? null : addMinutes(baseTime, selectedAtOffset),
  parentId,
  mediaURL: null,
  mediaMimeType: null,
  inputTokens: null,
  outputTokens: null,
  cachedTokens: null,
  thinkingContent: null,
});

afterEach(() => {
  vi.useRealTimers();
});

describe('getActiveBranch', () => {
  it('returns a linear conversation path', () => {
    const messages = [
      createMessage('u1', 'user', null, 0),
      createMessage('m1', 'model', 'u1', 1),
      createMessage('u2', 'user', 'm1', 2),
      createMessage('m2', 'model', 'u2', 3),
    ];

    const branch = getActiveBranch(messages);

    expect(branch.map((message) => message.id)).toEqual(['u1', 'm1', 'u2', 'm2']);
  });

  it('selects the branch based on latest selectedAt', () => {
    const messages = [
      createMessage('u1', 'user', null, 0),
      createMessage('m1', 'model', 'u1', 1, 2),
      createMessage('m2', 'model', 'u1', 1, 5),
      createMessage('u2', 'user', 'm2', 6),
    ];

    const branch = getActiveBranch(messages);

    expect(branch.map((message) => message.id)).toEqual(['u1', 'm2', 'u2']);
  });

  it('picks the latest root message', () => {
    const messages = [
      createMessage('u1', 'user', null, 0),
      createMessage('m1', 'model', 'u1', 1),
      createMessage('u2', 'user', null, 5),
      createMessage('m2', 'model', 'u2', 6),
    ];

    const branch = getActiveBranch(messages);

    expect(branch.map((message) => message.id)).toEqual(['u2', 'm2']);
  });
});

describe('getSiblings', () => {
  it('returns sibling messages ordered by selection', () => {
    const messages = [
      createMessage('u1', 'user', null, 0),
      createMessage('m1', 'model', 'u1', 1, 2),
      createMessage('m2', 'model', 'u1', 1, 4),
      createMessage('m3', 'model', 'u1', 1, 1),
    ];

    const siblings = getSiblings(messages, 'm1');

    expect(siblings.map((message) => message.id)).toEqual(['m2', 'm1', 'm3']);
  });
});

describe('getBranchInfo', () => {
  it('returns navigation metadata for siblings', () => {
    const messages = [
      createMessage('u1', 'user', null, 0),
      createMessage('m1', 'model', 'u1', 1, 2),
      createMessage('m2', 'model', 'u1', 1, 4),
      createMessage('m3', 'model', 'u1', 1, 1),
    ];

    const info = getBranchInfo(messages, 'm1');

    expect(info).toEqual({
      currentIndex: 1,
      totalSiblings: 3,
      hasPrevious: true,
      hasNext: true,
    });
  });
});

describe('getMessagesUpTo', () => {
  it('returns messages before the requested message in the active branch', () => {
    const messages = [
      createMessage('u1', 'user', null, 0),
      createMessage('m1', 'model', 'u1', 1, 5),
      createMessage('m2', 'model', 'u1', 1, 2),
      createMessage('u2', 'user', 'm1', 3),
      createMessage('m3', 'model', 'u2', 4),
    ];

    const result = getMessagesUpTo(messages, 'm3');

    expect(result.map((message) => message.id)).toEqual(['u1', 'm1', 'u2']);
  });
});

describe('getSubtreeIds', () => {
  it('collects all descendant message ids', () => {
    const messages = [
      createMessage('u1', 'user', null, 0),
      createMessage('m1', 'model', 'u1', 1),
      createMessage('u2', 'user', 'm1', 2),
      createMessage('m2', 'model', 'u2', 3),
      createMessage('u3', 'user', 'm1', 4),
    ];

    const ids = getSubtreeIds(messages, 'm1');

    expect(new Set(ids)).toEqual(new Set(['u2', 'm2', 'u3']));
  });
});

describe('switchBranch', () => {
  it('selects the previous sibling when moving backward', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2024-01-02T00:00:00.000Z'));

    const messages = [
      createMessage('u1', 'user', null, 0),
      createMessage('m1', 'model', 'u1', 1, 5),
      createMessage('m2', 'model', 'u1', 1, 4),
      createMessage('m3', 'model', 'u1', 1, 2),
    ];

    const result = switchBranch(messages, 'm2', 'previous');

    expect(result).toEqual({
      newSelectedId: 'm3',
      newSelectedAt: new Date('2024-01-02T00:00:00.000Z'),
    });
  });

  it('selects the next sibling when moving forward', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2024-01-02T01:00:00.000Z'));

    const messages = [
      createMessage('u1', 'user', null, 0),
      createMessage('m1', 'model', 'u1', 1, 5),
      createMessage('m2', 'model', 'u1', 1, 4),
      createMessage('m3', 'model', 'u1', 1, 2),
    ];

    const result = switchBranch(messages, 'm2', 'next');

    expect(result).toEqual({
      newSelectedId: 'm1',
      newSelectedAt: new Date('2024-01-02T01:00:00.000Z'),
    });
  });
});
