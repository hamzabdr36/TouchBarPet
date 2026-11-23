import AppKit
import PockKit

/// Settings page shown in Pock → Preferences → Widgets → Cat.
/// Built in code (no nib); Pock creates it with init(nibName:bundle:) and we supply the view in loadView().
public final class CatPreferencePane: NSViewController, PKWidgetPreference {
    public static var nibName: NSNib.Name = "CatPreferencePane"

    private let defaults = UserDefaults.standard
    private let napPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let personality = NSSegmentedControl(labels: ["Lazy", "Normal", "Playful"], trackingMode: .selectOne, target: nil, action: nil)
    private let speedSlider = NSSlider(value: 1, minValue: 0.5, maxValue: 1.5, target: nil, action: nil)
    private let speedLabel = NSTextField(labelWithString: "100%")
    private let typing = NSButton(checkboxWithTitle: "Swat and dash off when I type fast", target: nil, action: nil)
    private let hearts = NSButton(checkboxWithTitle: "Show hearts when I tap it", target: nil, action: nil)
    private let zzz = NSButton(checkboxWithTitle: "Show \u{201C}z\u{201D}s while it naps", target: nil, action: nil)

    public override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 320))
        preferredContentSize = root.frame.size

        // Header: kitten icon + title
        let icon = NSImageView()
        icon.imageScaling = .scaleProportionallyUpOrDown
        if let cg = CatSprites(bundle: Bundle(for: CatPreferencePane.self)).frame("idle", 0)?.cropping(to: CGRect(x: 20, y: 14, width: 40, height: 36)) {
            let img = NSImage(cgImage: cg, size: NSSize(width: 40, height: 36))
            icon.image = img
        }
        icon.wantsLayer = true
        icon.layer?.magnificationFilter = .nearest
        icon.widthAnchor.constraint(equalToConstant: 48).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 44).isActive = true
        let title = NSTextField(labelWithString: "Cat")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "Changes apply to your Touch Bar right away.")
        subtitle.textColor = .secondaryLabelColor
        let titles = NSStackView(views: [title, subtitle]); titles.orientation = .vertical; titles.alignment = .leading; titles.spacing = 2
        let header = NSStackView(views: [icon, titles]); header.spacing = 12; header.alignment = .centerY

        // Controls
        for c in CatSettings.napChoices { napPopUp.addItem(withTitle: c.title) }
        napPopUp.target = self; napPopUp.action = #selector(napChanged)
        personality.target = self; personality.action = #selector(personalityChanged)
        speedSlider.target = self; speedSlider.action = #selector(speedChanged)
        speedSlider.isContinuous = true
        speedSlider.widthAnchor.constraint(equalToConstant: 180).isActive = true
        speedLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let speedRow = NSStackView(views: [speedSlider, speedLabel]); speedRow.spacing = 8
        [typing, hearts, zzz].forEach { $0.target = self; $0.action = #selector(toggleChanged(_:)) }
        let toggles = NSStackView(views: [typing, hearts, zzz]); toggles.orientation = .vertical; toggles.alignment = .leading; toggles.spacing = 6

        let grid = NSGridView(views: [
            [label("Nap after I'm idle for:"), napPopUp],
            [label("Personality:"), personality],
            [label("Walking speed:"), speedRow],
            [label("Reactions:"), toggles]
        ])
        grid.rowSpacing = 12; grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.row(at: 3).yPlacement = .top

        let reset = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetTapped))
        let credit = NSTextField(labelWithString: "Kitten sprites by Mattz Art.")
        credit.textColor = .tertiaryLabelColor
        credit.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let footer = NSStackView(views: [credit, NSView(), reset]); footer.distribution = .fill

        let stack = NSStackView(views: [header, grid, footer])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48)
        ])
        view = root
        refresh()
    }

    private func label(_ s: String) -> NSTextField { NSTextField(labelWithString: s) }

    private func refresh() {
        let s = CatSettings.load(from: defaults)
        let idx = CatSettings.napChoices.firstIndex { $0.seconds == s.idleSeconds } ?? 2
        napPopUp.selectItem(at: idx)
        personality.selectedSegment = s.personality.rawValue
        speedSlider.doubleValue = s.speed
        speedLabel.stringValue = "\(Int((s.speed * 100).rounded()))%"
        typing.state = s.typingReaction ? .on : .off
        hearts.state = s.hearts ? .on : .off
        zzz.state = s.zzz ? .on : .off
    }

    @objc private func napChanged() {
        let i = max(0, napPopUp.indexOfSelectedItem)
        defaults.set(CatSettings.napChoices[i].seconds, forKey: CatSettings.Key.idleSeconds)
    }
    @objc private func personalityChanged() { defaults.set(personality.selectedSegment, forKey: CatSettings.Key.personality) }
    @objc private func speedChanged() {
        let v = (speedSlider.doubleValue * 20).rounded() / 20
        defaults.set(v, forKey: CatSettings.Key.speed)
        speedLabel.stringValue = "\(Int((v * 100).rounded()))%"
    }
    @objc private func toggleChanged(_ sender: NSButton) {
        let key = sender === typing ? CatSettings.Key.typingReaction : (sender === hearts ? CatSettings.Key.hearts : CatSettings.Key.zzz)
        defaults.set(sender.state == .on, forKey: key)
    }
    @objc private func resetTapped() { CatSettings.reset(defaults); refresh() }
}
