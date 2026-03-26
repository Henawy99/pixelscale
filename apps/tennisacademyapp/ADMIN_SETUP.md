# Admin setup & login (Tennis Academy app only)

This setup is for the **Tennis Academy app** only. The PixelScale workspace shares one Supabase project; this script only touches data used by the Academy app:

- **auth.users** — one user record (shared project; used for login).
- **profiles** — the Tennis Academy app’s profile table (no prefix). Other apps use their own tables (e.g. `amazon_profiles`). This script does not modify any other app’s tables.

---

## 1. Create the admin user (one-time)

The Tennis Academy app has a default admin account. Create it in your Supabase project using the **service role key** (never use this in the app; only for this script).

1. **Get your service role key**
   - Open [Supabase Dashboard](https://supabase.com/dashboard) → your project
   - **Project Settings** → **API**
   - Copy the **service_role** key (under "Project API keys")

2. **Run the script in your terminal** (do **not** paste it into the Supabase SQL Editor — it is a Node.js script, not SQL). The script reads the service role key from the workspace file **`.env.pixelscale`** at the PixelScale root (same key used for all apps):

   ```bash
   cd apps/academy-app
   node scripts/create-admin-user.js
   ```

   If you haven’t set up `.env.pixelscale` yet, create it at the workspace root with one line:  
   `SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here`

   This creates:
   - **Email:** `albasset@tennis.com`
   - **Password:** `12345`
   - **Role:** admin (in the Academy app’s `profiles` table)
   - Email is **pre-confirmed**, so no verification email is required to log in.

   If the user already exists (e.g. you ran the script before), it will just ensure the profile has `role = 'admin'`.

   **If you get `profiles_level_check` error:** Your `profiles` table has a CHECK on `level` that may not allow the value the script uses. Run this in the **Supabase SQL Editor** once, then run the script again:

   ```sql
   -- Allow any value or NULL for level (admin doesn't need a tennis level)
   ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_level_check;
   ALTER TABLE profiles ALTER COLUMN level DROP NOT NULL;
   ```

## 2. Disable email verification for all users (optional)

So that **any** user (e.g. players who sign up) can log in without confirming their email:

1. Supabase Dashboard → **Authentication** → **Providers**
2. Open **Email**
3. Turn **off** “Confirm email”

Then new signups can log in immediately without clicking a confirmation link.

## 3. How to log in as admin

1. Open the Academy app (Expo / device / emulator).
2. On the first screen you’ll see the **login** form and “Explore” options.
3. Enter:
   - **Email:** `albasset@tennis.com`
   - **Password:** `12345`
4. Tap **Login**.

After login, the app redirects you to the **Admin** area (Schedules, Registrations, etc.) because your profile has `role = 'admin'`.

To log in as a **player** instead, use a different account (sign up from the app or create another user) or use **Explore as Player** for a demo (no real account).
