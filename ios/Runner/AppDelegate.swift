import Flutter
import UIKit
import Darwin

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  let light = AmberLightBridge()
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AmberLightBridge") {
      let channel = FlutterMethodChannel(name: "amber_night/light", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        self?.light.handle(call, result: result)
      }
    }
  }
}

protocol BrightnessScreen: AnyObject {
  var brightness: CGFloat { get set }
}
extension UIScreen: BrightnessScreen {}

final class AmberLightBridge {
  weak var window: UIWindow?
  private var originalBrightness: CGFloat?
  private var originalIdleTimer: Bool?
  private var active = false
  private var foreground = false
  private var shield: UIView?
  private let preferences = UserDefaults.standard
  private let screenProvider: (() -> BrightnessScreen?)?
  private var screen: BrightnessScreen? { screenProvider?() ?? window?.windowScene?.screen }

  init(screenProvider: (() -> BrightnessScreen?)? = nil) {
    self.screenProvider = screenProvider
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "openPrivacyPolicy":
      guard let url = URL(string: "https://yangwagongjuren-ship-it.github.io/amber-night-support/privacy.html") else {
        result(false); return
      }
      UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
    case "clock":
      var timebase = mach_timebase_info_data_t()
      mach_timebase_info(&timebase)
      let millis = Double(mach_continuous_time()) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000
      result(Int64(millis))
    case "loadSettings":
      result(preferences.dictionary(forKey: "amberNightSettings") ?? [:])
    case "saveSettings":
      guard let seconds = args["seconds"] as? Int, (1...9223372036854).contains(seconds),
        let brightness = args["brightness"] as? Double, brightness.isFinite,
        (0.02...1).contains(brightness), let language = args["language"] as? String,
        ["system", "en", "zh"].contains(language) else {
        result(FlutterError(code: "SETTINGS", message: "Invalid preferences", details: nil)); return
      }
      preferences.set(["seconds": seconds, "brightness": brightness, "language": language,
                       "introSeen": args["introSeen"] as? Bool ?? false], forKey: "amberNightSettings")
      result(nil)
    case "preview":
      guard let value = level(args) else {
        result(FlutterError(code: "LIGHT_CONTROL", message: "Invalid brightness", details: nil)); return
      }
      if foreground {
        captureBrightness()
        screen?.brightness = value
        removeShield()
      }
      result(nil)
    case "suspend":
      active = false
      releaseIdleTimer()
      restoreBrightness()
      // Keep the cover until Dart has painted the resumed scene.
      result(nil)
    case "begin":
      guard foreground, let screen = screen, let value = level(args) else {
        result(FlutterError(code: "LIGHT_CONTROL", message: "No active screen", details: nil)); return
      }
      captureBrightness()
      if originalIdleTimer == nil { originalIdleTimer = UIApplication.shared.isIdleTimerDisabled }
      screen.brightness = value
      UIApplication.shared.isIdleTimerDisabled = true
      active = true
      removeShield()
      result(nil)
    case "setBrightness":
      guard let value = level(args) else {
        result(FlutterError(code: "LIGHT_CONTROL", message: "Invalid brightness", details: nil)); return
      }
      if active && foreground { screen?.brightness = value }
      result(nil)
    case "release":
      active = false
      releaseIdleTimer()
      if args["keepDark"] as? Bool == true {
        if foreground {
          captureBrightness()
          screen?.brightness = 0.01
          removeShield()
        }
      } else {
        restoreBrightness()
        if foreground { removeShield() }
      }
      result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }
  private func level(_ args: [String: Any]) -> CGFloat? {
    guard let number = args["brightness"] as? Double, number.isFinite,
          (0...1).contains(number) else { return nil }
    return CGFloat(number)
  }
  private func captureBrightness() {
    if originalBrightness == nil { originalBrightness = screen?.brightness }
  }
  private func restoreBrightness() {
    if let value = originalBrightness { screen?.brightness = value }
    originalBrightness = nil
  }
  private func releaseIdleTimer() {
    if let previous = originalIdleTimer { UIApplication.shared.isIdleTimerDisabled = previous }
    originalIdleTimer = nil
  }
  private func removeShield() { shield?.removeFromSuperview(); shield = nil }
  func becameActive(window: UIWindow?) {
    self.window = window
    foreground = true
  }
  func resignActive() {
    if active || originalBrightness != nil {
      if shield == nil, let window = window {
        let cover = UIView(frame: window.bounds)
        cover.backgroundColor = .black
        cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(cover)
        shield = cover
      }
    }
    active = false
    foreground = false
    releaseIdleTimer()
    restoreBrightness()
  }
  func enteredBackground() {
    active = false
    foreground = false
    releaseIdleTimer()
    restoreBrightness()
  }
}
