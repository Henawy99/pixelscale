import { Button, HStack, Image, Spacer, Text, VStack, ZStack } from '@expo/ui/swift-ui';
import {
  background,
  buttonStyle,
  font,
  foregroundStyle,
  frame,
  layoutPriority,
  padding,
  shapes,
  truncationMode,
} from '@expo/ui/swift-ui/modifiers';
import type { SFSymbol } from 'sf-symbols-typescript';
import { text } from './theme';

/** Small rounded chip, e.g. "Review" or "Last minute". */
export function Tag({ label, color, icon }: { label: string; color: string; icon?: SFSymbol }) {
  return (
    <HStack
      spacing={3}
      modifiers={[
        padding({ horizontal: 7, vertical: 2 }),
        background(`${toHex(color)}22`, shapes.capsule()),
      ]}>
      {icon ? <Image systemName={icon} size={9} color={color} /> : null}
      <Text modifiers={[text.caption2, text.oneLine, foregroundStyle(color)]}>{label}</Text>
    </HStack>
  );
}

/** Colored circle with the person's initial. */
export function Avatar({ name, color, size = 36 }: { name: string; color?: string; size?: number }) {
  return (
    <ZStack
      modifiers={[
        frame({ width: size, height: size }),
        background(color || '#64748b', shapes.circle()),
      ]}>
      <Text modifiers={[font({ size: size * 0.42, weight: 'semibold', design: 'rounded' }), foregroundStyle('white')]}>
        {(name.trim().charAt(0) || '?').toUpperCase()}
      </Text>
    </ZStack>
  );
}

/** A label/value pair laid out like iOS Settings: title left, value right. Tappable when `onPress` is set. */
export function ValueRow({
  title,
  value,
  valueColor,
  icon,
  iconColor,
  bold,
  onPress,
}: {
  title: string;
  value: string;
  valueColor?: string;
  icon?: SFSymbol;
  iconColor?: string;
  bold?: boolean;
  onPress?: () => void;
}) {
  const row = (
    <HStack spacing={10}>
      {icon ? <Image systemName={icon} size={15} color={iconColor ?? 'gray'} modifiers={[frame({ width: 22 })]} /> : null}
      <Text modifiers={[bold ? text.headline : text.body, text.primary]}>{title}</Text>
      <Spacer />
      <Text
        modifiers={[
          bold ? text.headline : text.body,
          text.digits,
          valueColor ? foregroundStyle(valueColor) : text.secondary,
        ]}>
        {value}
      </Text>
    </HStack>
  );
  return onPress ? <Button onPress={onPress}>{row}</Button> : row;
}

/** Big stat block: small caption on top, bold number below. */
export function Stat({ label, value, color }: { label: string; value: string; color?: string }) {
  return (
    <VStack alignment="leading" spacing={2}>
      <Text modifiers={[text.caption, text.secondary]}>{label}</Text>
      <Text modifiers={[text.title, text.digits, color ? foregroundStyle(color) : text.primary]}>{value}</Text>
    </VStack>
  );
}


/** SwiftUI named colors can't take an alpha suffix, so map them to hex first. */
const NAMED: Record<string, string> = {
  red: '#FF3B30',
  orange: '#FF9500',
  yellow: '#FFCC00',
  green: '#34C759',
  mint: '#00C7BE',
  teal: '#30B0C7',
  cyan: '#32ADE6',
  blue: '#007AFF',
  indigo: '#5856D6',
  purple: '#AF52DE',
  pink: '#FF2D55',
  brown: '#A2845E',
  gray: '#8E8E93',
};

export function toHex(color: string): string {
  return NAMED[color] ?? color;
}

/** Row of tappable color dots; the selected one shows a checkmark. */
export function ColorSwatches({
  colors,
  value,
  onChange,
}: {
  colors: string[];
  value: string;
  onChange: (color: string) => void;
}) {
  return (
    <HStack spacing={12}>
      {/* Separate borderless buttons: several plain tap targets in one Form row don't receive taps. */}
      {colors.map((c) => (
        <Button key={c} onPress={() => onChange(c)} modifiers={[buttonStyle('borderless')]}>
          <ZStack modifiers={[frame({ width: 30, height: 30 }), background(c, shapes.circle())]}>
            <Image systemName="checkmark" size={13} color={c === value ? 'white' : 'clear'} />
          </ZStack>
        </Button>
      ))}
    </HStack>
  );
}

/** Settings-style row: tinted icon tile, title, trailing value and chevron. */
export function NavRow({
  icon,
  iconColor,
  title,
  value,
  onPress,
}: {
  icon: SFSymbol;
  iconColor: string;
  title: string;
  value?: string;
  onPress: () => void;
}) {
  return (
    <Button onPress={onPress}>
      <HStack spacing={12}>
        <ZStack modifiers={[frame({ width: 30, height: 30 }), background(iconColor, shapes.roundedRectangle({ cornerRadius: 7 }))]}>
          <Image systemName={icon} size={15} color="white" />
        </ZStack>
        <Text modifiers={[text.body, text.primary, text.oneLine, layoutPriority(1)]}>{title}</Text>
        <Spacer />
        {value ? <Text modifiers={[text.body, text.secondary, text.oneLine, truncationMode('middle')]}>{value}</Text> : null}
        <Image systemName="chevron.right" size={13} color="#C7C7CC" />
      </HStack>
    </Button>
  );
}
