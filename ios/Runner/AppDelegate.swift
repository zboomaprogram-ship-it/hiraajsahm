import Flutter
import UIKit
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // ✅ Configure Firebase FIRST, before plugin registration
    // This prevents race condition crash (EXC_BAD_ACCESS)
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    
    // ✅ Then register plugins
    GeneratedPluginRegistrant.register(with: self)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
