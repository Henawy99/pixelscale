# Foodora Live Order Relay (Windows POS Edition)

This lightweight relay runs directly on your restaurant POS PC (on your local Austrian Wi-Fi).

### Why this solves the issue permanently:
1. **Austrian Residential/Business IP**: Foodora's security (PerimeterX) sees your requests originating from a standard Austrian ISP (A1, Magenta, Drei, etc.) instead of a German cloud datacenter.
2. **Real Windows Hardware**: Has a real hardware GPU and display, eliminating bot threat score flags.
3. **Permanent Login**: Your login session is saved inside `foodora-profile` and stays authenticated indefinitely.
4. **Starts with Windows**: Automatically boots in the background when your POS PC turns on.

---

### Setup Instructions (Only 2 Minutes)

1. **Copy this folder** to your Windows POS PC (e.g. to `C:\FoodoraRelay` or your Desktop).
2. **Double-click `setup.bat`**:
   - Checks if Node.js is installed (installs it automatically if needed).
   - Installs the lightweight Puppeteer dependency.
3. **Double-click `start.bat`**:
   - Opens a Chrome/Edge window.
   - **Log in to Foodora Partner Portal once** if prompted.
   - Once logged in, your session is saved! You will see it begin polling orders.
4. **Double-click `add_to_startup.bat`**:
   - Automatically registers the relay into Windows Startup.
   - From now on, whenever your POS PC turns on in the morning, the relay starts silently in the background!

---

### Files
- `relay.mjs` - Main monitoring engine and Supabase order dispatcher.
- `setup.bat` - 1-click dependency installer.
- `start.bat` - Visible launcher with console logs for testing.
- `start_hidden.vbs` - Silent launcher without any black command prompt window.
- `add_to_startup.bat` - Adds `start_hidden.vbs` to Windows Startup folder.
