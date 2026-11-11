import Flutter
import GoogleMaps
import UIKit

// The Google Maps iOS SDK (owner decision D1, 2026-11-02).
//
// The key is NOT written here. It comes from the `GMSApiKey` entry in
// Info.plist, which is `$(MAPS_API_KEY)`: an xcconfig value fed by a CI secret
// and restricted in Google Cloud to this app's bundle ID. The literal key that
// used to sit in this file is in git history and must stay revoked (see
// runbooks/maps-key-rotation.md); do not put any key back here.
//
// With no key supplied the app still starts; the map simply has no tiles.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var hasMapsKey = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
      !key.isEmpty, !key.hasPrefix("$(")
    {
      GMSServices.provideAPIKey(key)
      hasMapsKey = true
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // The app draws its branded placeholder map unless a key was built in.
    let channel = FlutterMethodChannel(
      name: "saaradhigo/maps",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "hasKey" { result(self?.hasMapsKey ?? false) } else { result(FlutterMethodNotImplemented) }
    }
  }
}
