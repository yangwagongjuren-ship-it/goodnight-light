import Flutter
import UIKit
import XCTest
@testable import Runner

private final class TestScreen: BrightnessScreen {
  var brightness: CGFloat = 0.75
}

final class RunnerTests: XCTestCase {
  func testPreviewAndLifecycleRestoreOriginalBrightness() {
    let screen = TestScreen()
    let bridge = AmberLightBridge(screenProvider: { screen })
    let previousIdleTimer = UIApplication.shared.isIdleTimerDisabled
    defer { UIApplication.shared.isIdleTimerDisabled = previousIdleTimer }
    bridge.becameActive(window: nil)
    invoke(bridge, "preview", ["brightness": 0.4])
    XCTAssertEqual(screen.brightness, 0.4, accuracy: 0.001)
    XCTAssertEqual(UIApplication.shared.isIdleTimerDisabled, previousIdleTimer)
    invoke(bridge, "begin", ["brightness": 0.2])
    invoke(bridge, "setBrightness", ["brightness": 0.03])
    XCTAssertEqual(screen.brightness, 0.03, accuracy: 0.001)
    bridge.resignActive()
    XCTAssertEqual(screen.brightness, 0.75, accuracy: 0.001)
    XCTAssertEqual(UIApplication.shared.isIdleTimerDisabled, previousIdleTimer)
    bridge.enteredBackground()
    bridge.becameActive(window: nil)
    XCTAssertEqual(screen.brightness, 0.75, accuracy: 0.001)
    invoke(bridge, "begin", ["brightness": 0.1])
    invoke(bridge, "release", ["keepDark": true])
    XCTAssertEqual(screen.brightness, 0.01, accuracy: 0.001)
    bridge.resignActive()
    XCTAssertEqual(screen.brightness, 0.75, accuracy: 0.001)
    bridge.becameActive(window: nil)
    invoke(bridge, "release", ["keepDark": false])
    XCTAssertEqual(screen.brightness, 0.75, accuracy: 0.001)
  }

  func testPreviewOnlyAndRepeatedSuspendDoNotCaptureMinimumBrightness() {
    let screen = TestScreen()
    let bridge = AmberLightBridge(screenProvider: { screen })
    bridge.becameActive(window: nil)
    invoke(bridge, "preview", ["brightness": 0.04])
    bridge.resignActive()
    invoke(bridge, "suspend")
    invoke(bridge, "setBrightness", ["brightness": 0.01])
    XCTAssertEqual(screen.brightness, 0.75, accuracy: 0.001)
    screen.brightness = 0.6
    bridge.becameActive(window: nil)
    invoke(bridge, "begin", ["brightness": 0.12])
    bridge.resignActive()
    XCTAssertEqual(screen.brightness, 0.6, accuracy: 0.001)
  }

  private func invoke(_ bridge: AmberLightBridge, _ method: String, _ args: [String: Any] = [:]) {
    var replied = false
    bridge.handle(FlutterMethodCall(methodName: method, arguments: args)) { result in
      XCTAssertNil(result)
      replied = true
    }
    XCTAssertTrue(replied)
  }
}
