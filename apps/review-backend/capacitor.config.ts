import type { CapacitorConfig } from '@capacitor/cli';

// Production Cloud URL deployed on Vercel with live Zoho IMAP & Gemini AI
const SERVER_URL = process.env.CAPACITOR_SERVER_URL || 'https://review-app-seven-kappa.vercel.app';

const config: CapacitorConfig = {
  appId: 'com.pixelscale.reviewapp',
  appName: 'PixelReview',
  webDir: 'public',
  server: {
    url: SERVER_URL,
    androidScheme: 'https',
    iosScheme: 'https',
  },
  ios: {
    contentInset: 'automatic',
    allowsLinkPreview: false,
    scrollEnabled: false,
  },
};

export default config;
