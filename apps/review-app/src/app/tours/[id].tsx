import { useMemo, useState } from 'react';
import { Pressable, ScrollView, Share } from 'react-native';
import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import { Image as ExpoImage } from 'expo-image';
import { Host } from '@expo/ui';
import {
  Button,
  ContentUnavailableView,
  DisclosureGroup,
  HStack,
  Image,
  Label,
  List,
  Picker,
  RNHostView,
  Section,
  Spacer,
  Text,
  VStack,
} from '@expo/ui/swift-ui';
import { foregroundStyle, frame, listStyle, pickerStyle, tag, textSelection } from '@expo/ui/swift-ui/modifiers';
import type { SFSymbol } from 'sf-symbols-typescript';
import { useAppData } from '@/state/app-data';
import { OfferedTour } from '@/types';
import { TourContent } from '@/lib/tourContent';
import {
  TimedStep,
  formatDuration,
  formatGroupSize,
  formatPrice,
  itineraryText,
  normalizeStartTime,
  timedItinerary,
  tourContentFor,
  transferLabel,
} from '@/lib/itinerary';
import { formatEur } from '@/lib/finance';
import { openUrl } from '@/lib/links';
import { Tag, ValueRow } from '@/components/primitives';
import { ACCENT, text, tone } from '@/components/theme';

export default function TourScreen() {
  // `sheet` is set when a booking opens the tour: it then stacks as a sheet over the booking, without a back button.
  const { id, start, sheet } = useLocalSearchParams<{ id: string; start?: string; sheet?: string }>();
  const router = useRouter();
  const { offeredTours } = useAppData();
  const tour = offeredTours.find((t) => t.id === id);

  return (
    <>
      {sheet ? (
        <Stack.Toolbar placement="left">
          <Stack.Toolbar.Button icon="xmark" onPress={() => router.back()} accessibilityLabel="Close" />
        </Stack.Toolbar>
      ) : null}
      {tour ? (
        <TourDetail tour={tour} start={start} />
      ) : (
        <Host style={{ flex: 1 }}>
          <ContentUnavailableView title="Tour Not Found" systemImage="questionmark.folder" description="It was removed from the catalog." />
        </Host>
      )}
    </>
  );
}

function TourDetail({ tour, start }: { tour: OfferedTour; start?: string }) {
  const router = useRouter();
  const { bookings, matchTour } = useAppData();
  const content = tourContentFor(tour);

  // A booking opens the plan at its own departure; otherwise the first daily departure.
  const bookedStart = normalizeStartTime(start);
  const [departure, setDeparture] = useState(bookedStart ?? content?.startTimes[0] ?? '09:00');
  const departures = useMemo(() => {
    const list = content?.startTimes ?? [];
    return bookedStart && !list.includes(bookedStart) ? [...list, bookedStart].sort() : list;
  }, [content, bookedStart]);

  const bookingCount = useMemo(
    () => bookings.filter((b) => b.status !== 'cancelled' && matchTour(b)?.tour.id === tour.id).length,
    [bookings, matchTour, tour.id]
  );

  const edit = () => router.push({ pathname: '/tour-form', params: { id: tour.id } });
  const share = () => content && Share.share({ message: itineraryText(tour, content, departure) });

  return (
    <>
      <Stack.Screen options={{ title: tour.referenceCode || 'Tour' }} />
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Menu icon="ellipsis" accessibilityLabel="More">
          {content ? (
            <Stack.Toolbar.MenuAction icon="square.and.arrow.up" onPress={share}>
              Share Itinerary
            </Stack.Toolbar.MenuAction>
          ) : null}
          <Stack.Toolbar.MenuAction icon="pencil" onPress={edit}>
            Edit Tour
          </Stack.Toolbar.MenuAction>
          {tour.gygUrl ? (
            <Stack.Toolbar.MenuAction icon="safari" onPress={() => openUrl(tour.gygUrl)}>
              Open on GetYourGuide
            </Stack.Toolbar.MenuAction>
          ) : null}
        </Stack.Toolbar.Menu>
      </Stack.Toolbar>

      <Host style={{ flex: 1 }} seedColor={ACCENT}>
        <List modifiers={[listStyle('insetGrouped')]}>
          {content && content.photos.length > 0 ? (
            <Section>
              <RNHostView matchContents>
                <ScrollView
                  horizontal
                  showsHorizontalScrollIndicator={false}
                  contentContainerStyle={{ gap: 10, paddingHorizontal: 16 }}
                  style={{ height: 150, marginHorizontal: -16 }}>
                  {content.photos.map((uri) => (
                    <Pressable key={uri} onPress={() => router.push({ pathname: '/photo', params: { uri } })}>
                      <ExpoImage source={{ uri }} style={{ width: 218, height: 150, borderRadius: 12 }} contentFit="cover" transition={200} />
                    </Pressable>
                  ))}
                </ScrollView>
              </RNHostView>
            </Section>
          ) : null}

          <Section>
            <VStack alignment="leading" spacing={8}>
              <Text modifiers={[text.headline]}>{tour.title}</Text>
              {content ? <Text modifiers={[text.subheadline, text.secondary]}>{content.summary}</Text> : null}
              <HStack spacing={6}>
                <Tag label="Private" color={tone.info} icon="lock.fill" />
                {content ? <Tag label={formatDuration(content.durationMinutes)} color={tone.positive} icon="clock" /> : null}
                <Tag label={`${bookingCount} ${bookingCount === 1 ? 'booking' : 'bookings'}`} color="gray" />
              </HStack>
            </VStack>
          </Section>

          {content ? <Overview content={content} /> : <NoContent tour={tour} onEdit={edit} />}

          {content ? (
            <Section
              title="Itinerary"
              footer={
                <Text>
                  {content.itineraryApproximate
                    ? 'GetYourGuide has no itinerary for this tour yet, so these times are estimated from its description.'
                    : 'Times follow the GetYourGuide itinerary and move with traffic, weather and queues.'}
                </Text>
              }>
              {departures.length > 1 ? (
                <Picker selection={departure} onSelectionChange={(v) => setDeparture(String(v))} modifiers={[pickerStyle('segmented')]}>
                  {departures.map((t) => (
                    <Text key={t} modifiers={[tag(t)]}>
                      {t}
                    </Text>
                  ))}
                </Picker>
              ) : null}
              {timedItinerary(content.itinerary, departure).map((step, i) => (
                <StepRow key={i} step={step} />
              ))}
            </Section>
          ) : null}

          {content ? <Details content={content} /> : null}

          <Section title="Tickets Bought per Guest">
            {(tour.tickets ?? []).length === 0 ? (
              <Text modifiers={[text.footnote, text.secondary]}>No tickets included</Text>
            ) : (
              (tour.tickets ?? []).map((t) => (
                <ValueRow
                  key={t.id}
                  icon="ticket"
                  iconColor={t.pricePerPassenger > 0 ? undefined : tone.warning}
                  title={t.name}
                  value={t.pricePerPassenger > 0 ? formatEur(t.pricePerPassenger) : 'No price'}
                  valueColor={t.pricePerPassenger > 0 ? undefined : tone.warning}
                />
              ))
            )}
            <Button onPress={edit}>
              <Label title="Edit Tour & Tickets" systemImage="pencil" />
            </Button>
          </Section>

          <Section title="Listings">
            {tour.gygTourId ? <ValueRow icon="number" title="GetYourGuide ID" value={tour.gygTourId} /> : null}
            {content?.viatorProductCode ? (
              <ValueRow icon="checkmark.seal" title="Viator product" value={content.viatorProductCode} valueColor={tone.positive} />
            ) : (
              <ValueRow icon="xmark.seal" title="Viator" value="Not listed" />
            )}
            {tour.gygUrl ? (
              <Button onPress={() => openUrl(tour.gygUrl)}>
                <Label title="Open on GetYourGuide" systemImage="safari" />
              </Button>
            ) : null}
          </Section>
        </List>
      </Host>
    </>
  );
}

function Overview({ content }: { content: TourContent }) {
  const { price } = content;
  return (
    <Section title="At a Glance">
      <ValueRow icon="clock" title="Duration" value={formatDuration(content.durationMinutes)} />
      <ValueRow icon="calendar" title="Departs daily" value={content.startTimes.join(' · ')} />
      {content.season ? <ValueRow icon="calendar.badge.exclamationmark" title="Season" value={content.season.replace(/^Bookable /, '')} /> : null}
      <ValueRow icon="eurosign.circle" title="Price" value={formatPrice(price)} />
      {price.child !== undefined ? <ValueRow icon="figure.and.child.holdinghands" title="Child" value={formatEur(price.child)} /> : null}
      <ValueRow icon="person.2" title="Group size" value={formatGroupSize(price)} />
      <ValueRow
        icon="steeringwheel"
        title={content.guide}
        value={content.languages.length > 0 ? content.languages.join(', ') : '—'}
      />
      <ValueRow icon="hourglass" title="Booking cut-off" value={`${content.cutoffHours} h before`} />
      <ValueRow icon="arrow.uturn.backward.circle" title="Free cancellation" value="24 h before" />
    </Section>
  );
}

function StepRow({ step }: { step: TimedStep }) {
  if (step.type === 'transfer') {
    return (
      <HStack spacing={10}>
        <Spacer modifiers={[frame({ width: 44 })]} />
        <Image systemName={step.mode === 'cable car' ? 'cablecar.fill' : 'car.fill'} size={11} color="gray" modifiers={[frame({ width: 22 })]} />
        <Text modifiers={[text.caption, text.secondary]}>{transferLabel(step)}</Text>
        <Spacer />
      </HStack>
    );
  }

  const time = (
    <Text modifiers={[text.subheadline, text.digits, text.secondary, frame({ width: 44, alignment: 'leading' })]}>{step.at}</Text>
  );

  if (step.type === 'pickup' || step.type === 'dropoff') {
    const pickup = step.type === 'pickup';
    return (
      <HStack spacing={10} alignment="top">
        {time}
        <Image systemName={pickup ? 'figure.wave' : 'flag.checkered'} size={15} color="gray" modifiers={[frame({ width: 22 })]} />
        <VStack alignment="leading" spacing={3}>
          <Text modifiers={[text.rowTitle, text.primary]}>{pickup ? 'Pickup' : 'Drop-off'}</Text>
          <Text modifiers={[text.footnote, text.secondary]}>{step.place}</Text>
        </VStack>
        <Spacer />
      </HStack>
    );
  }

  return (
    <HStack spacing={10} alignment="top">
      {time}
      <Image systemName="mappin.circle.fill" size={15} color={ACCENT} modifiers={[frame({ width: 22 })]} />
      <VStack alignment="leading" spacing={3}>
        <Text modifiers={[text.rowTitle, text.primary]}>{step.place}</Text>
        <Text modifiers={[text.footnote, text.secondary]}>{[formatDuration(step.minutes), ...step.activities].join(' · ')}</Text>
        {step.included ? (
          <HStack spacing={5}>
            <Image systemName="ticket.fill" size={11} color={tone.positive} />
            <Text modifiers={[text.footnote, foregroundStyle(tone.positive)]}>{`Included: ${step.included}`}</Text>
          </HStack>
        ) : null}
        {step.note ? <Text modifiers={[text.footnote, text.tertiary]}>{step.note}</Text> : null}
      </VStack>
      <Spacer />
    </HStack>
  );
}

function Bullets({ items, icon, color }: { items: string[]; icon: SFSymbol; color: string }) {
  return (
    <>
      {items.map((item) => (
        <HStack key={item} spacing={10} alignment="top">
          <Image systemName={icon} size={13} color={color} modifiers={[frame({ width: 20 })]} />
          <Text modifiers={[text.subheadline, text.primary]}>{item}</Text>
          <Spacer />
        </HStack>
      ))}
    </>
  );
}

function Details({ content }: { content: TourContent }) {
  const [descriptionOpen, setDescriptionOpen] = useState(false);
  return (
    <>
      <Section title="Highlights">
        <Bullets items={content.highlights} icon="sparkles" color={tone.warning} />
      </Section>

      <Section title="Included">
        <Bullets items={content.included} icon="checkmark" color={tone.positive} />
      </Section>

      <Section title="Not Included">
        <Bullets items={content.excluded} icon="xmark" color={tone.negative} />
      </Section>

      <Section title="Good to Know">
        {content.pickupInfo ? (
          <Label systemImage="mappin.and.ellipse">
            <Text modifiers={[text.subheadline, text.primary]}>{content.pickupInfo}</Text>
          </Label>
        ) : null}
        {content.bring.length > 0 ? (
          <Label systemImage="bag">
            <Text modifiers={[text.subheadline, text.primary]}>{`Bring: ${content.bring.join(', ')}`}</Text>
          </Label>
        ) : null}
        {content.notSuitableFor.length > 0 ? (
          <Label systemImage="exclamationmark.triangle">
            <Text modifiers={[text.subheadline, text.primary]}>{`Not suitable for: ${content.notSuitableFor.join(', ')}`}</Text>
          </Label>
        ) : null}
        {content.knowBeforeYouGo.map((note) => (
          <Label key={note} systemImage="info.circle">
            <Text modifiers={[text.subheadline, text.primary]}>{note}</Text>
          </Label>
        ))}
      </Section>

      <Section>
        <DisclosureGroup label="Full Description" isExpanded={descriptionOpen} onIsExpandedChange={setDescriptionOpen}>
          <Text modifiers={[text.subheadline, text.primary, textSelection(true)]}>{content.description}</Text>
        </DisclosureGroup>
      </Section>
    </>
  );
}

function NoContent({ tour, onEdit }: { tour: OfferedTour; onEdit: () => void }) {
  return (
    <Section footer={<Text>Details and itineraries come with the GetYourGuide products. This tour was added by hand.</Text>}>
      {tour.notes ? <Text modifiers={[text.subheadline, text.primary]}>{tour.notes}</Text> : null}
      <Button onPress={onEdit}>
        <Label title="Edit Tour" systemImage="pencil" />
      </Button>
    </Section>
  );
}
