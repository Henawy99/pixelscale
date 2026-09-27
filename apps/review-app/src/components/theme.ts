import { useColorScheme } from 'react-native';
import {
  font,
  foregroundStyle,
  lineLimit,
  monospacedDigit,
  type ModifierConfig,
} from '@expo/ui/swift-ui/modifiers';

/** Brand accent used as the tint for every Expo UI host. */
export const ACCENT = '#4F46E5';

/**
 * Stack header options: accent-tinted buttons, neutral titles. The explicit soft scroll edge
 * effect is required because screens scroll inside SwiftUI; with `automatic`, rows show through
 * crisp under the status bar. (A header background color hides large titles on iOS 26.)
 *
 * Title colors are plain hex picked from the current scheme: the native header resolves its
 * title color once, so a semantic color would stay black after switching to dark mode.
 */
export function useHeaderOptions() {
  const dark = useColorScheme() === 'dark';
  const label = dark ? '#FFFFFF' : '#000000';
  return {
    headerTintColor: ACCENT,
    headerTitleStyle: { color: label },
    headerLargeTitleStyle: { color: label },
    scrollEdgeEffects: { top: 'soft' },
  } as const;
}

/** Semantic colors for tags and amounts. SwiftUI named colors adapt to dark mode. */
export const tone = {
  positive: 'green',
  negative: 'red',
  warning: 'orange',
  review: 'purple',
  info: 'blue',
  airbnb: '#FF385C',
  gyg: '#FF5533',
} as const;

export const DRIVER_COLORS = ['#3b82f6', '#10b981', '#8b5cf6', '#f59e0b', '#ec4899', '#06b6d4', '#4f46e5'];

/** Reusable modifier presets so every screen shares one type scale. */
export const text = {
  // Explicit colors (not hierarchical styles) so text inside tappable rows isn't tinted.
  primary: foregroundStyle({ type: 'color', color: 'primary' }),
  secondary: foregroundStyle({ type: 'color', color: 'secondary' }),
  tertiary: foregroundStyle({ type: 'color', color: '#8E8E93' }),
  largeNumber: font({ size: 34, weight: 'bold', design: 'rounded' }),
  title: font({ textStyle: 'title3', weight: 'semibold' }),
  headline: font({ textStyle: 'headline' }),
  body: font({ textStyle: 'body' }),
  rowTitle: font({ textStyle: 'subheadline', weight: 'semibold' }),
  subheadline: font({ textStyle: 'subheadline' }),
  footnote: font({ textStyle: 'footnote' }),
  caption: font({ textStyle: 'caption' }),
  captionBold: font({ textStyle: 'caption', weight: 'semibold' }),
  caption2: font({ textStyle: 'caption2', weight: 'medium' }),
  digits: monospacedDigit(),
  oneLine: lineLimit(1),
  twoLines: lineLimit(2),
} satisfies Record<string, ModifierConfig>;
