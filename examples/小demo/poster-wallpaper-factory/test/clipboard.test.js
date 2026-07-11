import { describe, expect, test, vi } from 'vitest';
import { copyTextToClipboard } from '../src/clipboard.js';

describe('clipboard helper', () => {
  test('uses the async Clipboard API when it is available', async () => {
    const writeText = vi.fn().mockResolvedValue(undefined);

    await expect(
      copyTextToClipboard('http://127.0.0.1:5173/demo', {
        navigator: { clipboard: { writeText } },
      }),
    ).resolves.toEqual({ ok: true, method: 'clipboard' });

    expect(writeText).toHaveBeenCalledWith('http://127.0.0.1:5173/demo');
  });

  test('falls back to selection copy when async clipboard is rejected', async () => {
    const writeText = vi.fn().mockRejectedValue(new Error('permission denied'));
    const document = createFakeDocument({ copyResult: true });

    await expect(
      copyTextToClipboard('fallback-url', {
        document,
        navigator: { clipboard: { writeText } },
      }),
    ).resolves.toEqual({ ok: true, method: 'selection' });

    expect(document.createdTextarea.value).toBe('fallback-url');
    expect(document.removedTextarea).toBe(document.createdTextarea);
  });

  test('reports failure when no copy method is available', async () => {
    await expect(copyTextToClipboard('nope', {})).resolves.toEqual({
      ok: false,
      method: 'none',
    });
  });
});

function createFakeDocument({ copyResult }) {
  const textarea = {
    style: {},
    setAttribute: vi.fn(),
    focus: vi.fn(),
    select: vi.fn(),
    value: '',
  };
  const document = {
    createdTextarea: textarea,
    removedTextarea: null,
    body: {
      appendChild: vi.fn(),
      removeChild: vi.fn((element) => {
        document.removedTextarea = element;
      }),
    },
    createElement: vi.fn(() => textarea),
    execCommand: vi.fn(() => copyResult),
  };

  return document;
}
