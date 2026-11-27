# Implementation notes

Flutter 3.47.7, Dart, Kotlin and Swift. Minimum platforms follow the generated toolchain: Android API 24, iOS 15. No third-party runtime packages, network layer or backend. `flutter_localizations` is an SDK package.

## State and timing

`NightController`: setup → starting → running → dark. Completion stays dark while unattended to avoid disturbing sleep; a tap returns to settings with a completion message. Reopening a completed session shows settings automatically. Non-resumed lifecycle states release brightness and keep-awake without ending the logical timer. Resume recomputes progress and continues only an unexpired session. Force-closing does not persist a running session.

Foreground animation samples a monotonic Stopwatch every 50ms, never accumulates timer ticks. Start and resume use a native clock including device sleep (`mach_continuous_time` on iOS, `SystemClock.elapsedRealtime` on Android), then rebase the foreground stopwatch. Changing wall time or time zone does not alter a session. The smoothstep remainder is `f(p)=1-3p²+2p³`. Hardware command is `max(0.01, initial*sqrt(f))`; software color intensity is `sqrt(f)`. Commands are serialized, with at most one pending fade brightness command. Session generations invalidate delayed work after leave, return or disposal. UI paints black before final brightness release; resume paints the current fade under a native black cover before removing it.

Duration is stored in seconds, with backward migration from the earlier minutes preference. Hour/minute/second Cupertino wheels support seconds-only and multi-day durations; the hours column is built lazily without a 24-hour or product time cap. Zero duration is disabled. Only the integer range of Dart Duration is enforced. Slider changes apply real hardware brightness without a wake lock. Preview and subsequent illumination share one original-brightness capture until leaving the app. There is no standalone color swatch. The running screen has a static moon and companion label; their color fades with the background and never exceeds its RGB channels. Completion removes both so the final frame is pure black.

This control formula is not a photometric calibration. The OS/hardware minimum may be higher than 0.01, and low-bit-depth color output can band. OLED and LCD require physical testing. The controls intentionally reveal dim text after an explicit long press; otherwise timeout leaves no text.

## Platform channel `amber_night/light`

| Method | Input | Behavior |
|---|---|---|
| loadSettings | none | Returns local seconds (legacy minutes migrated), brightness, language, introSeen |
| saveSettings | those four fields | Validates and saves local preferences |
| begin | brightness 0–1 | Captures brightness, controls screen brightness, enables keep-awake |
| preview | brightness 0–1 | Captures original brightness and applies live setup preview, without keep-awake |
| clock | none | Monotonic milliseconds including device sleep |
| suspend | none | Restores original brightness, releases keep-awake, retains lifecycle cover until resume is painted |
| setBrightness | brightness 0–1 | Applies only to the active foreground session |
| release | keepDark boolean | Disables keep-awake; keeps minimum brightness on a black foreground screen or restores original brightness on explicit exit |

Android uses window attributes, never WRITE_SETTINGS, device admin or accessibility services. iOS uses the current window scene’s screen and UIApplication idle timer with Flutter UIScene lifecycle and implicit-engine registration. Original brightness is restored immediately on resign-active / onPause, before another app becomes visible; background cleanup is idempotent. Becoming active does not force minimum brightness or capture a new baseline. Only an explicit begin/preview captures the current system brightness, including changes the user made outside the app.

The black native lifecycle shield prevents stale warm content flashing while Dart catches up. Resume releases it after Dart has painted either the current fade or the completed settings transition. No background execution service, alarm, notification, sound or vibration is required; elapsed time is recalculated when returning.

## Persistence and privacy

Android SharedPreferences / iOS UserDefaults. Inputs are normalized when loaded; only four preferences are persisted. Android backup is disabled. The iOS privacy manifest declares UserDefaults reason CA92.1 and timer reason 35F9.1 for elapsed-time calculations. No clock readings leave the device. Debug Android manifests retain Flutter’s INTERNET permission for debugging; main/release has no Internet permission.

## Verification boundary

Pure and widget tests cover live preview, brightness ownership, background/resume, sleep-time calibration, startup races, completed-screen recovery, second/multi-day wheels and accessibility layout. Native Swift tests use an injected screen to verify lifecycle restoration without claiming simulator light-output measurements. The macOS job runs these and a complete real-channel 30-second fade. Physical brightness, lock behavior and family experience still require the manual matrix.
