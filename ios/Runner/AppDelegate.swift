import Flutter
import UIKit
import FirebaseCore
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // ✅ Configure Firebase FIRST, before plugin registration
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    
    // ✅ Register Google Maps
    GMSServices.provideAPIKey("AIzaSyDl5bO63kW9ukQkEEyqdg40oSFh1R8mOSM")
    
    // ✅ Then register plugins
    GeneratedPluginRegistrant.register(with: self)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
