# VcamNextPlus — Reconstructed Source

Clean-room reconstruction of VcamNextPlus v0.16.73 (corev2-vnp8-rc1) from binary reverse engineering.

## Overview

Virtual camera tweak for jailbroken iOS 15.0+. Replaces the live camera feed in any app with custom media (image, video, or RTMP stream from OBS/FFmpeg). Includes floating overlay controls on SpringBoard, an RTMP server daemon, auth/license management daemon, and a configuration app.

**Original package:** `com.vcnext.app`  
**Original name:** V4HCAM Next (rebranded to VcamNextPlus)  
**Architecture:** arm64e, rootless (roothide)  
**Version:** 0.16.73+corev2.vnp8~rc1 (Build 37)

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│                    VcamNextPlus Package                     │
├──────────────┬──────────────┬──────────────┬───────────────┤
│  VCNShared   │ VCNextCamera │VCNextOverlay │   VCNextApp   │
│ (library)    │ (tweak)      │ (tweak)      │ (application) │
├──────────────┼──────────────┼──────────────┼───────────────┤
│VCNextBrandUI │VCNextNetwork │VCNStream     │VCNNetwork     │
│ (tweak)      │ Compat       │ Daemon       │ Daemon        │
│              │ (tweak)      │ (tool)       │ (tool)        │
├──────────────┴──────────────┴──────────────┴───────────────┤
│              VCNNetworkDaemonLauncher (tool)                │
└────────────────────────────────────────────────────────────┘
```

### Components (9 subprojects)

| Component | Type | Target Process | Purpose |
|-----------|------|---------------|---------|
| VCNShared | Library | All | Shared paths, notifications, crypto, config |
| VCNextCamera | Tweak | cameracaptured, mediaserverd | Camera pipeline hooks, frame replacement |
| VCNextOverlay | Tweak | SpringBoard | Floating window, control panel |
| VCNextBrandUI | Tweak | com.vcnext.app | String replacement (V4HCAM → VcamNextPlus) |
| VCNextNetworkCompat | Tweak | VCNNetworkDaemon | URL redirect (anix204.xyz → vcnext.corev.bond) |
| VCNStreamDaemon | Tool | Standalone daemon | RTMP server on port 1935, FLV writer |
| VCNNetworkDaemon | Tool | Standalone daemon | Auth heartbeat, capability lease, cellular policy |
| VCNNetworkDaemonLauncher | Tool | Standalone | Sets DYLD_INSERT_LIBRARIES, execs NetworkDaemon |
| VCNextApp | Application | Standalone | Login, media import, camera config UI |

## Project Structure

```
VCNextPlus/
├── Makefile                          # Aggregate makefile (all subprojects)
├── README.md
├── REVERSE_ENGINEERING_MAP.md
├── TEST_PLAN.md
├── UI_DIFFERENCES.md
├── PHAN_TICH_KIEN_TRUC.txt          # Vietnamese architecture analysis
│
├── VCNShared/                        # Shared library
│   ├── Makefile
│   ├── VCNPaths.h / .m              # File path constants
│   ├── VCNNotifications.h / .m      # Darwin notification names + helpers
│   ├── VCNSecurity.h / .m           # ECDSA, RSA, AES, HMAC, SHA256, Keychain
│   └── VCNConfig.h / .m             # Plist config read/write, device detection
│
├── VCNextCamera/                     # Camera hook tweak
│   ├── Makefile
│   ├── Tweak.xm                     # Logos hooks (BW* classes)
│   ├── VCNCameraHooks.h / .m        # Hook declarations
│   ├── VCNVideoDecoder.h / .m       # H.264 VTDecompressionSession
│   ├── VCNFrameProcessor.h / .m     # Frame replacement engine
│   ├── VCNFaceDetector.h / .m       # Vision face detection + blur
│   ├── VCNColorSync.h / .m          # CIColorKernel RGB shift
│   └── VCNStreamReader.h / .m       # FLV file reader + parser
│
├── VCNextOverlay/                    # SpringBoard overlay tweak
│   ├── Makefile
│   ├── Tweak.xm                     # SpringBoard hook
│   ├── VCNFloatingWindow.h / .m     # Draggable floating button
│   ├── VCNControlPanel.h / .m       # Toggle/stream/source/color buttons
│   └── VCNScreenCapture.h / .m      # IOSurface screen capture
│
├── VCNextBrandUI/                    # Rebrand tweak
│   ├── Makefile
│   └── Tweak.xm                     # Swizzle setTitle:/setText:
│
├── VCNextNetworkCompat/              # URL redirect tweak
│   ├── Makefile
│   └── Tweak.xm                     # Swizzle +[NSURL URLWithString:]
│
├── VCNNetworkDaemonLauncher/         # Launcher (pure C)
│   ├── Makefile
│   └── main.c                       # DYLD_INSERT + execl
│
├── VCNStreamDaemon/                  # RTMP server daemon
│   ├── Makefile
│   ├── main.m                       # Server setup, FLV video callback
│   └── rtmp/
│       ├── rtmp_server.h / .c       # Core server, socket, protocol control
│       ├── rtmp_handshake.h / .c    # C0/C1/C2 handshake
│       ├── rtmp_chunk.h / .c        # Chunk read/write, reassembly
│       ├── rtmp_amf.h / .c          # AMF0 encode/decode
│       ├── rtmp_netconnection.h / .c # connect, createStream, etc.
│       ├── rtmp_netstream.h / .c    # publish, invoke dispatcher
│       └── rtmp_flv.h / .c          # FLV container format
│
├── VCNNetworkDaemon/                 # Auth/heartbeat daemon
│   ├── Makefile
│   ├── entitlements.plist
│   ├── main.m                       # EC keygen, cellular policy, heartbeat
│   ├── VCNHTTPClient.h / .m         # NSURLSession HTTP client
│   ├── VCNAuthHeartbeat.h / .m      # ECDSA-signed heartbeat, lease refresh
│   ├── VCNCellularPolicy.h / .m     # CoreTelephony private API
│
├── VCNextApp/                        # Main UI application
│   ├── Makefile
│   ├── entitlements.plist
│   ├── Info.plist                    # Bundle config (from original)
│   ├── main.m
│   ├── VCNAppDelegate.h / .m
│   ├── VCNMainViewController.h / .m # Main screen (account/camera/media/server)
│   ├── VCNAccountManager.h / .m     # Login/logout, token management
│   ├── VCNMediaPicker.h / .m        # Photos/Files import
│   ├── VCNCameraConfigController.h / .m # Camera settings UI
│   └── Resources/
│       └── ASSETS_README.txt         # Placeholder notes for images
│
└── layout/                           # Package layout
    ├── DEBIAN/
    │   ├── control
    │   ├── postinst
    │   ├── preinst
    │   └── prerm
    ├── Library/
    │   ├── LaunchDaemons/
    │   │   ├── com.vcnext.streamd.plist
    │   │   └── com.vcnext.networkd.plist
    │   └── TweakInject/
    │       ├── VCNextCamera.plist
    │       ├── VCNextOverlay.plist
    │       ├── VCNextBrandUI.plist
    │       └── VCNextNetworkCompat.plist
```

## Dependencies

| Dependency | Source | Required By |
|-----------|--------|-------------|
| Theos | Build system | All |
| MobileSubstrate | Jailbreak | Camera, Overlay, BrandUI, NetworkCompat tweaks |
| rootless-compat >= 0.9 | Jailbreak | Package (roothide support) |
| firmware >= 15.0 | iOS | All |

### Frameworks Used

UIKit, Foundation, CoreFoundation, Security, CommonCrypto, CoreImage, CoreVideo, VideoToolbox, Vision, AVFoundation, IOSurface, QuartzCore, CoreTelephony, Photos, PhotosUI

### Private APIs

- `CARenderServerRenderDisplay` (QuartzCore) — screen capture
- `CTServerConnectionCreate` / `CTServerConnectionSetCellularUsagePolicy` (CoreTelephony) — cellular data policy
- `BW*` classes (mediaserverd) — camera pipeline internals

## Build Requirements

- macOS with Xcode Command Line Tools
- [Theos](https://theos.dev/) installed and configured
- iOS 15.0+ SDK
- arm64e target support

## Build

```bash
export THEOS=/path/to/theos
export THEOS_DEVICE_IP=your-device-ip

# Copy original image assets into VCNextApp/Resources/ first
# (AppIcon.png, AppIcon@2x.png, AppIcon@3x.png, BrandLogo.png)

make clean
make package
```

## Installation

```bash
# Via Theos
make install

# Or manually
dpkg -i packages/com.vcnext.app_0.16.73+corev2.vnp8~rc1_iphoneos-arm64e.deb

# Post-install runs automatically:
# - Creates /var/jb/var/mobile/Library/VCNext/{Media,Streams}
# - Loads LaunchDaemons
# - Runs uicache
# - Kills mediaserverd (triggers dylib reload)
```

## Runtime Behavior

### Startup Sequence
1. `launchd` starts VCNStreamDaemon (RTMP server, port 1935)
2. `launchd` starts VCNNetworkDaemonLauncher → injects URL redirect → execs VCNNetworkDaemon
3. NetworkDaemon generates ECDSA key pair, authenticates, starts heartbeat
4. MobileSubstrate loads VCNextCamera.dylib into mediaserverd/cameracaptured
5. MobileSubstrate loads VCNextOverlay.dylib into SpringBoard

### IPC Architecture
- **Darwin Notifications**: Signal-only (no payload), receiver reads corresponding plist
- **Plist Files**: Shared state in `/var/jb/var/mobile/Library/VCNext/`
- Notifications: auth.changed, camera.config, camera.status, capability.changed, server.status, overlay.toggle, stream.start, stream.stop

### Camera Replacement Flow
1. User enables via overlay or app
2. Config written to CameraConfig.plist → Darwin notification posted
3. VCNextCamera reads config, loads media source
4. Hooks intercept `renderSampleBuffer:forInput:` on BW* pipeline nodes
5. VCNFrameProcessor replaces pixel buffer with media content
6. Optional: CIColorKernel color sync, Vision face detection + blur

## Configuration

All config stored as plists in `/var/jb/var/mobile/Library/VCNext/`:

| File | Contents |
|------|----------|
| AuthSession.plist | username, token, expiresAt, loginTime |
| CameraConfig.plist | enabled, sourceType, mediaPath, colorSync, faceBlur |
| CameraStatus.plist | active, lastFrameTime, frameCount |
| CapabilityLease.plist | streamEnabled, maxResolution, expiresAt |
| ServerStatus.plist | state, port, timestamp |

## Known Limitations

1. Class names in original binary are obfuscated (VCN + hex hash). Reconstructed names are descriptive equivalents based on behavioral analysis.
2. RTMP server is simplified: no digest handshake, no AMF3, single client at a time.
3. Original image assets (icons, logo) not included — must be copied from extracted .deb or replaced.
4. BW* camera pipeline classes are undocumented iOS internals. Names/interfaces may change between iOS versions.
5. Cannot verify exact UI layout (pixel-perfect spacing, colors) without running on device.
6. Some error paths and edge cases are inferred from binary structure, not confirmed at runtime.

## Reconstruction Confidence

See [REVERSE_ENGINEERING_MAP.md](REVERSE_ENGINEERING_MAP.md) for per-symbol confidence levels.

**Overall:** ~85% behavioral equivalence. Core architecture, hooks, IPC, crypto, and RTMP protocol are CONFIRMED from binary analysis. UI layout details and some error handling paths are RECONSTRUCTED/INFERRED.
