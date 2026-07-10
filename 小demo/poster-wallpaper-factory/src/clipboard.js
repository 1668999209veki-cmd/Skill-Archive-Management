export async function copyTextToClipboard(text, environment = globalThis) {
  const clipboard = environment.navigator?.clipboard;

  if (clipboard?.writeText) {
    try {
      await clipboard.writeText(text);
      return { ok: true, method: 'clipboard' };
    } catch {
      // Some embedded browsers expose Clipboard API but reject writes.
    }
  }

  return copyWithSelection(text, environment);
}

function copyWithSelection(text, environment) {
  const document = environment.document;

  if (!document?.body || typeof document.createElement !== 'function' || typeof document.execCommand !== 'function') {
    return { ok: false, method: 'none' };
  }

  const textarea = document.createElement('textarea');
  textarea.value = text;
  textarea.setAttribute('readonly', '');
  textarea.style.position = 'fixed';
  textarea.style.insetBlockStart = '0';
  textarea.style.insetInlineStart = '0';
  textarea.style.opacity = '0';
  textarea.style.pointerEvents = 'none';

  document.body.appendChild(textarea);
  textarea.focus();
  textarea.select();

  try {
    const ok = document.execCommand('copy');
    return {
      ok: Boolean(ok),
      method: ok ? 'selection' : 'none',
    };
  } finally {
    document.body.removeChild(textarea);
  }
}
