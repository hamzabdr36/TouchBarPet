import AppKit
import PockKit

/// Pock widget entry point (Info.plist NSPrincipalClass = "Cat.CatWidget").
public final class CatWidget: NSObject, PKWidget {
    public var identifier: NSTouchBarItem.Identifier = NSTouchBarItem.Identifier("com.local.pock.Cat")
    public var customizationLabel: String = "Cat"
    public var view: NSView!

    public required override init() {
        super.init()
        view = CatView(bundle: Bundle(for: CatWidget.self))
    }

    public func viewDidAppear() { (view as? CatView)?.start() }
    public func viewWillDisappear() { (view as? CatView)?.stop() }
}
