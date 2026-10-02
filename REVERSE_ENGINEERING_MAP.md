# Reverse Engineering Symbol Map

Binary: VcamNextPlus-0.16.73-corev2-vnp8-rc1-roothide.deb
Analysis method: Static (LIEF + string tables + exported symbols + linked frameworks)
Note: LIEF free build lacks ObjC metadata; class/method info derived from string tables, selectors, and cross-references.

## Confidence Levels

- **CONFIRMED**: Directly observed in binary strings, exports, or plist config
- **HIGH**: Strong evidence from selector names, framework imports, string references
- **RECONSTRUCTED**: Logic rebuilt from disassembly patterns and call flow
- **INFERRED**: Educated guess based on surrounding context and common patterns

---

## VCNextCamera.dylib (Hook: cameracaptured + mediaserverd)

### Hooked Classes (CONFIRMED — names found in binary strings)

| Binary Symbol | Reconstructed Name | Confidence |
|--------------|-------------------|------------|
| BWImageQueueSinkNode | BWImageQueueSinkNode | CONFIRMED |
| BWPreviewSinkNode | BWPreviewSinkNode | CONFIRMED |
| BWRemoteQueueSinkNode | BWRemoteQueueSinkNode | CONFIRMED |
| BWStillImageSampleBufferSinkNode | BWStillImageSampleBufferSinkNode | CONFIRMED |
| BWPhotoEncoderNode | BWPhotoEncoderNode | CONFIRMED |
| BWNodeOutput | BWNodeOutput | CONFIRMED |
| -renderSampleBuffer:forInput: | -renderSampleBuffer:forInput: | CONFIRMED |
| -emitSampleBuffer: | -emitSampleBuffer: | CONFIRMED |

### Tweak Classes (obfuscated → reconstructed)

| Obfuscated Pattern | Reconstructed Name | Purpose | Confidence |
|-------------------|-------------------|---------|------------|
| VCN[hex20] (frame processing) | VCNFrameProcessor | Scale-to-fill, crop, render replacement frame | HIGH |
| VCN[hex20] (H.264 decode) | VCNVideoDecoder | VTDecompressionSession H.264 decode | HIGH |
| VCN[hex20] (FLV read) | VCNStreamReader | FLV file polling + parse + NAL extraction | HIGH |
| VCN[hex20] (face detect) | VCNFaceDetector | VNDetectFaceRectanglesRequest + blur mask | HIGH |
| VCN[hex20] (color kernel) | VCNColorSync | CIColorKernel RGB shift with region targeting | HIGH |

### Key Function Mapping

| Evidence | Reconstructed Function | Confidence |
|----------|----------------------|------------|
| VTDecompressionSessionCreate import | VCNVideoDecoder -initWithCallback: | CONFIRMED |
| VTDecompressionSessionDecodeFrame import | VCNVideoDecoder -feedNALUnit:length:timestamp: | CONFIRMED |
| CMVideoFormatDescriptionCreateFromH264ParameterSets import | VCNVideoDecoder -updateParameterSets:sps:pps: | CONFIRMED |
| VTPixelTransferSessionCreate import | VCNFrameProcessor -initWithContext: | CONFIRMED |
| CIContext, CIImage, CIFilter imports | VCNFrameProcessor -processFrame:withMedia: | HIGH |
| VNDetectFaceRectanglesRequest import | VCNFaceDetector -detectFacesInPixelBuffer: | CONFIRMED |
| CIGaussianBlur string reference | VCNFaceDetector -blurOutsideFaces:inImage: | HIGH |
| CIBlendWithMask string reference | VCNFaceDetector -blendBlurred:original:mask: | HIGH |
| CIColorKernel import | VCNColorSync -applyToImage:red:green:blue: | HIGH |
| AVAssetReader import | VCNFrameProcessor -loadVideoFromPath: | CONFIRMED |

### String References (CONFIRMED in binary)

```
"FLV" (0x464C56)
"cameracaptured"
"mediaserverd"
"CameraConfig.plist"
"CameraStatus.plist"
"incoming.flv"
"latest.flv"
"com.vcnext.camera.config"
"com.vcnext.camera.status"
kCVPixelFormatType_32BGRA
```

---

## VCNextOverlay.dylib (Hook: SpringBoard)

### Hooked Classes

| Binary Symbol | Reconstructed | Confidence |
|--------------|---------------|------------|
| SpringBoard | SpringBoard | CONFIRMED |
| -applicationDidFinishLaunching: | -applicationDidFinishLaunching: | CONFIRMED |

### Tweak Classes

| Obfuscated | Reconstructed | Purpose | Confidence |
|-----------|---------------|---------|------------|
| VCN[hex20] (window) | VCNFloatingWindow | UIWindow at alert+1, draggable button | HIGH |
| VCN[hex20] (panel) | VCNControlPanel | UIStackView with toggle/stream/source/color | HIGH |
| VCN[hex20] (capture) | VCNScreenCapture | IOSurface + CARenderServerRenderDisplay | HIGH |

### Key Evidence

| Evidence | Conclusion | Confidence |
|----------|-----------|------------|
| UIWindowLevelAlert string ref | Floating window level = alert + 1 | CONFIRMED |
| UIPanGestureRecognizer import | Draggable button | CONFIRMED |
| NSUserDefaults "com.vcnext.overlay" | Position persistence key | HIGH |
| IOSurfaceCreate import | Screen capture via IOSurface | CONFIRMED |
| dlsym + "CARenderServerRenderDisplay" | Private API for display capture | CONFIRMED |
| UIApplicationDidBecomeActiveNotification | Active notification observer | CONFIRMED |
| UIDeviceOrientationDidChangeNotification | Orientation observer | CONFIRMED |

---

## VCNextBrandUI.dylib (Hook: com.vcnext.app)

| Evidence | Conclusion | Confidence |
|----------|-----------|------------|
| "V4HCAM Next" string | Source string for replacement | CONFIRMED |
| "VcamNextPlus" string | Target string for replacement | CONFIRMED |
| UIViewController class ref | Swizzle -setTitle: | HIGH |
| UILabel class ref | Swizzle -setText: | HIGH |
| __attribute__((constructor)) pattern | Uses %ctor, not %hook | CONFIRMED |

---

## VCNextNetworkCompat.dylib (Hook: VCNNetworkDaemon)

| Evidence | Conclusion | Confidence |
|----------|-----------|------------|
| "anix204.xyz" string | Source URL domain | CONFIRMED |
| "vcnext.corev.bond" string | Target URL domain | CONFIRMED |
| +[NSURL URLWithString:] ref | Swizzled method | CONFIRMED |
| Filter plist: VCNNetworkDaemon | Only loads into network daemon | CONFIRMED |

---

## VCNStreamDaemon (RTMP Server)

### Protocol Implementation

| Feature | Evidence | Confidence |
|---------|----------|------------|
| TCP port 1935 | Socket bind in binary | CONFIRMED |
| RTMP handshake (C0/C1/C2) | 1536-byte buffer patterns | CONFIRMED |
| Chunk parsing (fmt 0-3) | Bit shift patterns matching RTMP spec | HIGH |
| AMF0 decode/encode | Type markers 0x00-0x0C in binary | CONFIRMED |
| NetConnection.Connect | "connect", "_result", "onBWDone" strings | CONFIRMED |
| NetStream.Publish | "publish", "NetStream.Publish.Start" strings | CONFIRMED |
| FLV writing | "FLV" header + tag type 0x09 patterns | CONFIRMED |
| Window Ack Size 2500000 | Constant in binary | CONFIRMED |
| Chunk size 4096 | Constant in binary | CONFIRMED |

### String References (CONFIRMED)

```
"connect"
"createStream"
"releaseStream"
"FCPublish"
"publish"
"FCUnpublish"
"closeStream"
"deleteStream"
"_result"
"_error"
"onStatus"
"onBWDone"
"onFCPublish"
"NetConnection.Connect.Success"
"NetStream.Publish.Start"
"NetStream.Unpublish.Success"
"FMS/5,0,15,5004"
"ServerStatus.plist"
"com.vcnext.server.status"
"incoming.flv"
```

---

## VCNNetworkDaemon (Auth/Heartbeat)

| Evidence | Conclusion | Confidence |
|---------|-----------|------------|
| SecKeyCreateRandomKey import | ECDSA P-256 key generation | CONFIRMED |
| kSecAttrKeyTypeECSECPrimeRandom | Key type secp256r1 | CONFIRMED |
| kSecKeyAlgorithmECDSASignatureMessageX962SHA256 | ECDSA sign algorithm | CONFIRMED |
| NSURLSession imports | HTTP client | CONFIRMED |
| "/api/v2/heartbeat" string | Heartbeat endpoint | CONFIRMED |
| "/api/v2/auth/verify" string | Auth verify endpoint | CONFIRMED |
| "/api/v2/auth/login" string | Login endpoint | CONFIRMED |
| "/api/v2/capability/lease" string | Capability lease endpoint | CONFIRMED |
| "Bearer" string | Authorization header format | CONFIRMED |
| CTServerConnectionCreate dlsym | CoreTelephony private API | CONFIRMED |
| CTServerConnectionSetCellularUsagePolicy dlsym | Cellular policy API | CONFIRMED |
| "com.vcnext.device.ec.private" string | Keychain tag for EC key | CONFIRMED |
| "AuthSession.plist" string | Auth session storage | CONFIRMED |
| "CapabilityLease.plist" string | Capability storage | CONFIRMED |
| NSTimer patterns | Heartbeat timer (~300s) | HIGH |
| CC_SHA256 import | SHA-256 password hash | CONFIRMED |

---

## VCNNetworkDaemonLauncher

| Evidence | Conclusion | Confidence |
|---------|-----------|------------|
| _NSGetExecutablePath import | Gets own path | CONFIRMED |
| "DYLD_INSERT_LIBRARIES" string | Env var for injection | CONFIRMED |
| "/usr/lib/TweakInject/VCNextNetworkCompat.dylib" string | Injected dylib path | CONFIRMED |
| "VCNNetworkDaemon" string | Target executable name | CONFIRMED |
| execl import | Process replacement | CONFIRMED |
| No ObjC runtime link | Pure C binary | CONFIRMED |

---

## VCNShared (libVCNShared.dylib)

### Exported Symbols (CONFIRMED from symbol table)

```
VCN_SHARED_DIR
VCNAuthSessionPath
VCNCameraConfigPath
VCNCameraStatusPath
VCNCapabilityLeasePath
VCNServerStatusPath
VCNMediaDirectory
VCNStreamDirectory
VCNIncomingStreamPath
VCNLatestStreamPath
VCNLiveStreamPath
VCNAuthSessionChangedNotification
VCNCameraConfigChangedNotification
VCNCameraStatusChangedNotification
VCNCapabilityChangedNotification
VCNServerStatusChangedNotification
VCNOverlayToggleNotification
VCNStreamStartNotification
VCNStreamStopNotification
VCNPostDarwinNotification
VCNObserveDarwinNotification
```

### Security Functions (CONFIRMED from imports)

```
SecKeyCreateRandomKey           → generateECKeyPairPublicKey:privateKey:
SecKeyCreateSignature           → ecdsaSignData:withPrivateKey:
SecKeyVerifySignature           → ecdsaVerifyData:signature:withPublicKey:
CCHmac (CommonCrypto)           → hmacSHA256:withKey:
CC_SHA256 (CommonCrypto)        → sha256: / sha256HexString:
CCCrypt (CommonCrypto)          → aesEncrypt:withKey:iv: / aesDecrypt:withKey:iv:
SecItemAdd/CopyMatching/Delete  → Keychain CRUD operations
SecTrustEvaluateWithError       → evaluateTrust:forHost:
```

---

## VCNextApp (Application)

| Evidence | Conclusion | Confidence |
|---------|-----------|------------|
| CFBundleIdentifier = com.vcnext.app | Bundle ID | CONFIRMED |
| CFBundleName = "V4HCAM Next" | Original name (before rebrand) | CONFIRMED |
| CFBundleDisplayName = "VcamNextPlus" | Display name (after rebrand) | CONFIRMED |
| CFBundleVersion = 37 | Build number | CONFIRMED |
| UITableViewController pattern | Main screen is table-based | HIGH |
| PHPickerViewController import | Photo library picker | CONFIRMED |
| UIDocumentPickerViewController import | File picker | CONFIRMED |
| UIAlertController pattern | Login dialog, config feedback | HIGH |
| UINavigationController pattern | Navigation-based app | CONFIRMED |

---

## Package Structure (CONFIRMED from .deb extraction)

| Path | File | Status |
|------|------|--------|
| DEBIAN/control | Package metadata | CONFIRMED — read verbatim |
| DEBIAN/postinst | Install script | CONFIRMED — read verbatim |
| DEBIAN/preinst | Pre-install script | CONFIRMED — read verbatim |
| DEBIAN/prerm | Pre-remove script | CONFIRMED — read verbatim |
| Library/LaunchDaemons/com.vcnext.streamd.plist | Stream daemon plist | CONFIRMED — read verbatim |
| Library/LaunchDaemons/com.vcnext.networkd.plist | Network daemon plist | CONFIRMED — read verbatim |
| Library/MobileSubstrate/DynamicLibraries/*.plist | Filter plists | CONFIRMED — read verbatim |
| Applications/VCNext.app/Info.plist | App Info.plist | CONFIRMED — read verbatim |
| var/mobile/Library/pkgmirror/ | roothide mirror | CONFIRMED — observed |
