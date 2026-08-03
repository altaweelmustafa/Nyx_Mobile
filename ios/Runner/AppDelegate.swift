import AVFAudio
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.brager/bluetooth",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "getConnectedDevice":
          result(AppDelegate.connectedAudioDevice())
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// AVAudioSession's current route already tells us the active audio
  /// output -- no Bluetooth pairing/scanning permission required. CarPlay
  /// shows up as its own port type; other car head units usually present
  /// as plain A2DP/HFP, so we fall back to a name heuristic for those.
  private static func connectedAudioDevice() -> [String: Any]? {
    let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
    guard let output = outputs.first(where: { isBluetoothOrCar($0.portType) }) else {
      return nil
    }
    return ["name": output.portName, "type": classify(output.portType, name: output.portName)]
  }

  private static func isBluetoothOrCar(_ portType: AVAudioSession.Port) -> Bool {
    switch portType {
    case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .carAudio:
      return true
    default:
      return false
    }
  }

  private static func classify(_ portType: AVAudioSession.Port, name: String) -> String {
    if portType == .carAudio { return "car" }
    let lower = name.lowercased()
    if lower.contains("car") || lower.contains("auto") || lower.contains("carplay") {
      return "car"
    }
    if lower.contains("speaker") || lower.contains("boom") || lower.contains("soundbar")
      || lower.contains("home")
    {
      return "speaker"
    }
    return "headphones"
  }
}
