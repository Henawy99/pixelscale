# Academy App — Padel & Football Training

A React Native (Expo) mobile application for managing a Padel and Football training academy. Built with Supabase for backend, featuring role-based access for players, parents, coaches, and admins.

## Features

### Players
- Browse Football and Padel academies
- View training schedule in calendar format
- Book sessions (with admin approval)
- Apply discount codes
- View notifications
- Manage profile & subscriptions

### Coaches
- View today's sessions
- See enrolled player list
- Mark attendance (present/absent)

### Admin
- Dashboard with key stats (players, bookings, revenue)
- Create/block/cancel training sessions
- Approve or reject bookings
- Confirm payments (cash or external)
- Manage discount codes
- Send announcements to all players
- Manage player levels

### General
- Arabic + English (i18n with RTL support)
- Dark mode
- Push notifications
- Supabase Auth (email/password)

## Tech Stack

- **Framework:** Expo SDK 54 + Expo Router
- **Backend:** Supabase (Auth, Postgres, Realtime)
- **UI:** React Native Paper (Material Design 3)
- **Calendar:** react-native-calendars
- **i18n:** i18next + react-i18next
- **Notifications:** expo-notifications

## Getting Started

### Prerequisites
- Node.js 18+
- Expo CLI (`npm install -g expo-cli`)
- Supabase project

### Installation

```bash
cd academy-app
npm install
```

### Database Setup

1. Go to your Supabase project SQL Editor
2. Run the contents of `supabase/schema.sql` to create all tables, RLS policies, and seed data

### Admin user & login

- **Create the default admin** (one-time): see [ADMIN_SETUP.md](./ADMIN_SETUP.md). You need the Supabase **service_role** key; then run `SUPABASE_SERVICE_ROLE_KEY=... node scripts/create-admin-user.js`.
- **Log in as admin:** open the app → Login → email `albasset@tennis.com`, password `12345`. The app will redirect to the Admin area.
- **No email verification:** the script creates the admin with email pre-confirmed. To allow all new signups to log in without verifying email, turn off "Confirm email" in Supabase → Authentication → Providers → Email.

### Running the App

```bash
npx expo start
```

Scan the QR code with Expo Go on your phone, or press `i` for iOS simulator / `a` for Android emulator.

## Project Structure

```
academy-app/
├── app/                  # Expo Router screens
│   ├── (auth)/           # Login, Signup
│   ├── (player)/         # Player tab screens
│   ├── (coach)/          # Coach tab screens
│   └── (admin)/          # Admin tab screens
├── components/           # Shared UI components
├── contexts/             # React contexts (Auth, Theme, Locale)
├── hooks/                # Custom hooks for Supabase data
├── lib/                  # Supabase client, i18n, theme
├── types/                # TypeScript interfaces
└── supabase/             # Database schema SQL
```

## User Roles

| Role | Access |
|------|--------|
| Player | Home, Schedule, Booking, Profile |
| Parent | Same as Player + manage child accounts |
| Coach | Sessions, Attendance, Player List |
| Admin | Full dashboard, all management features |
