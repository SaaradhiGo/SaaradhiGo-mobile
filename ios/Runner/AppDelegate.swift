import Flutter
import UIKit

// The Google Maps iOS SDK is deliberately not initialised here any more.
//
// This file used to `import GoogleMaps` and call
// `GMSServices.provideAPIKey("AIza...")` with the key as a literal. Three
// things were wrong with that:
//
//   1. The key was committed. It is the SAME key that was in
//      AndroidManifest.xml, present since the initial commit, so it is in git
//      history and must be treated as compromised. Removing it from HEAD does
//      not rotate it — see runbooks/maps-key-rotation.md.
//   2. Nothing used it. This app renders maps with `flutter_map` over OSM
//      tiles and has no `google_maps_flutter` dependency.
//   3. It could not have built. There is no GoogleMaps entry in ios/Podfile or
//      Podfile.lock, so `import GoogleMaps` has nothing to resolve against.
//
// If the Maps SDK is ever adopted on iOS, add the pod and supply the key
// through an xcconfig fed by a CI secret. Do not put it back in this file.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
