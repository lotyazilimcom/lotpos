import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private static let savedWindowStateKey = "flutter.patisyov10.window_state.v1"
  private static let preferredLaunchPixelSize = NSSize(width: 3456, height: 2234)

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    let windowFrame = initialWindowFrame()
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }

  private func initialWindowFrame() -> NSRect {
    guard isFirstMacOSLaunch, let screen = launchScreen else {
      return self.frame
    }

    let visibleFrame = screen.visibleFrame
    let screenFrameInPixels = screen.convertRectToBacking(screen.frame)
    let targetFitsDisplay =
      screenFrameInPixels.size.width >= Self.preferredLaunchPixelSize.width &&
      screenFrameInPixels.size.height >= Self.preferredLaunchPixelSize.height

    guard targetFitsDisplay else {
      return visibleFrame
    }

    let scaleFactor = max(screen.backingScaleFactor, 1)
    let targetSize = NSSize(
      width: Self.preferredLaunchPixelSize.width / scaleFactor,
      height: Self.preferredLaunchPixelSize.height / scaleFactor
    )

    guard targetSize.width <= visibleFrame.width, targetSize.height <= visibleFrame.height else {
      return visibleFrame
    }

    return NSRect(
      x: visibleFrame.midX - (targetSize.width / 2),
      y: visibleFrame.midY - (targetSize.height / 2),
      width: targetSize.width,
      height: targetSize.height
    )
  }

  private var isFirstMacOSLaunch: Bool {
    UserDefaults.standard.object(forKey: "flutter.\(Self.savedWindowStateKey)") == nil
  }

  private var launchScreen: NSScreen? {
    self.screen ?? NSScreen.main ?? NSScreen.screens.first
  }
}
