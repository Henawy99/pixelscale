import { useEffect, useMemo, useState } from 'react';
import { Share } from 'react-native';
import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import { Image as ExpoImage } from 'expo-image';
import * as Clipboard from 'expo-clipboard';
import * as Haptics from 'expo-haptics';
import { Host } from '@expo/ui';
import {
  Button,
  ContentUnavailableView,
  Form,
  HStack,
  Label,
  Picker,
  RNHostView,
  Section,
  Text,
  TextField,
  VStack,
} from '@expo/ui/swift-ui';
import { foregroundStyle, keyboardType, lineLimit, scrollDismissesKeyboard, tag } from '@expo/ui/swift-ui/modifiers';
import { useAppData, useBooking } from '@/state/app-data';
import { BookingItem, getNumericPrice, isBookingReview } from '@/types';
import { calculateDriverTourPayout } from '@/lib/driverStorage';
import { getBookingTicketDeduction, reviewNotesFor } from '@/lib/tours';
import { NO_TOUR } from '@/lib/toursStorage';
import { formatWhatsAppReviewMessage, shareToWhatsApp } from '@/lib/reviewerStorage';
import { formatEur, platformFeeRate, platformName } from '@/lib/finance';
import { callPhone, openPickup, openUrl } from '@/lib/links';
import { bookingTime, formatRelative } from '@/lib/dates';
import { Tag, ValueRow } from '@/components/primitives';
import { ACCENT, text, tone } from '@/components/theme';
import { parseAmount, useField } from '@/components/use-field';

export default function BookingScreen() {
  const { ref } = useLocalSearchParams<{ ref: string }>();
  const booking = useBooking(ref);
  const router = useRouter();

  if (!booking) {
    return (
      <>
        <Stack.Toolbar placement="left">
          <Stack.Toolbar.Button icon="xmark" onPress={() => router.back()} accessibilityLabel="Close" />
        </Stack.Toolbar>
        <Host style={{ flex: 1 }}>
          <ContentUnavailableView
            title="Booking Not Found"
            systemImage="questionmark.folder"
            description="It is no longer in the synced inbox."
          />
        </Host>
      </>
    );
  }
  return <BookingDetail booking={booking} />;
}

function BookingDetail({ booking }: { booking: BookingItem }) {
  const router = useRouter();
  const {
    drivers,
    assignments,
    offeredTours,
    matchTour,
    tourLinks,
    linkBookingToTour,
    reviewers,
    reviewerAssignments,
    assignDriver,
    unassignDriver,
    assignReviewer,
    unassignReviewer,
  } = useAppData();

  const ref = booking.referenceNumber;
  const isCancelled = booking.status === 'cancelled';
  const isReview = isBookingReview(booking);
  const assignment = assignments[ref];
  const driver = assignment ? drivers.find((d) => d.id === assignment.driverId) : undefined;
  const reviewerAssignment = reviewerAssignments[ref];
  const reviewer = reviewerAssignment ? reviewers.find((r) => r.id === reviewerAssignment.reviewerId) : undefined;
  const attachedReview = reviewerAssignment?.reviewText || reviewerAssignment?.generatedReviewText;

  const gross = getNumericPrice(booking);
  const feeRate = platformFeeRate(booking);
  const tourMatch = matchTour(booking);
  const tour = tourMatch?.tour;
  const tickets = useMemo(() => getBookingTicketDeduction(booking, matchTour), [booking, matchTour]);
  const driverPayout = driver ? calculateDriverTourPayout(booking, driver, assignment?.customPayoutAmount) : 0;

  const payoutField = useField(assignment?.customPayoutAmount ? String(assignment.customPayoutAmount) : '');
  const [copied, setCopied] = useState(false);

  const customPayout = () => {
    const n = parseAmount(payoutField.current());
    return !isNaN(n) && n > 0 ? n : undefined;
  };

  const onDriverChange = async (id: string) => {
    Haptics.selectionAsync();
    if (id === 'none') await unassignDriver(ref);
    else await assignDriver(ref, id, customPayout());
  };

  // Save the custom payout shortly after typing stops — decimal pads have no Return key.
  useEffect(() => {
    if (!driver) return;
    const timer = setTimeout(() => {
      const next = customPayout();
      if (next !== assignment?.customPayoutAmount) assignDriver(ref, driver.id, next);
    }, 500);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [payoutField.value]);

  const onReviewerChange = async (id: string) => {
    Haptics.selectionAsync();
    if (id === 'none') await unassignReviewer(ref);
    else await assignReviewer(ref, id);
  };

  const copyReference = async () => {
    await Clipboard.setStringAsync(ref);
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  const shareDetails = () =>
    Share.share({
      message: [
        booking.tourTitle,
        booking.date,
        `${booking.customerName || 'Customer'} · ${booking.participants}`,
        booking.pickup ? `Pickup: ${booking.pickup}` : null,
        booking.customerPhone ? `Phone: ${booking.customerPhone}` : null,
        `Ref: ${ref}`,
      ]
        .filter(Boolean)
        .join('\n'),
    });

  // With a recognised tour the studio already knows the GetYourGuide link, so it starts writing right away.
  const openStudio = () =>
    router.push({
      pathname: '/studio',
      params: {
        url: tour?.gygUrl ?? '',
        notes: tour
          ? reviewNotesFor(tour, `Date: ${booking.date}`)
          : `Tour: ${booking.tourTitle}\nDate: ${booking.date}`,
        bookingRef: ref,
        autostart: tour ? '1' : undefined,
      },
    });

  const onTourChange = async (id: string) => {
    Haptics.selectionAsync();
    await linkBookingToTour(ref, id === 'auto' ? null : id);
  };

  const sendWhatsApp = async () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    const message = formatWhatsAppReviewMessage(booking, reviewer?.name || 'Reviewer', attachedReview, reviewerAssignment?.photoUrls);
    await shareToWhatsApp(reviewer?.whatsappPhone || reviewer?.phone, message);
  };

  const net = tickets.netGygPayout;
  const profit = tickets.netProfitAfterTickets;
  const tourFooter = tourMatch
    ? {
        manual: 'Chosen by hand for this booking.',
        reference: 'Recognised by the product reference code.',
        title: 'Recognised by the tour title.',
        similar: 'Recognised by a similar title. Change it if it’s wrong.',
      }[tourMatch.via]
    : 'Pick the tour so its tickets are deducted and reviews use the right GetYourGuide page.';

  return (
    <>
      <Stack.Screen options={{ title: ref }} />
      <Stack.Toolbar placement="left">
        <Stack.Toolbar.Button icon="xmark" onPress={() => router.back()} accessibilityLabel="Close" />
      </Stack.Toolbar>
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Menu icon="ellipsis" accessibilityLabel="More">
          <Stack.Toolbar.MenuAction icon="doc.on.doc" onPress={copyReference}>
            Copy Reference
          </Stack.Toolbar.MenuAction>
          <Stack.Toolbar.MenuAction icon="square.and.arrow.up" onPress={shareDetails}>
            Share Details
          </Stack.Toolbar.MenuAction>
          {booking.bookingUrl ? (
            <Stack.Toolbar.MenuAction icon="safari" onPress={() => openUrl(booking.bookingUrl!)}>
              {`Open in ${platformName(booking)}`}
            </Stack.Toolbar.MenuAction>
          ) : null}
        </Stack.Toolbar.Menu>
      </Stack.Toolbar>

      <Host style={{ flex: 1 }} seedColor={ACCENT}>
        <Form modifiers={[scrollDismissesKeyboard('interactively')]}>
          {/* Tour */}
          <Section>
            <HStack spacing={14} alignment="top">
              {booking.imageUrl ? (
                <RNHostView matchContents>
                  <ExpoImage
                    source={{ uri: booking.imageUrl }}
                    style={{ width: 64, height: 64, borderRadius: 12 }}
                    contentFit="cover"
                    transition={200}
                  />
                </RNHostView>
              ) : null}
              <VStack alignment="leading" spacing={8}>
                <Text modifiers={[text.headline]}>{booking.tourTitle}</Text>
                {booking.fareOption ? (
                  <Text modifiers={[text.footnote, text.secondary]}>{booking.fareOption}</Text>
                ) : null}
                <HStack spacing={6}>
                  <Tag label={platformName(booking)} color={booking.platform === 'airbnb' ? tone.airbnb : tone.gyg} />
                  {isCancelled ? <Tag label="Cancelled" color={tone.negative} icon="xmark" /> : null}
                  {!isCancelled && isReview ? <Tag label="Review" color={tone.review} icon="star.fill" /> : null}
                  {!isCancelled && booking.isLastMinute ? (
                    <Tag label="Last minute" color={tone.negative} icon="flame.fill" />
                  ) : null}
                  {!isCancelled && !booking.isLastMinute && booking.status === 'confirmed' ? (
                    <Tag label="Confirmed" color={tone.positive} icon="checkmark" />
                  ) : null}
                </HStack>
              </VStack>
            </HStack>
          </Section>

          {isCancelled ? (
            <Section>
              <Label title="Cancelled — excluded from revenue and payouts" systemImage="xmark.octagon.fill" modifiers={[foregroundStyle('red')]} />
            </Section>
          ) : null}

          {/* Which GetYourGuide product this is, and the tickets it includes */}
          <Section title="Tour" footer={<Text>{tourFooter}</Text>}>
            {tour ? (
              <>
                <ValueRow icon="barcode" title="Reference code" value={tour.referenceCode || '—'} />
                {tourMatch?.via !== 'title' ? (
                  <Text modifiers={[text.footnote, text.secondary]}>{tour.title}</Text>
                ) : null}
                {(tour.tickets ?? []).length === 0 ? (
                  <ValueRow icon="ticket" title="Tickets" value="None included" />
                ) : (
                  (tour.tickets ?? []).map((t) => (
                    <ValueRow
                      key={t.id}
                      icon="ticket"
                      iconColor={t.pricePerPassenger > 0 ? undefined : tone.warning}
                      title={t.name}
                      value={t.pricePerPassenger > 0 ? `${formatEur(t.pricePerPassenger)} / guest` : 'No price'}
                      valueColor={t.pricePerPassenger > 0 ? undefined : tone.warning}
                    />
                  ))
                )}
                <Button
                  onPress={() =>
                    router.push({
                      pathname: '/tours/[id]',
                      params: { id: tour.id, start: bookingTime(booking) ?? undefined, sheet: '1' },
                    })
                  }>
                  <Label title="Itinerary & Tour Details" systemImage="map" />
                </Button>
                <Button onPress={() => openUrl(tour.gygUrl)}>
                  <Label title="Open on GetYourGuide" systemImage="safari" />
                </Button>
              </>
            ) : (
              <Label title="Tour not recognised" systemImage="questionmark.circle" modifiers={[foregroundStyle(tone.warning)]} />
            )}
            <Picker
              label={tour ? 'Change tour' : 'Choose tour'}
              systemImage="arrow.triangle.swap"
              selection={tourLinks[ref] ?? 'auto'}
              onSelectionChange={(v) => onTourChange(String(v))}>
              <Text modifiers={[tag('auto')]}>Automatic</Text>
              <Text modifiers={[tag(NO_TOUR)]}>None of my tours</Text>
              {offeredTours.map((t) => (
                <Text key={t.id} modifiers={[tag(t.id)]}>
                  {t.referenceCode ? `${t.referenceCode} · ${t.title}` : t.title}
                </Text>
              ))}
            </Picker>
          </Section>

          {/* Who & when */}
          <Section title="Details">
            <ValueRow icon="calendar" title="Date" value={booking.date || '—'} />
            <ValueRow icon="person.2" title="Guests" value={booking.participants || '—'} />
            <ValueRow icon="person" title="Customer" value={booking.customerName || '—'} />
            {booking.tourLanguage ? <ValueRow icon="globe" title="Language" value={booking.tourLanguage} /> : null}
            <ValueRow icon="number" title="Reference" value={copied ? 'Copied' : ref} onPress={copyReference} />
            {booking.receivedAt ? <ValueRow icon="tray.and.arrow.down" title="Received" value={formatRelative(booking.receivedAt)} /> : null}
          </Section>

          {/* Contact & pickup */}
          {booking.customerPhone || booking.pickup ? (
            <Section title="Contact">
              {booking.customerPhone ? (
                <Button onPress={() => callPhone(booking.customerPhone)}>
                  <Label title={`Call ${booking.customerPhone}`} systemImage="phone.fill" />
                </Button>
              ) : null}
              {booking.pickup ? (
                <Button onPress={() => openPickup(booking)}>
                  <Label systemImage="mappin.and.ellipse">
                    <VStack alignment="leading" spacing={2}>
                      <Text>Pickup</Text>
                      <Text modifiers={[text.footnote, text.secondary, lineLimit(2)]}>{booking.pickup}</Text>
                    </VStack>
                  </Label>
                </Button>
              ) : null}
            </Section>
          ) : null}

          {/* Money */}
          {!isCancelled ? (
            <Section
              title="Payout"
              footer={
                isReview ? (
                  <Text>Review booking: no tickets are bought.</Text>
                ) : tickets.missingPrices > 0 ? (
                  <Text>{`${tickets.missingPrices} included ${tickets.missingPrices === 1 ? 'ticket has' : 'tickets have'} no price yet, so this profit is too high.`}</Text>
                ) : undefined
              }>
              <ValueRow title="Gross price" value={formatEur(gross)} />
              <ValueRow title={`${platformName(booking)} fee (${Math.round(feeRate * 100)}%)`} value={`− ${formatEur(gross - net)}`} />
              {tickets.lines.map((line) => (
                <ValueRow
                  key={line.name}
                  title={`${line.name} (${tickets.passengerCount} × ${formatEur(line.pricePerPassenger)})`}
                  value={`− ${formatEur(line.subtotal)}`}
                />
              ))}
              {!isReview && tickets.missingPrices > 0 ? (
                <Button onPress={() => router.push('/tours')}>
                  <Label title="Set Ticket Prices" systemImage="ticket" />
                </Button>
              ) : null}
              <ValueRow
                title={tickets.hasDeduction ? 'Net profit' : 'Net payout'}
                value={formatEur(tickets.hasDeduction ? profit : net)}
                valueColor={tone.positive}
                bold
              />
            </Section>
          ) : null}

          {/* Driver — real tours only */}
          {!isReview && !isCancelled ? (
            <Section
              title="Driver"
              footer={
                drivers.length === 0 ? (
                  <Text>Add drivers in the Team tab first.</Text>
                ) : driver ? (
                  <Text>Leave the custom payout empty to use the driver’s default rate.</Text>
                ) : undefined
              }>
              <Picker
                label="Driver"
                systemImage="car.fill"
                selection={driver?.id ?? 'none'}
                onSelectionChange={(v) => onDriverChange(String(v))}>
                <Text modifiers={[tag('none')]}>Not assigned</Text>
                {drivers.map((d) => (
                  <Text key={d.id} modifiers={[tag(d.id)]}>
                    {`${d.name} · ${formatEur(d.id === driver?.id ? driverPayout : calculateDriverTourPayout(booking, d))}`}
                  </Text>
                ))}
              </Picker>
              {driver ? (
                <>
                  <ValueRow title="Driver payout" value={formatEur(driverPayout)} bold />
                  <HStack spacing={10}>
                    <Text>Custom payout €</Text>
                    <TextField
                      text={payoutField.state}
                      onTextChange={payoutField.onTextChange}
                      placeholder="Default rate"
                      modifiers={[keyboardType('decimal-pad')]}
                    />
                  </HStack>
                </>
              ) : null}
            </Section>
          ) : null}

          {/* Review workflow — review bookings only */}
          {isReview && !isCancelled ? (
            <>
              <Section
                title="Reviewer"
                footer={reviewers.length === 0 ? <Text>Add review people in the Team tab first.</Text> : undefined}>
                <Picker
                  label="Reviewer"
                  systemImage="person.crop.circle.badge.checkmark"
                  selection={reviewer?.id ?? 'none'}
                  onSelectionChange={(v) => onReviewerChange(String(v))}>
                  <Text modifiers={[tag('none')]}>Not attached</Text>
                  {reviewers.map((r) => (
                    <Text key={r.id} modifiers={[tag(r.id)]}>
                      {r.name}
                    </Text>
                  ))}
                </Picker>
              </Section>

              <Section
                title="Review"
                footer={
                  !tour ? (
                    <Text>Choose the tour above and reviews are written from its GetYourGuide page automatically.</Text>
                  ) : reviewerAssignment?.photoUrls?.length ? (
                    <Text>{`${reviewerAssignment.photoUrls.length} photo links will be sent with the review.`}</Text>
                  ) : undefined
                }>
                {attachedReview ? (
                  <Text modifiers={[text.subheadline, lineLimit(6)]}>{`“${attachedReview}”`}</Text>
                ) : (
                  <Text modifiers={[text.secondary]}>No review attached yet.</Text>
                )}
                <Button
                  label={attachedReview ? 'Regenerate Review' : 'Generate Review & Photos'}
                  systemImage="sparkles"
                  onPress={openStudio}
                />
                <Button
                  label={reviewer ? `Send to ${reviewer.name} on WhatsApp` : 'Share via WhatsApp'}
                  systemImage="paperplane.fill"
                  onPress={sendWhatsApp}
                  modifiers={[foregroundStyle('green')]}
                />
              </Section>
            </>
          ) : null}

          {booking.bookingUrl ? (
            <Section>
              <Button onPress={() => openUrl(booking.bookingUrl!)}>
                <Label title={`Open in ${platformName(booking)}`} systemImage="arrow.up.right.square" />
              </Button>
            </Section>
          ) : null}
        </Form>
      </Host>
    </>
  );
}
