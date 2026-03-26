# SD / camera storage replay – setup on the Pi (Tailscale SSH)

Use this when your **camera records 6–12 (or any window) to an SD card or storage** that the Pi can read, and you want to "replay" that footage through the pipeline from the Admin app.

---

## 1. SSH into the Pi via Tailscale

From your Mac/PC (with Tailscale running):

```bash
# Option A: use the Pi’s Tailscale hostname (e.g. raspberrypi, or the name you gave it)
ssh pi@raspberrypi

# Option B: use the Pi’s Tailscale IP (find it in the Tailscale admin or with: tailscale status)
ssh pi@100.x.x.x
```

Replace `pi` with your username if different. Enter the Pi’s password when prompted.

---

## 2. Find where the script runs and where your env is

The script reads variables from a **`.env`** file in the directory it’s run from (or from the environment).

```bash
# Go to where you run the camera script (common: home or a project folder)
cd ~
# or, if you run it from a specific folder, e.g.:
# cd ~/playmaker-camera

# List .env if it exists
ls -la .env
```

If you run the script with **systemd**, the service file might set the working directory and environment. Check:

```bash
sudo systemctl status camera-recorder
# or whatever your service is called; then:
sudo systemctl cat camera-recorder
```

You need to add `SD_FOOTAGE_BASE_DIR` in **the same place** you set `FIELD_ID`, `RECORDING_DIR`, etc. (either in `.env` or in the systemd unit, or in a shell script that starts the recorder).

---

## 3. Decide the footage path

The Pi must see the camera’s recordings as **files in a directory**. Examples:

- **Camera’s SD card mounted on the Pi**  
  e.g. `/media/pi/CAMERA_SD/` or `/mnt/camera_sd/`

- **Camera writes to a network share the Pi mounts**  
  e.g. `/mnt/nas/camera_recordings/`

- **Camera FTP/SFTP to the Pi**  
  e.g. `/home/pi/camera_uploads/`

**Find where the 6–12 files actually are:**

```bash
# If you already know the mount point:
ls /media/pi/
ls /mnt/

# Or search for recent .mp4 files (today or yesterday)
find /media /mnt /home/pi -name "*.mp4" -mtime -2 2>/dev/null | head -20
```

Pick the **directory that contains the daily recordings** (either one folder per date, or one folder with all files). That will be your `SD_FOOTAGE_BASE_DIR`.

**Expected layout:**

- **Option A (by date):**  
  `SD_FOOTAGE_BASE_DIR/2026-02-15/video1.mp4`  
  So the path you set is the **parent** of the `YYYY-MM-DD` folders.

- **Option B (flat):**  
  All files in `SD_FOOTAGE_BASE_DIR/`; the script will filter by file **modification time** to match the requested time window.

---

## 4. Set SD_FOOTAGE_BASE_DIR

**If you use a `.env` file** (same folder as the script or where you start it):

```bash
nano .env
```

Add a line (use **your** path):

```
SD_FOOTAGE_BASE_DIR=/media/pi/CAMERA_SD/recordings
```

Save: `Ctrl+O`, Enter, then `Ctrl+X`.

**If you use systemd:** edit the service and add the variable:

```bash
sudo nano /etc/systemd/system/camera-recorder.service
```

In the `[Service]` section add (adjust path):

```
Environment="SD_FOOTAGE_BASE_DIR=/media/pi/CAMERA_SD/recordings"
```

Save, then:

```bash
sudo systemctl daemon-reload
```

---

## 5. Restart the camera script

So it reloads the new variable:

**If you run it manually:**

```bash
# Stop the current process (Ctrl+C if in foreground, or kill the process)
# Then start it again from the same directory where .env is
python3 scheduled_camera_recorder.py
```

**If you use systemd:**

```bash
sudo systemctl restart camera-recorder
```

---

## 6. Check it’s set (optional)

```bash
# If using .env, from the same directory:
grep SD_FOOTAGE_BASE_DIR .env

# Quick test that the path exists and has files (use YOUR path)
ls -la /media/pi/CAMERA_SD/recordings/
# or for a date folder:
ls -la /media/pi/CAMERA_SD/recordings/2026-02-15/
```

---

## 7. Use it from the Admin app

1. Open **Camera Monitoring**.
2. Pick the camera/field.
3. Tap **Record** (schedule recording).
4. Choose a **past date** (e.g. 10 Feb) and **time range** (e.g. 7:00–9:00).
5. Turn **on** “Use footage from camera/SD storage”.
6. Create the schedule.

The job will show as **SD REPLAY**. The Pi will pick it up on the next poll (within a few seconds if it’s idle), find the files for that date/time, upload them, and run the ball-tracking pipeline.

---

## Troubleshooting

| Problem | What to check |
|--------|----------------|
| Job stays “SD REPLAY” and nothing happens | Pi: `SD_FOOTAGE_BASE_DIR` set? Path exists? Script restarted? Check Pi logs. |
| “No footage found on storage” | Path correct? Date folder `YYYY-MM-DD` exists? Files have mtime in the requested window? |
| Permission denied | `ls -la` the path; ensure the user that runs the script can read the directory and files. |

If you’re not sure where the camera saves, check the camera’s web UI or manual for “storage path”, “FTP path”, or “NAS path”.
