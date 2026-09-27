import { Button, HStack, Image, Spacer, Text, VStack } from '@expo/ui/swift-ui';
import { frame, layoutPriority, opacity, strikethrough } from '@expo/ui/swift-ui/modifiers';
import { useRouter } from 'expo-router';
import {
  BookingItem,
  Driver,
  DriverAssignment,
  Reviewer,
  ReviewerAssignment,
  getNumericPrice,
  isBookingReview,
} from '../types';
import { bookingDate, bookingTime, monthShort, weekdayShort } from '../lib/dates';
import { formatEurWhole } from '../lib/finance';
import { parsePassengerCount } from '../lib/tours';
import { useAppData } from '../state/app-data';
import { Tag } from './primitives';
import { text, tone } from './theme';

interface BookingRowProps {
  booking: BookingItem;
  drivers: Driver[];
  assignment?: DriverAssignment;
  reviewers: Reviewer[];
  reviewerAssignment?: ReviewerAssignment;
  /** "date" shows a calendar block on the left, "time" shows the start time (for day views). */
  leading?: 'date' | 'time';
}

/**
 * One booking, three lines, always in the same order so the eye can scan a column:
 * tour · time/customer/guests · status tags, with the price pinned to the right.
 */
export function BookingRow({
  booking,
  drivers,
  assignment,
  reviewers,
  reviewerAssignment,
  leading = 'date',
}: BookingRowProps) {
  const router = useRouter();
  const { matchTour } = useAppData();
  const isCancelled = booking.status === 'cancelled';
  const isReview = isBookingReview(booking);
  const date = bookingDate(booking);
  const time = bookingTime(booking);
  const guests = parsePassengerCount(booking.participants);

  const driver = assignment ? drivers.find((d) => d.id === assignment.driverId) : undefined;
  const reviewer = reviewerAssignment ? reviewers.find((r) => r.id === reviewerAssignment.reviewerId) : undefined;
  const tour = matchTour(booking)?.tour;

  const subtitle = [
    leading === 'date' ? time : null,
    booking.customerName || 'Customer',
    `${guests} ${guests === 1 ? 'guest' : 'guests'}`,
  ]
    .filter(Boolean)
    .join(' · ');

  return (
    <Button onPress={() => router.push(`/booking/${encodeURIComponent(booking.referenceNumber)}`)}>
      <HStack spacing={12} modifiers={isCancelled ? [opacity(0.55)] : []}>
        {leading === 'date' ? (
          <VStack spacing={0} modifiers={[frame({ width: 38 })]}>
            <Text modifiers={[text.caption2, text.secondary]}>{date ? weekdayShort(date) : '—'}</Text>
            <Text modifiers={[text.title, text.digits, text.primary]}>{date ? String(date.getDate()) : '?'}</Text>
            <Text modifiers={[text.caption2, text.tertiary]}>{date ? monthShort(date) : ''}</Text>
          </VStack>
        ) : (
          <Text modifiers={[text.captionBold, text.digits, text.secondary, frame({ width: 58, alignment: 'leading' })]}>
            {time ?? 'Flexible'}
          </Text>
        )}

        <VStack alignment="leading" spacing={4}>
          <Text modifiers={[text.rowTitle, text.twoLines, text.primary]}>{booking.tourTitle}</Text>
          <Text modifiers={[text.footnote, text.oneLine, text.secondary]}>{subtitle}</Text>
          <HStack spacing={5}>
            {isCancelled ? (
              <Tag label="Cancelled" color={tone.negative} icon="xmark" />
            ) : isReview ? (
              <>
                <Tag label="Review" color={tone.review} icon="star.fill" />
                {reviewer ? (
                  <Tag label={reviewer.name.split(' ')[0]} color={reviewer.color || tone.positive} icon="person.fill" />
                ) : (
                  <Tag label="No reviewer" color={tone.warning} />
                )}
              </>
            ) : driver ? (
              <Tag label={driver.name.split(' ')[0]} color={driver.color || tone.info} icon="car.fill" />
            ) : (
              <Tag label="No driver" color={tone.warning} icon="car" />
            )}
            {booking.isLastMinute && !isCancelled ? <Tag label="Last minute" color={tone.negative} icon="flame.fill" /> : null}
            {booking.platform === 'airbnb' ? <Tag label="Airbnb" color={tone.airbnb} /> : null}
            {/* Lowest priority: the tour code gives up width before the driver and status tags do. */}
            {isCancelled ? null : (
              <HStack modifiers={[layoutPriority(-1)]}>
                {tour ? (
                  <Tag label={tour.referenceCode || 'Tour'} color="gray" icon="ticket" />
                ) : (
                  <Tag label="Unknown tour" color={tone.warning} icon="questionmark" />
                )}
              </HStack>
            )}
          </HStack>
        </VStack>

        <Spacer />

        <VStack alignment="trailing" spacing={2}>
          <Text
            modifiers={[
              text.rowTitle,
              text.digits,
              isReview || isCancelled ? text.secondary : text.primary,
              ...(isCancelled ? [strikethrough({ isActive: true, pattern: 'solid' })] : []),
            ]}>
            {formatEurWhole(getNumericPrice(booking))}
          </Text>
        </VStack>
        <Image systemName="chevron.right" size={12} color="#C7C7CC" />
      </HStack>
    </Button>
  );
}

