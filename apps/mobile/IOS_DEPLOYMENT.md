# Deploying to Physical iPhone

To run the app on your real iPhone:

1.  **Connect via USB**: Plug your iPhone into your Mac.
2.  **Unlock & Trust**: Unlock your iPhone. If asked, tap "Trust This Computer" and enter your passcode.
3.  **Enable Developer Mode** (iOS 16+):
    *   Go to **Settings > Privacy & Security**.
    *   Scroll down to **Developer Mode** and enable it.
    *   Your phone will restart. After restart, unlock and tap "Turn On" in the alert.

4.  **Run the App**:
    *   In the terminal, check your device ID:
        ```bash
        flutter devices
        ```
    *   Run the app targeting your phone (replace `<device_id>` with the ID found above):
        ```bash
        flutter run -d <device_id>
        ```

5.  **First Launch Trust**:
    *   The build might install but likely won't launch immediately.
    *   On your iPhone, go to **Settings > General > VPN & Device Management**.
    *   Tap the "Apple Development: ..." profile under USER APPS.
    *   Tap **Trust**.
    *   Run the `flutter run` command again or tap the app icon.
