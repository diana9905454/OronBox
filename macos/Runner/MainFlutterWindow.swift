import Cocoa
import FlutterMacOS
import desktop_multi_window
import window_manager

class MainFlutterWindow: NSWindow {
  private var rfcommChannel: MacOSRfcommChannel?
  private var miAccountTwoFactorChannel: MacOSMiAccountTwoFactorChannel?
  private var zeppSettingsChannel: MacOSZeppSettingsChannel?

  override func awakeFromNib() {
    let noGui = ProcessInfo.processInfo.arguments.contains("--nogui")
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
    }
    rfcommChannel = MacOSRfcommChannel(
      messenger: flutterViewController.engine.binaryMessenger
    )
    miAccountTwoFactorChannel = MacOSMiAccountTwoFactorChannel(
      messenger: flutterViewController.engine.binaryMessenger,
      parentWindow: self
    )
    zeppSettingsChannel = MacOSZeppSettingsChannel(
      messenger: flutterViewController.engine.binaryMessenger,
      parentWindow: self
    )

    let fileChannel = FlutterMethodChannel(
      name: "oronbox/file_open",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    fileChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getInitialFile":
        result(AppDelegate.activateFileOpenDelivery())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    AppDelegate.fileOpenChannel = fileChannel

    let windowChannel = FlutterMethodChannel(
      name: "oronbox/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    windowChannel.setMethodCallHandler { call, result in
      guard call.method == "setIcon" else {
        result(FlutterMethodNotImplemented); return
      }
      guard let encoded = call.arguments as? String,
            let data = Data(base64Encoded: encoded),
            let image = NSImage(data: data) else {
        result(FlutterError(code: "INVALID_ICON", message: "Invalid icon data", details: nil)); return
      }
      let canvas = NSImage(size: NSSize(width: 1024, height: 1024))
      canvas.lockFocus()
      NSGraphicsContext.current?.imageInterpolation = .high
      let side = 840.0
      image.draw(
        in: NSRect(x: (1024.0 - side) / 2.0, y: (1024.0 - side) / 2.0, width: side, height: side),
        from: NSRect(origin: .zero, size: image.size),
        operation: .copy,
        fraction: 1.0
      )
      canvas.unlockFocus()
      NSApp.applicationIconImage = canvas
      result(nil)
    }

    super.awakeFromNib()
    if noGui {
      orderOut(nil)
    }
  }

  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
