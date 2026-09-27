import { useNativeState } from '@expo/ui/swift-ui';
import { useCallback, useState } from 'react';

/**
 * State for an Expo UI `TextField`/`SecureField`. The native observable drives the field;
 * `value` mirrors it for React rendering (e.g. enabling a Save button).
 *
 * Always read with `current()` when saving: during fast input (paste, dictation) SwiftUI
 * coalesces changes and the last `onTextChange` event can be dropped, but the native state
 * itself is always up to date and readable synchronously.
 */
export function useField(initial = '') {
  const state = useNativeState(initial);
  const [value, setValue] = useState(initial);
  const set = useCallback(
    (next: string) => {
      state.set(next);
      setValue(next);
    },
    [state]
  );
  const current = useCallback((): string => {
    const native = state.get();
    return typeof native === 'string' ? native : value;
  }, [state, value]);
  return { state, value, onTextChange: setValue, set, current };
}

export type Field = ReturnType<typeof useField>;

/** Parses "49", "49,50" or "€ 49.50" into a number, or NaN. */
export function parseAmount(raw: string): number {
  const cleaned = raw.replace(/[^0-9.,-]/g, '').replace(',', '.');
  return cleaned ? parseFloat(cleaned) : NaN;
}
