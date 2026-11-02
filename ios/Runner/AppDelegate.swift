import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Whether the Google Maps SDK got a key at launch (see below).
  private var mapsConfigured = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps SDK for iOS (customer address pin, driver and live order
    // maps): the key is Info.plist's `GMSApiKey`, filled from the git-ignored
    // ios/Flutter/Secrets.xcconfig, and given to the SDK before any map can
    // be created. It's never logged. Without a key the SDK isn't initialised
    // and would raise as soon as a map is created, so the app asks
    // `com.quickmandi/maps_config` first and shows a placeholder instead
    // (`maps_availability.dart`); nothing else is affected.
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !key.isEmpty, !key.hasPrefix("$(") {
      GMSServices.provideAPIKey(key)
      mapsConfigured = true
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Occasion-driven home-screen icon (`app_icon_channel.dart`) — switches
    // among the alternate icons declared in Info.plist's `CFBundleIcons`.
    // `name` is one of those keys ("festiveGold"/"festiveRed") or nil to
    // revert to the primary (Asset Catalog) icon.
    // Whether maps can be shown (true only once the SDK has a key).
    let mapsRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "MapsConfigChannel")
    let mapsChannel = FlutterMethodChannel(name: "com.quickmandi/maps_config", binaryMessenger: mapsRegistrar!.messenger())
    mapsChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "isConfigured" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.mapsConfigured ?? false)
    }

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppIconChannel")
    let channel = FlutterMethodChannel(
      name: "com.quickmandi/app_icon",
      binaryMessenger: registrar!.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "setIcon" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let name = (call.arguments as? [String: Any])?["name"] as? String
      guard UIApplication.shared.supportsAlternateIcons else {
        result(nil)
        return
      }
      UIApplication.shared.setAlternateIconName(name) { error in
        if let error = error {
          result(FlutterError(code: "SET_ICON_FAILED", message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    }
  }
}
