# Test Plan — VcamNextPlus Reconstructed

## Test Environment
- Device: Jailbroken iOS 15.0+ (arm64e)
- Jailbreak: roothide-compatible (Dopamine, palera1n, etc.)
- Tools: OBS Studio (for RTMP streaming), any camera-using app

---

## 1. Installation & Package

| # | Test Case | Expected | Status | Notes |
|---|-----------|----------|--------|-------|
| 1.1 | Install .deb via dpkg | Installs without errors | TODO | |
| 1.2 | postinst creates VCNext directories | /var/jb/var/mobile/Library/VCNext/{Media,Streams} exist | TODO | |
| 1.3 | postinst loads LaunchDaemons | Both daemons running (ps aux) | TODO | |
| 1.4 | postinst cleans config plists | CameraConfig/Status/CapabilityLease removed | TODO | |
| 1.5 | Fresh install removes AuthSession | AuthSession.plist deleted | TODO | |
| 1.6 | Upgrade preserves AuthSession | AuthSession.plist kept ($2 non-empty) | TODO | |
| 1.7 | uicache registers app | VcamNextPlus appears on home screen | TODO | |
| 1.8 | mediaserverd restart | Camera dylib loads immediately | TODO | |
| 1.9 | A13 device (iPhone12,*) handling | Camera filter rewritten to mediaserverd-only | TODO | |
| 1.10 | Uninstall via dpkg -r | LaunchDaemons unloaded, clean removal | TODO | |

## 2. VCNStreamDaemon (RTMP Server)

| # | Test Case | Expected | Status | Notes |
|---|-----------|----------|--------|-------|
| 2.1 | Daemon starts on boot | Listening on port 1935 | TODO | |
| 2.2 | ServerStatus.plist written | state=listening, port=1935 | TODO | |
| 2.3 | OBS connects to rtmp://device:1935/live | Handshake completes, state=connected | TODO | |
| 2.4 | OBS starts publishing | state=streaming, video data received | TODO | |
| 2.5 | FLV file written | incoming.flv contains valid FLV data | TODO | |
| 2.6 | OBS disconnects | state=listening, server re-accepts | TODO | |
| 2.7 | FFmpeg stream test | ffmpeg -i input.mp4 -f flv rtmp://device:1935/live works | TODO | |
| 2.8 | Multiple reconnections | Server handles reconnect without crash | TODO | |
| 2.9 | Capability revoked | Daemon logs capability revoked message | TODO | |
| 2.10 | SIGTERM handling | Clean shutdown, no zombie process | TODO | |

## 3. VCNNetworkDaemon (Auth & Heartbeat)

| # | Test Case | Expected | Status | Notes |
|---|-----------|----------|--------|-------|
| 3.1 | Launcher sets DYLD_INSERT_LIBRARIES | VCNextNetworkCompat.dylib loaded | TODO | |
| 3.2 | EC key pair generated on first run | com.vcnext.device.ec.private in Keychain | TODO | |
| 3.3 | EC key pair preserved on restart | Same key reused, not regenerated | TODO | |
| 3.4 | Cellular policy set | com.vcnext.app allowed cellular data | TODO | |
| 3.5 | Initial authentication | POST /api/v2/auth/verify called | TODO | |
| 3.6 | Heartbeat fires every 5 min | POST /api/v2/heartbeat with ECDSA signature | TODO | |
| 3.7 | Capability lease refresh every 1 hr | GET /api/v2/capability/lease called | TODO | |
| 3.8 | Auth notification triggers re-auth | Responds to com.vcnext.auth.changed | TODO | |
| 3.9 | URL redirect active | anix204.xyz → vcnext.corev.bond in requests | TODO | |
| 3.10 | Unauthorized response clears session | AuthSession.plist emptied, notification posted | TODO | |

## 4. VCNextCamera (Camera Replacement)

| # | Test Case | Expected | Status | Notes |
|---|-----------|----------|--------|-------|
| 4.1 | Dylib loads into mediaserverd | No crash, hooks installed | TODO | |
| 4.2 | Dylib loads into cameracaptured (iOS 17+) | No crash, hooks installed | TODO | |
| 4.3 | Config change notification received | Reads CameraConfig.plist, updates state | TODO | |
| 4.4 | Image source: camera shows image | Static image replaces camera feed | TODO | |
| 4.5 | Video source: camera shows video | Looping video replaces camera feed | TODO | |
| 4.6 | Stream source: camera shows RTMP stream | Live stream from OBS replaces camera | TODO | |
| 4.7 | Scale-to-fill + crop | Media fills frame without stretching | TODO | |
| 4.8 | Works in Camera app | Preview shows replacement content | TODO | |
| 4.9 | Works in FaceTime | Remote party sees replacement content | TODO | |
| 4.10 | Works in third-party apps | WhatsApp/Zoom/etc show replacement | TODO | |
| 4.11 | Still photo capture | Captured photo uses replacement content | TODO | |
| 4.12 | Color Sync enabled | RGB shift applied to replacement frame | TODO | |
| 4.13 | Color Sync regions | Forehead/Chin/Sides targeting works | TODO | |
| 4.14 | Face blur enabled | Blur outside detected faces | TODO | |
| 4.15 | Face blur radius configurable | Blur radius matches config value | TODO | |
| 4.16 | Disable camera replacement | Original camera feed restored | TODO | |
| 4.17 | FLV stream reader | Parses incoming.flv, extracts NAL units | TODO | |
| 4.18 | H.264 decoder | VTDecompressionSession decodes without errors | TODO | |
| 4.19 | Sample buffer attachments preserved | Metadata, timing info carried through | TODO | |

## 5. VCNextOverlay (SpringBoard UI)

| # | Test Case | Expected | Status | Notes |
|---|-----------|----------|--------|-------|
| 5.1 | Floating button appears | Circular button visible on SpringBoard | TODO | |
| 5.2 | Button draggable | Pan gesture moves button | TODO | |
| 5.3 | Button snaps to edge | Releases near screen edges snap properly | TODO | |
| 5.4 | Position persists across resprings | NSUserDefaults com.vcnext.overlay | TODO | |
| 5.5 | Hit test pass-through | Touches outside button reach apps below | TODO | |
| 5.6 | Control panel opens | Tap button shows panel with controls | TODO | |
| 5.7 | Toggle button works | Enables/disables camera replacement | TODO | |
| 5.8 | Stream button works | Starts/stops RTMP stream acceptance | TODO | |
| 5.9 | Source button works | Switches source type (image/video/stream) | TODO | |
| 5.10 | Status label updates | Shows current state from config/status plists | TODO | |
| 5.11 | Orientation change handling | Layout adjusts on device rotation | TODO | |
| 5.12 | Button visible over all apps | UIWindowLevel above normal windows | TODO | |

## 6. VCNextBrandUI (String Replacement)

| # | Test Case | Expected | Status | Notes |
|---|-----------|----------|--------|-------|
| 6.1 | UIViewController titles replaced | "V4HCAM Next" → "VcamNextPlus" | TODO | |
| 6.2 | UILabel text replaced | "V4HCAM Next" → "VcamNextPlus" | TODO | |
| 6.3 | Only active in VCNext app | Other apps unaffected | TODO | |

## 7. VCNextApp (Main Application)

| # | Test Case | Expected | Status | Notes |
|---|-----------|----------|--------|-------|
| 7.1 | App launches | Main screen with 4 sections visible | TODO | |
| 7.2 | Login dialog | Username + password fields, login button | TODO | |
| 7.3 | Login success | Token saved, username displayed | TODO | |
| 7.4 | Login failure | Error message shown | TODO | |
| 7.5 | Logout | Session cleared, notifications posted | TODO | |
| 7.6 | Import from Photos | PHPicker opens, media copied to Media/ | TODO | |
| 7.7 | Import from Files | Document picker opens, file copied | TODO | |
| 7.8 | Camera Config screen | 3 sections: Source, Color Sync, Face Detection | TODO | |
| 7.9 | Config save | Writes CameraConfig.plist, posts notification | TODO | |
| 7.10 | Server status display | Shows RTMP state, port, capability | TODO | |
| 7.11 | Pull to refresh | Status reloaded from plists | TODO | |
| 7.12 | Dark theme navigation bar | Dark background, white text | TODO | |

## 8. Edge Cases & Error Paths

| # | Test Case | Expected | Status | Notes |
|---|-----------|----------|--------|-------|
| 8.1 | First launch (no config) | Safe defaults, no crash | TODO | |
| 8.2 | Missing media file | Graceful fallback, no crash | TODO | |
| 8.3 | Invalid FLV data | Stream reader handles gracefully | TODO | |
| 8.4 | Network offline | Heartbeat fails silently, retries | TODO | |
| 8.5 | Token expired | Re-authentication triggered | TODO | |
| 8.6 | mediaserverd crash recovery | Dylib reloads on restart | TODO | |
| 8.7 | Respring | Overlay recreated, daemons unaffected | TODO | |
| 8.8 | Reboot | LaunchDaemons restart everything | TODO | |
| 8.9 | Concurrent camera access | Multiple apps using camera simultaneously | TODO | |
| 8.10 | Low memory | No excessive allocation in frame processing | TODO | |

## 9. Comparison: Original vs Reconstructed

| Feature | Original | Reconstructed | Match |
|---------|----------|---------------|-------|
| Camera hook (mediaserverd) | Yes | Yes | Equivalent |
| Camera hook (cameracaptured) | Yes | Yes | Equivalent |
| Image source replacement | Yes | Yes | Equivalent |
| Video source replacement | Yes | Yes | Equivalent |
| RTMP stream source | Yes | Yes | Equivalent |
| H.264 decoding | VTDecompressionSession | VTDecompressionSession | Equivalent |
| Frame processing | CIContext + VTPixelTransfer | CIContext + VTPixelTransfer | Equivalent |
| Face detection | VNDetectFaceRectangles | VNDetectFaceRectangles | Equivalent |
| Color sync | CIColorKernel | CIColorKernel | Equivalent |
| Floating overlay | UIWindow + pan gesture | UIWindow + pan gesture | Equivalent |
| RTMP server | Port 1935, custom C impl | Port 1935, custom C impl | Equivalent |
| FLV writing | Direct file write | Direct file write | Equivalent |
| Auth heartbeat | ECDSA-signed, 5min interval | ECDSA-signed, 5min interval | Equivalent |
| Cellular policy | CTServerConnection SPI | CTServerConnection SPI | Equivalent |
| URL redirect | Swizzle NSURL, DYLD inject | Swizzle NSURL, DYLD inject | Equivalent |
| Brand UI | Swizzle setTitle/setText | Swizzle setTitle/setText | Equivalent |
| App UI | UITableViewController | UITableViewController | Approximate |
| A13 handling | Canary flag + filter rewrite | Canary flag + filter rewrite | Equivalent |
| Class name obfuscation | VCN+hex20 | Descriptive names | Different (by design) |
