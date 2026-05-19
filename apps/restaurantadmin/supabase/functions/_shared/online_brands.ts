/** Ghost kitchen brands exposed on public ordering websites. */
export const ONLINE_BRANDS: Record<
  string,
  { id: string; name: string; tagline: string }
> = {
  'devils-smash-burger': {
    id: '4446a388-aaa7-402f-be4d-b82b23797415',
    name: 'DEVILS SMASH BURGER',
    tagline: 'Smash burgers, done right.',
  },
  tacotastic: {
    id: 'f5116077-8de3-488b-bf9d-75295f791dce',
    name: 'TACOTASTIC',
    tagline: 'French tacos & street food.',
  },
  'crispy-chicken-lab': {
    id: '8ec82a94-89f5-4603-bb35-c47c78d66d2a',
    name: 'CRISPY CHICKEN LAB',
    tagline: 'Crispy chicken, every time.',
  },
  'the-bowl-spot': {
    id: '59bf0f09-ab58-48a0-9b3f-13c7709c8600',
    name: 'THE BOWL SPOT',
    tagline: 'Fresh bowls, full flavor.',
  },
};

export function resolveBrandSlug(slug: string) {
  const key = slug.toLowerCase().trim();
  return ONLINE_BRANDS[key] ?? null;
}
