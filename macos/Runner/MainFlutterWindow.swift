import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Fully borderless + transparent window for a desktop pet.
    // - .borderless drops the titled theme frame, so there is NO white highlight
    //   hairline at the top (that highlight cannot be removed on titled windows).
    // - Clearing BOTH the window and the FlutterViewController backgrounds is
    //   required since Flutter 3.7, otherwise transparent content renders black.
    self.styleMask = [.borderless]
    self.isOpaque = false
    self.backgroundColor = NSColor.clear
    self.hasShadow = false
    flutterViewController.backgroundColor = NSColor.clear

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  // Borderless windows cannot become key/main by default; allow it so the pet
  // still receives mouse (and future keyboard) events reliably.
  override var canBecomeKey: Bool { return true }
  override var canBecomeMain: Bool { return true }
}
