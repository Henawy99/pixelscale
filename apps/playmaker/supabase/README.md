# Supabase Database Setup

## Running the Schema

### Option 1: Supabase Dashboard (Recommended)

1. Go to your Supabase project dashboard: https://supabase.com/dashboard/project/upooyypqhftzzwjrfyra
2. Click on **SQL Editor** in the left sidebar
3. Click **New Query**
4. Copy the entire contents of `schema.sql`
5. Paste it into the editor
6. Click **Run** or press `Ctrl/Cmd + Enter`

### Option 2: Supabase CLI (Advanced)

```bash
# Install Supabase CLI if you haven't
npm install -g supabase

# Login
supabase login

# Link your project
supabase link --project-ref upooyypqhftzzwjrfyra

# Run the migration
supabase db push
```

## Verifying the Setup

After running the schema, verify that all tables were created:

1. Go to **Table Editor** in the Supabase dashboard
2. You should see these tables:
   - `player_profiles`
   - `football_fields`
   - `bookings`
   - `playmaker_squads`
   - `field_managers`

## Testing RLS Policies

The Row Level Security (RLS) policies are set to permissive for now to allow development. You can test them by:

1. Go to **Authentication** → **Policies**
2. Each table should have RLS enabled
3. You can test policies in the SQL Editor using:

```sql
-- Test as authenticated user
SELECT * FROM player_profiles WHERE id = 'test-user-id';
```

## Database Schema Overview

### player_profiles
- Stores user profile information
- Uses Firebase Auth UID as primary key
- Includes arrays for relationships (friends, bookings, teams)

### football_fields
- Stores field/venue information
- Includes location (lat/long) for maps
- Stores amenities as JSONB
- Has camera details for match recording

### bookings
- Match bookings and reservations
- Links to player_profiles and football_fields
- Supports recurring bookings
- Stores recording URLs (Firebase Storage paths)

### playmaker_squads
- Team/squad information
- Has captain and members arrays
- Includes join requests

### field_managers
- Manager accounts for field owners
- Links to football_fields they manage

## Important Notes

⚠️ **Authentication Integration**:
- We're using Firebase Auth for user authentication
- The Firebase UID is used as the primary key in `player_profiles`
- RLS policies reference this Firebase UID

⚠️ **Storage**:
- Profile pictures: Firebase Storage (URLs stored in database)
- Match recordings: Firebase Storage (URLs stored in `bookings.recording_url`)

⚠️ **Security**:
- All tables have RLS enabled
- Policies are currently permissive for development
- You can tighten them later based on your security requirements

## Next Steps

After running the schema:

1. ✅ Verify all tables are created
2. ✅ Check that RLS is enabled on all tables
3. ✅ Test inserting a sample player_profile
4. ✅ Ready to integrate with Flutter app!


