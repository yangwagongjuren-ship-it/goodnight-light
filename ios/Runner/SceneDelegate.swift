import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var light: AmberLightBridge? { (UIApplication.shared.delegate as? AppDelegate)?.light }
  override func sceneDidBecomeActive(_ scene: UIScene) {
    light?.becameActive(window: window)
    super.sceneDidBecomeActive(scene)
  }
  override func sceneWillResignActive(_ scene: UIScene) {
    light?.resignActive()
    super.sceneWillResignActive(scene)
  }
  override func sceneDidEnterBackground(_ scene: UIScene) {
    light?.enteredBackground()
    super.sceneDidEnterBackground(scene)
  }
}
