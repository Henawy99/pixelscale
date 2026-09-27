import { useMemo, useState } from 'react';
import { Host } from '@expo/ui';
import { Button, HStack, List, Picker, Section, Spacer, Text, VStack } from '@expo/ui/swift-ui';
import { listStyle, tag } from '@expo/ui/swift-ui/modifiers';
import { useAppData } from '@/state/app-data';
import { ALL_TIME, computeRevenue, formatEur, statsForMonth } from '@/lib/finance';
import { currentMonthLabel } from '@/lib/dates';
import { ValueRow } from '@/components/primitives';
import { ACCENT, text, tone } from '@/components/theme';

export default function RevenueScreen() {
  const { bookings, matchTour } = useAppData();
  const summary = useMemo(() => computeRevenue(bookings, matchTour), [bookings, matchTour]);
  const [month, setMonth] = useState(currentMonthLabel());

  const months = summary.months.includes(month) || month === ALL_TIME ? summary.months : [month, ...summary.months];
  const stats = statsForMonth(summary, month);
  const hasTickets = stats.ticketCosts > 0;

  return (
    <Host style={{ flex: 1 }} seedColor={ACCENT}>
      <List modifiers={[listStyle('insetGrouped')]}>
        <Section>
          <Picker label="Period" systemImage="calendar" selection={month} onSelectionChange={(v) => setMonth(String(v))}>
            {months.map((m) => (
              <Text key={m} modifiers={[tag(m)]}>
                {m}
              </Text>
            ))}
            <Text modifiers={[tag(ALL_TIME)]}>{ALL_TIME}</Text>
          </Picker>
        </Section>

        <Section footer={<Text>Cancelled bookings are excluded. Fees: 30% GetYourGuide, 20% Airbnb.</Text>}>
          <VStack alignment="leading" spacing={4}>
            <Text modifiers={[text.caption, text.secondary]}>{hasTickets ? 'Net profit after tickets' : 'Net payout'}</Text>
            <Text modifiers={[text.largeNumber, text.digits]}>{formatEur(hasTickets ? stats.profit : stats.net)}</Text>
            <Text modifiers={[text.footnote, text.secondary]}>{`${stats.count} bookings`}</Text>
          </VStack>
        </Section>

        <Section title="Breakdown">
          <ValueRow title="Gross revenue" value={formatEur(stats.gross)} />
          <ValueRow title="Platform fees" value={`− ${formatEur(stats.fee)}`} />
          {hasTickets ? <ValueRow title="Ticket costs" value={`− ${formatEur(stats.ticketCosts)}`} /> : null}
          <ValueRow
            title={hasTickets ? 'Net profit' : 'Net payout'}
            value={formatEur(hasTickets ? stats.profit : stats.net)}
            valueColor={tone.positive}
            bold
          />
        </Section>

        <Section title={`Tours (€30 and up) · ${stats.normalCount}`}>
          <ValueRow title="Gross" value={formatEur(stats.normalGross)} />
          <ValueRow title="Fees" value={`− ${formatEur(stats.normalFee)}`} />
          <ValueRow title="Net" value={formatEur(stats.normalNet)} bold />
        </Section>

        <Section title={`Review bookings (under €30) · ${stats.reviewCount}`}>
          <ValueRow title="Gross" value={formatEur(stats.reviewGross)} />
          <ValueRow title="Fees" value={`− ${formatEur(stats.reviewFee)}`} />
          <ValueRow title="Net" value={formatEur(stats.reviewNet)} bold />
        </Section>

        {summary.months.length > 1 ? (
          <Section title="By Month">
            {summary.months.map((m) => {
              const s = summary.byMonth[m];
              return (
                <Button key={m} onPress={() => setMonth(m)}>
                  <HStack>
                    <VStack alignment="leading" spacing={2}>
                      <Text modifiers={[text.primary]}>{m}</Text>
                      <Text modifiers={[text.footnote, text.secondary]}>{`${s.count} bookings`}</Text>
                    </VStack>
                    <Spacer />
                    <Text modifiers={[text.digits, m === month ? text.primary : text.secondary]}>
                      {formatEur(s.ticketCosts > 0 ? s.profit : s.net)}
                    </Text>
                  </HStack>
                </Button>
              );
            })}
          </Section>
        ) : null}
      </List>
    </Host>
  );
}
