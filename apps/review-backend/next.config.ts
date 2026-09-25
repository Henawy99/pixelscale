import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "images.unsplash.com" },
      { protocol: "https", hostname: "images.pexels.com" },
      { protocol: "https", hostname: "cdn.getyourguide.com" },
      { protocol: "https", hostname: "upload.wikimedia.org" },
      { protocol: "https", hostname: "*.wikimedia.org" },
    ],
  },
  serverExternalPackages: ['imapflow', 'mailparser'],
  allowedDevOrigins: ['172.20.10.2', 'localhost', '127.0.0.1', '*'],
};

export default nextConfig;
