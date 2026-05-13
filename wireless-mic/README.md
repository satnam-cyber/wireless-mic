# Wireless Microphone System

A complete wireless microphone solution that streams audio from an Android device to a Windows PC via UDP. The Windows client outputs audio to a virtual microphone (VB-Cable) for use in any application.

## Project Structure

```
wireless-mic/
├── android_app/          # Flutter Android application
│   ├── lib/
│   │   ├── main.dart            # Main UI and app entry point
│   │   └── audio_provider.dart  # State management and UDP sender
│   ├── android/
│   │   ├── app/src/main/kotlin/com/mymic/
│   │   │   ├── AudioStreamPlugin.kt  # Native audio capture plugin
│   │   │   └── wireless_mic/MainActivity.kt
│   │   ├── app/build.gradle
│   │   └── build.gradle
│   └── pubspec.yaml
├── windows_client/       # Python Windows receiver
│   ├── main.py           # Main client application
│   └── requirements.txt  # Python dependencies
└── README.md             # This file
```

## Features

### Android App
- **Material 3 Dark Theme**: Clean, modern UI
- **Real-time Status**: Visual indicators (🔴 Streaming, ⏹️ Ready, ⚠️ Error)
- **IP Configuration**: Configurable server IP (default: 192.168.1.100)
- **Native Audio Capture**: 48kHz, 16-bit, mono PCM via Kotlin AudioRecord
- **UDP Streaming**: Raw audio packets sent via dart:io RawDatagramSocket
- **Permission Handling**: Runtime microphone and network permissions
- **Background Support**: Prepared for flutter_background_service integration

### Windows Client
- **UDP Listener**: Receives audio on port 55555
- **Thread-safe Queue**: Prevents audio jitter with max 50-packet buffer
- **PyAudio Output**: Outputs to default playback device (VB-Cable)
- **Console UI**: Simple commands for status and control
- **Statistics**: Real-time packet count, bitrate, queue depth
- **Auto-recovery**: Graceful handling of connection drops

## Technical Specifications

| Parameter | Value |
|-----------|-------|
| Sample Rate | 48000 Hz |
| Bit Depth | 16-bit |
| Channels | Mono (1) |
| Format | PCM (uncompressed) |
| Protocol | UDP |
| Port | 55555 |
| Chunk Size | 4800 bytes (~100ms) |
| Max Queue | 50 packets |
| Bitrate | ~768 kbps |

---

## Installation & Setup

### Part 1: Windows Client Setup

#### Step 1: Install Python
1. Download Python 3.9+ from https://python.org
2. During installation, check "Add Python to PATH"

#### Step 2: Install VB-Cable (Virtual Microphone)
1. Download VB-Cable from https://vb-audio.com/Cable/
2. Run the installer as Administrator
3. Restart your computer after installation
4. Verify installation:
   - Right-click speaker icon → Sounds → Playback tab
   - You should see "CABLE Input (VB-Audio Virtual Cable)"
   - Recording tab should show "CABLE Output (VB-Audio Virtual Cable)"

#### Step 3: Install Python Dependencies
```bash
cd windows_client
pip install -r requirements.txt
```

**Note for PyAudio on Windows:**
If `pip install pyaudio` fails, download the wheel file from:
https://www.lfd.uci.edu/~gohlke/pythonlibs/#pyaudio

Then install:
```bash
pip install PyAudio‑0.2.13‑cp311‑cp311‑win_amd64.whl
```
(Adjust version number for your Python version)

#### Step 4: Configure Windows Firewall
Allow UDP port 55555 through Windows Firewall:

**Option A: Using PowerShell (Admin)**
```powershell
New-NetFirewallRule -DisplayName "Wireless Mic UDP" -Direction Inbound -Protocol UDP -LocalPort 55555 -Action Allow
```

**Option B: Using GUI**
1. Open Windows Defender Firewall → Advanced Settings
2. Inbound Rules → New Rule
3. Select "Port" → UDP → Specific local ports: 55555
4. Allow the connection → Apply to all profiles
5. Name: "Wireless Mic UDP"

#### Step 5: Set Default Playback Device
1. Right-click speaker icon → Sounds → Playback tab
2. Select "CABLE Input (VB-Audio Virtual Cable)"
3. Click "Set Default"
4. Click OK

---

### Part 2: Android App Setup

#### Step 1: Install Flutter SDK
1. Download Flutter from https://docs.flutter.dev/get-started/install
2. Extract to a location (e.g., `C:\src\flutter`)
3. Add Flutter to PATH environment variable
4. Run `flutter doctor` to verify installation

#### Step 2: Setup VS Code for Flutter Development
1. Install VS Code from https://code.visualstudio.com/
2. Install extensions:
   - Flutter (by Dart Code)
   - Dart (by Dart Code)
   - Android Studio Tools (optional)

3. Configure Flutter:
   ```bash
   flutter config --android-sdk <path-to-android-sdk>
   flutter doctor
   ```

#### Step 3: Install Android Studio & SDK
1. Download Android Studio from https://developer.android.com/studio
2. During installation, ensure Android SDK is installed
3. Open SDK Manager and install:
   - Android SDK Platform 34 (or latest)
   - Android SDK Build-Tools
   - Android Emulator (optional)
   - Google USB Driver (if using physical device)

4. Enable USB Debugging on Android device:
   - Settings → About Phone → Tap "Build Number" 7 times
   - Settings → Developer Options → Enable "USB Debugging"

#### Step 4: Build and Run Android App
```bash
cd android_app

# Get dependencies
flutter pub get

# Connect Android device via USB or start emulator

# Run in debug mode
flutter run

# Or build release APK
flutter build apk --release
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

---

## Usage Workflow

### 1. Start Windows Client
```bash
cd windows_client
python main.py
```

You should see:
```
==================================================
Wireless Microphone Windows Client
==================================================
Audio Format: 48000Hz, 16-bit, Mono
UDP Port: 55555
Max Queue Depth: 50 packets
--------------------------------------------------
[UDP] Listening on 0.0.0.0:55555
[AUDIO] Output started: 48000Hz, 16-bit, mono
--------------------------------------------------
[OK] Client started successfully!
Commands: [s]tatus, [q]uit
--------------------------------------------------
```

### 2. Find Your Windows IP Address
On Windows, open Command Prompt:
```cmd
ipconfig
```
Note the IPv4 address (e.g., 192.168.1.100)

### 3. Configure Android App
1. Open the Wireless Microphone app
2. Enter your Windows IP address in the input field
3. Grant microphone permission when prompted

### 4. Start Streaming
1. Press the **START** button on the Android app
2. Status should change to "🔴 Streaming"
3. Speak into your Android device's microphone
4. Check Windows client for packet reception

### 5. Use in Applications
Any application that uses microphones can now use "CABLE Output":
- Zoom, Discord, OBS, Teams, etc.
- Go to app's audio settings
- Select "CABLE Output (VB-Audio Virtual Cable)" as microphone

### 6. Stop Streaming
- Press **STOP** on Android app, OR
- Type `q` in Windows client console

---

## Troubleshooting

### No Audio on Windows

**Check 1: Firewall**
```powershell
# Test if port is open
netstat -an | findstr 55555
```
Should show UDP 55555 listening.

**Check 2: Default Playback Device**
Ensure CABLE Input is set as default playback device.

**Check 3: PyAudio Installation**
```python
import pyaudio
p = pyaudio.PyAudio()
print(f"Default output device: {p.get_default_output_device_info()}")
```

### Connection Issues

**Check 1: Same Network**
Ensure Android and Windows are on the same WiFi network.

**Check 2: Correct IP**
Verify the IP address entered matches Windows' actual IP.

**Check 3: Network Profile**
Windows Firewall may block on Public networks. Change to Private:
```powershell
Set-NetConnectionProfile -Name "YourNetwork" -NetworkCategory Private
```

### High Latency

**Solutions:**
1. Reduce distance between devices (use 5GHz WiFi)
2. Close other bandwidth-heavy applications
3. Ensure router QoS prioritizes UDP traffic
4. Check queue depth with `[s]tatus` command (should be < 10)

### Audio Quality Issues

**Crackling/Dropouts:**
- Increase MAX_QUEUE_SIZE in main.py (trade-off: more latency)
- Close CPU-intensive applications
- Use USB tethering instead of WiFi

**Low Volume:**
- Increase volume in Windows Sound settings
- Check Android media volume
- Adjust gain in recording application

### Permission Denied (Android)

Go to Settings → Apps → Wireless Microphone → Permissions:
- Enable "Microphone"
- Enable "Nearby devices" (for network access on Android 13+)

---

## Console Commands

| Command | Description |
|---------|-------------|
| `s` or `status` | Show current statistics |
| `q` or `quit` | Stop and exit |

### Status Output Example
```
========================================
STATUS
========================================
Packets Received: 1523
Packets Dropped:  0
Queue Depth:      3 / 50
Elapsed Time:     152.3s
Packets/sec:      10.0
Bitrate:          768.0 kbps
========================================
```

---

## Development Notes

### Adding Background Service (Android)

The app includes `flutter_background_service` dependency. To enable full background streaming:

1. Update `lib/audio_provider.dart` to initialize the service
2. Configure notification for foreground service
3. Handle Android 12+ background restrictions

### Modifying Audio Parameters

To change audio quality, update these constants in BOTH files:

**Android (`AudioStreamPlugin.kt`):**
```kotlin
private const val SAMPLE_RATE = 48000
```

**Windows (`main.py`):**
```python
class AudioConfig:
    SAMPLE_RATE = 48000
    CHUNK_SIZE = 4800  # Adjust proportionally
```

### Building Release APK

```bash
cd android_app
flutter build apk --release --split-per-abi
```

This creates smaller APKs optimized for each CPU architecture.

---

## Security Considerations

⚠️ **Important:** This system uses unencrypted UDP transmission.

- Only use on trusted private networks
- Do not expose to public/internet networks
- Audio data is sent in plain text
- No authentication is performed

For production use, consider adding:
- AES encryption for audio packets
- HMAC authentication
- TLS/DTLS transport layer

---

## License

This project is provided as-is for educational and personal use.

## Contributing

Feel free to submit issues and enhancement requests.

## Support

For issues:
1. Check the Troubleshooting section above
2. Review console output on both Android and Windows
3. Verify network connectivity with ping/traceroute
4. Test with different network configurations
