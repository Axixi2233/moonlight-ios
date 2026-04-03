import SwiftUI
import UIKit

private func StreamMenuLocalized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func StreamMenuLocalizedFormat(_ key: String, _ args: CVarArg...) -> String {
    String(format: StreamMenuLocalized(key), locale: Locale.current, arguments: args)
}

private final class EdgeIgnoringHostingController<Content: View>: UIHostingController<Content> {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.insetsLayoutMarginsFromSafeArea = false
        viewRespectsSystemMinimumLayoutMargins = false
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()

        if view.responds(to: Selector(("_setSafeAreaInsets:"))) {
            view.perform(Selector(("_setSafeAreaInsets:")), with: NSValue(uiEdgeInsets: .zero))
        }
    }
}

@objcMembers
final class StreamActionSheetItem: NSObject {
    var identifier: String = ""
    var title: String = ""
    var subtitle: String = ""
    var symbolName: String = "circle"
    var destructive: Bool = false
}

@objc protocol StreamActionSheetHostingViewControllerDelegate: NSObjectProtocol {
    func streamActionSheetHostingViewController(_ controller: StreamActionSheetHostingViewController, didSelectActionWithIdentifier identifier: String)
    func streamActionSheetHostingViewControllerDidCancel(_ controller: StreamActionSheetHostingViewController)
    func streamActionSheetHostingViewController(_ controller: StreamActionSheetHostingViewController, didChangeTouchModeSelection selection: Int)
    func streamActionSheetHostingViewController(_ controller: StreamActionSheetHostingViewController, didChangeVideoAlignmentSelection selection: Int)
    func streamActionSheetHostingViewController(_ controller: StreamActionSheetHostingViewController, didChangeVideoAlignmentMargin margin: Double)
    func streamActionSheetHostingViewController(_ controller: StreamActionSheetHostingViewController, didChangeExtendedPerformanceMetricsEnabled enabled: Bool)
    func streamActionSheetHostingViewController(_ controller: StreamActionSheetHostingViewController, didChangePerformanceOverlayPositionSelection selection: Int)
    func streamActionSheetHostingViewController(_ controller: StreamActionSheetHostingViewController, didChangePerformanceOverlayMargin margin: Double)
    func streamActionSheetHostingViewController(_ controller: StreamActionSheetHostingViewController, didChangeAudioHapticsEnabled enabled: Bool)
    func streamActionSheetHostingViewController(_ controller: StreamActionSheetHostingViewController, didChangeAudioHapticsOutputTarget selection: Int)
    func streamActionSheetHostingViewController(_ controller: StreamActionSheetHostingViewController, didChangeAudioHapticsStrength strength: Double)
    func streamActionSheetHostingViewController(_ controller: StreamActionSheetHostingViewController, didChangeAudioHapticsVoiceFilterSelection selection: Int)
    func streamActionSheetHostingViewController(_ controller: StreamActionSheetHostingViewController, didChangeAudioHapticsKeepControllerRumble enabled: Bool)
}

@objcMembers
final class StreamShortcutPanelItem: NSObject {
    var identifier: String = ""
    var title: String = ""
    var subtitle: String = ""
    var symbolName: String = "command"
    var deletable: Bool = false
}

@objc protocol StreamShortcutPanelHostingViewControllerDelegate: NSObjectProtocol {
    func streamShortcutPanelHostingViewControllerDidCancel(_ controller: StreamShortcutPanelHostingViewController)
    func streamShortcutPanelHostingViewController(_ controller: StreamShortcutPanelHostingViewController, didSelectItemWithIdentifier identifier: String)
    func streamShortcutPanelHostingViewController(_ controller: StreamShortcutPanelHostingViewController, didSubmitItemWithTitle title: String, keyLabels: [String], keyCodes: [NSNumber])
    func streamShortcutPanelHostingViewController(_ controller: StreamShortcutPanelHostingViewController, didDeleteItemWithIdentifier identifier: String)
}

@objc protocol StreamVirtualKeyboardPanelHostingViewControllerDelegate: NSObjectProtocol {
    func streamVirtualKeyboardPanelHostingViewControllerDidCancel(_ controller: StreamVirtualKeyboardPanelHostingViewController)
    func streamVirtualKeyboardPanelHostingViewController(_ controller: StreamVirtualKeyboardPanelHostingViewController, didSubmitKeyCodes keyCodes: [NSNumber])
    func streamVirtualKeyboardPanelHostingViewControllerDidRequestSystemKeyboard(_ controller: StreamVirtualKeyboardPanelHostingViewController)
}

@objcMembers
final class StreamVirtualButtonPanelItem: NSObject {
    var identifier: String = ""
    var title: String = ""
    var subtitle: String = ""
    var shape: String = "roundedRect"
    var scale: NSNumber = 1.0
    var widthScale: NSNumber = 1.0
    var heightScale: NSNumber = 1.0
}

@objc protocol StreamVirtualButtonsPanelHostingViewControllerDelegate: NSObjectProtocol {
    func streamVirtualButtonsPanelHostingViewControllerDidCancel(_ controller: StreamVirtualButtonsPanelHostingViewController)
    func streamVirtualButtonsPanelHostingViewController(_ controller: StreamVirtualButtonsPanelHostingViewController, didChangeEditingEnabled enabled: Bool)
    func streamVirtualButtonsPanelHostingViewController(_ controller: StreamVirtualButtonsPanelHostingViewController, didDeleteItemWithIdentifier identifier: String)
    func streamVirtualButtonsPanelHostingViewController(_ controller: StreamVirtualButtonsPanelHostingViewController, didSubmitItemWithTitle title: String, keyLabels: [String], keyCodes: [NSNumber])
    func streamVirtualButtonsPanelHostingViewController(_ controller: StreamVirtualButtonsPanelHostingViewController, didSubmitMouseItemWithTitle title: String, mouseActionIdentifier: String, subtitle: String)
    func streamVirtualButtonsPanelHostingViewController(_ controller: StreamVirtualButtonsPanelHostingViewController, didSubmitDirectionalItemWithTitle title: String, controlActionIdentifier: String, subtitle: String)
    func streamVirtualButtonsPanelHostingViewController(_ controller: StreamVirtualButtonsPanelHostingViewController, didUpdateItemWithIdentifier identifier: String, shape: String, scale: Double, widthScale: Double, heightScale: Double)
    func streamVirtualButtonsPanelHostingViewController(_ controller: StreamVirtualButtonsPanelHostingViewController, didChangeButtonOpacity opacity: Double)
}

private final class StreamActionSheetViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var items: [StreamActionSheetItem] = []
    @Published var weekdayText: String = ""
    @Published var dateText: String = ""
    @Published var timeText: String = ""
    @Published var batteryText: String = "--%"
    @Published var touchModeSelection: Int = 0
    @Published var videoAlignmentSelection: Int = 0
    @Published var videoAlignmentMargin: Double = 0
    @Published var extendedPerformanceMetricsEnabled: Bool = false
    @Published var performanceOverlayPositionSelection: Int = 0
    @Published var performanceOverlayMargin: Double = 0
    @Published var audioHapticsEnabled: Bool = false
    @Published var audioHapticsOutputTargetSelection: Int = 0
    @Published var audioHapticsStrength: Double = 100
    @Published var audioHapticsVoiceFilterSelection: Int = 0
    @Published var audioHapticsKeepControllerRumble: Bool = false
    @Published var isShowingPerformanceOverlayPositionPicker: Bool = false
    @Published var touchModeToastText: String? = nil
}

private final class StreamShortcutPanelViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var builtInItems: [StreamShortcutPanelItem] = []
    @Published var customItems: [StreamShortcutPanelItem] = []
    @Published var listSelection: Int = 0
    @Published var isAddingItem: Bool = false
    @Published var draftTitle: String = ""
    @Published var fnModeEnabled: Bool = false
    @Published var selectedKeyLabels: [String] = []
    @Published var selectedKeyCodes: [NSNumber] = []
}

private final class StreamVirtualKeyboardPanelViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var combinationModeEnabled: Bool = false
    @Published var fnModeEnabled: Bool = false
    @Published var selectedModifierKeyCodes: Set<Int> = []
}

private final class StreamVirtualButtonsPanelViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var items: [StreamVirtualButtonPanelItem] = []
    @Published var isAddingItem: Bool = false
    @Published var isEditingEnabled: Bool = false
    @Published var buttonOpacity: Double = 0.52
    @Published var draftTitle: String = ""
    @Published var fnModeEnabled: Bool = false
    @Published var selectedKeyLabels: [String] = []
    @Published var selectedKeyCodes: [NSNumber] = []
    @Published var isShowingMousePicker: Bool = false
    @Published var isShowingTouchpadPicker: Bool = false
    @Published var isShowingDirectionalPicker: Bool = false
}

private struct StreamVirtualMouseSelectableItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let assetName: String
    let symbol: String
}

private struct StreamVirtualDirectionalSelectableItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
}

private struct StreamVirtualButtonSelectableKey: Identifiable, Hashable {
    let id: String
    let label: String
    let keyCode: Int
    let altLabel: String?
    let altKeyCode: Int?
    let widthUnits: CGFloat
}

private struct SegmentedOptionsControl: UIViewRepresentable {
    let items: [String]
    let selection: Int
    let fontSize: CGFloat
    let onSelectionChange: (Int) -> Void

    init(items: [String], selection: Int, fontSize: CGFloat = 14, onSelectionChange: @escaping (Int) -> Void) {
        self.items = items
        self.selection = selection
        self.fontSize = fontSize
        self.onSelectionChange = onSelectionChange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectionChange: onSelectionChange)
    }

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = selection
        control.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        control.selectedSegmentTintColor = UIColor(red: 0.50, green: 0.45, blue: 0.94, alpha: 1.0)
        control.setTitleTextAttributes([
            .foregroundColor: UIColor.white.withAlphaComponent(0.72),
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        ], for: .normal)
        control.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        ], for: .selected)
        control.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        return control
    }

    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        uiView.selectedSegmentIndex = selection
    }

    final class Coordinator: NSObject {
        private let onSelectionChange: (Int) -> Void

        init(onSelectionChange: @escaping (Int) -> Void) {
            self.onSelectionChange = onSelectionChange
        }

        @objc func valueChanged(_ sender: UISegmentedControl) {
            onSelectionChange(sender.selectedSegmentIndex)
        }
    }
}

private struct StreamActionSheetPanelView: View {
    @ObservedObject var viewModel: StreamActionSheetViewModel
    let isLandscape: Bool
    let onSelect: (String) -> Void
    let onTouchModeChange: (Int) -> Void
    let onVideoAlignmentChange: (Int) -> Void
    let onVideoAlignmentMarginChange: (Double) -> Void
    let onExtendedPerformanceMetricsChange: (Bool) -> Void
    let onPerformanceOverlayPositionChange: (Int) -> Void
    let onPerformanceOverlayMarginChange: (Double) -> Void
    let onAudioHapticsEnabledChange: (Bool) -> Void
    let onAudioHapticsOutputTargetChange: (Int) -> Void
    let onAudioHapticsStrengthChange: (Double) -> Void
    let onAudioHapticsVoiceFilterSelectionChange: (Int) -> Void
    let onAudioHapticsKeepControllerRumbleChange: (Bool) -> Void
    let onCancel: () -> Void

    private let horizontalPadding: CGFloat = 20
    private let cardSpacing: CGFloat = 10
    private let cardHeight: CGFloat = 96

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(geometry.size.width - horizontalPadding * 2, 0)
            let minCardWidth: CGFloat = isLandscape ? 112 : 104
            let columns = max(Int((contentWidth + cardSpacing) / (minCardWidth + cardSpacing)), 1)
            let normalizedColumns = min(columns, max(viewModel.items.count, 1))
            let cardWidth = max(floor((contentWidth - CGFloat(max(normalizedColumns - 1, 0)) * cardSpacing) / CGFloat(normalizedColumns)), 88)
            let rows = chunkedItems(columnCount: normalizedColumns)

            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.top, 22)
                        .padding(.bottom, 18)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 18) {
                            ForEach(0..<rows.count, id: \.self) { rowIndex in
                                HStack(spacing: cardSpacing) {
                                    ForEach(0..<rows[rowIndex].count, id: \.self) { itemIndex in
                                        let item = rows[rowIndex][itemIndex]
                                        StreamActionSheetCardView(item: item,
                                                                  width: cardWidth,
                                                                  height: cardHeight) {
                                            onSelect(item.identifier)
                                        }
                                    }

                                    if rows[rowIndex].count < normalizedColumns {
                                        ForEach(0..<(normalizedColumns - rows[rowIndex].count), id: \.self) { _ in
                                            Color.clear
                                                .frame(width: cardWidth, height: cardHeight)
                                        }
                                    }
                                }
                            }

                            touchModeSection
                            audioHapticsSection
                            videoAlignmentSection
                            videoAlignmentMarginSection
                            extendedPerformanceMetricsSection
                            performanceOverlayPositionSection
                            performanceOverlayMarginSection
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, 20)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)

                if let toastText = viewModel.touchModeToastText {
                    Text(toastText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.62))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.20), radius: 10, x: 0, y: 4)
                        .padding(.top, 14)
                }
            }
        }
    }

    private var header: some View {
        Group {
            if isLandscape {
                HStack(alignment: .center, spacing: 14) {
                    Text(viewModel.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    metadataRow

                    Spacer(minLength: 12)

                    closeButton
                }
            }
            else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Text(viewModel.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Spacer(minLength: 12)

                        closeButton
                    }

                    metadataRow
                }
            }
        }
    }

    private var metadataRow: some View {
        HStack(alignment: .center, spacing: 10) {
            metadataItem(icon: "calendar", text: viewModel.weekdayText)
            metadataItem(icon: nil, text: viewModel.dateText)
            metadataItem(icon: "clock", text: viewModel.timeText)
            metadataItem(icon: "battery.100.circle", text: viewModel.batteryText)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(Color.white.opacity(0.72))
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }

    private var closeButton: some View {
        Button(action: onCancel) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.82))
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func metadataItem(icon: String?, text: String) -> some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
            }

            Text(text)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var touchModeSection: some View {
        let items: [(icon: String, title: String)] = [
            ("hand.draw", StreamMenuLocalized("stream.touch_mode.trackpad")),
            ("cursorarrow.motionlines", StreamMenuLocalized("stream.touch_mode.mouse")),
            ("hand.point.up.left.and.text", StreamMenuLocalized("stream.touch_mode.multitouch")),
            ("hand.raised.slash", StreamMenuLocalized("stream.touch_mode.disabled"))
        ]

        return VStack(alignment: .leading, spacing: 10) {
            Text(StreamMenuLocalized("stream.touch_mode.title"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.72))

            HStack(spacing: 8) {
                touchModeButton(index: 0, icon: items[0].icon, title: items[0].title)
                touchModeButton(index: 1, icon: items[1].icon, title: items[1].title)
                touchModeButton(index: 2, icon: items[2].icon, title: items[2].title)
                touchModeButton(index: 3, icon: items[3].icon, title: items[3].title)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func touchModeButton(index: Int, icon: String, title: String) -> some View {
        let isSelected = viewModel.touchModeSelection == index

        return Button(action: {
            guard !isSelected else {
                return
            }
            viewModel.touchModeSelection = index
            onTouchModeChange(index)
        }) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(isSelected ? 0.18 : 0.10))
                    )

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ?
                          Color(red: 0.50, green: 0.45, blue: 0.94) :
                          Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.0 : 0.10), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var videoAlignmentSection: some View {
        let labels = [
            StreamMenuLocalized("settings.video_alignment.top"),
            StreamMenuLocalized("settings.video_alignment.center"),
            StreamMenuLocalized("settings.video_alignment.bottom")
        ]
        let displayedSelection: Int
        switch viewModel.videoAlignmentSelection {
            case 1:
                displayedSelection = 0
            case 0:
                displayedSelection = 1
            default:
                displayedSelection = 2
        }

        return VStack(alignment: .leading, spacing: 10) {
            Text(StreamMenuLocalized("stream.video_alignment.title"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.72))

            SegmentedOptionsControl(items: labels,
                                    selection: displayedSelection) { newValue in
                let actualSelection: Int
                switch newValue {
                    case 0:
                        actualSelection = 1
                    case 1:
                        actualSelection = 0
                    default:
                        actualSelection = 2
                }

                guard viewModel.videoAlignmentSelection != actualSelection else {
                    return
                }
                viewModel.videoAlignmentSelection = actualSelection
                onVideoAlignmentChange(actualSelection)
            }
            .frame(height: 38)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var videoAlignmentMarginSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(StreamMenuLocalizedFormat("stream.video_alignment_margin.label", Int(viewModel.videoAlignmentMargin)))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.72))

            Slider(value: Binding(get: {
                viewModel.videoAlignmentMargin
            }, set: { newValue in
                let steppedValue = Double(Int(newValue.rounded()))
                guard viewModel.videoAlignmentMargin != steppedValue else {
                    return
                }
                viewModel.videoAlignmentMargin = steppedValue
                onVideoAlignmentMarginChange(steppedValue)
            }), in: 0...150, step: 1)
            .accentColor(Color(red: 0.50, green: 0.45, blue: 0.94))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var extendedPerformanceMetricsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(StreamMenuLocalized("stream.performance.title"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.72))

            Toggle(isOn: Binding(get: {
                viewModel.extendedPerformanceMetricsEnabled
            }, set: { newValue in
                guard viewModel.extendedPerformanceMetricsEnabled != newValue else {
                    return
                }
                viewModel.extendedPerformanceMetricsEnabled = newValue
                onExtendedPerformanceMetricsChange(newValue)
            })) {
                Text(StreamMenuLocalized("stream.performance.extended_metrics.toggle"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .accentColor(Color(red: 0.50, green: 0.45, blue: 0.94))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var audioHapticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(StreamMenuLocalized("stream.audio_haptics.title"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.72))

            Toggle(isOn: Binding(get: {
                viewModel.audioHapticsEnabled
            }, set: { newValue in
                guard viewModel.audioHapticsEnabled != newValue else {
                    return
                }
                viewModel.audioHapticsEnabled = newValue
                onAudioHapticsEnabledChange(newValue)
            })) {
                Text(StreamMenuLocalized("stream.audio_haptics.enable_toggle"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .accentColor(Color(red: 0.50, green: 0.45, blue: 0.94))

            if viewModel.audioHapticsEnabled {
                audioHapticsOutputTargetSection
                audioHapticsStrengthSection
                audioHapticsVoiceFilterSection

                if viewModel.audioHapticsOutputTargetSelection == 1 {
                    Toggle(isOn: Binding(get: {
                        viewModel.audioHapticsKeepControllerRumble
                    }, set: { newValue in
                        guard viewModel.audioHapticsKeepControllerRumble != newValue else {
                            return
                        }
                        viewModel.audioHapticsKeepControllerRumble = newValue
                        onAudioHapticsKeepControllerRumbleChange(newValue)
                    })) {
                        Text(StreamMenuLocalized("settings.audio_haptics.keep_controller_rumble"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .accentColor(Color(red: 0.50, green: 0.45, blue: 0.94))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var audioHapticsOutputTargetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(StreamMenuLocalized("settings.audio_haptics.output_target"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.72))

            SegmentedOptionsControl(items: [
                StreamMenuLocalized("common.device"),
                StreamMenuLocalized("common.controller")
            ], selection: viewModel.audioHapticsOutputTargetSelection) { newValue in
                guard viewModel.audioHapticsOutputTargetSelection != newValue else {
                    return
                }
                viewModel.audioHapticsOutputTargetSelection = newValue
                onAudioHapticsOutputTargetChange(newValue)
            }
            .frame(height: 38)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var audioHapticsStrengthSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(StreamMenuLocalizedFormat("settings.audio_haptics.strength", Int(viewModel.audioHapticsStrength.rounded())))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.72))

            Slider(value: Binding(get: {
                viewModel.audioHapticsStrength
            }, set: { newValue in
                let steppedValue = Double(Int((newValue / 5.0).rounded()) * 5)
                guard viewModel.audioHapticsStrength != steppedValue else {
                    return
                }
                viewModel.audioHapticsStrength = steppedValue
                onAudioHapticsStrengthChange(steppedValue)
            }), in: 25...200, step: 5)
            .accentColor(Color(red: 0.50, green: 0.45, blue: 0.94))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var audioHapticsVoiceFilterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(StreamMenuLocalized("settings.audio_haptics.voice_filter"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.72))

            SegmentedOptionsControl(items: [
                StreamMenuLocalized("common.off"),
                StreamMenuLocalized("settings.audio_haptics.voice_filter.low"),
                StreamMenuLocalized("settings.audio_haptics.voice_filter.medium"),
                StreamMenuLocalized("settings.audio_haptics.voice_filter.high")
            ], selection: viewModel.audioHapticsVoiceFilterSelection, fontSize: 12) { newValue in
                guard viewModel.audioHapticsVoiceFilterSelection != newValue else {
                    return
                }
                viewModel.audioHapticsVoiceFilterSelection = newValue
                onAudioHapticsVoiceFilterSelectionChange(newValue)
            }
            .frame(height: 38)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var performanceOverlayPositionSection: some View {
        let items = [
            (title: StreamMenuLocalized("settings.performance_overlay_position.top_left"), actualSelection: 1),
            (title: StreamMenuLocalized("settings.performance_overlay_position.top_center"), actualSelection: 0),
            (title: StreamMenuLocalized("settings.performance_overlay_position.top_right"), actualSelection: 2),
            (title: StreamMenuLocalized("settings.performance_overlay_position.bottom_left"), actualSelection: 4),
            (title: StreamMenuLocalized("settings.performance_overlay_position.bottom_center"), actualSelection: 3),
            (title: StreamMenuLocalized("settings.performance_overlay_position.bottom_right"), actualSelection: 5)
        ]
        let selectedTitle = items.first(where: { $0.actualSelection == viewModel.performanceOverlayPositionSelection })?.title ?? items[0].title

        return HStack(alignment: .center, spacing: 12) {
            Text(StreamMenuLocalized("settings.performance_overlay_position.title"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: {
                viewModel.isShowingPerformanceOverlayPositionPicker = true
            }) {
                HStack(spacing: 10) {
                    Text(selectedTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.72))
                }
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
            }
            .frame(maxWidth: 220)
            .buttonStyle(PlainButtonStyle())
            .actionSheet(isPresented: Binding(get: {
                viewModel.isShowingPerformanceOverlayPositionPicker
            }, set: { newValue in
                viewModel.isShowingPerformanceOverlayPositionPicker = newValue
            })) {
                ActionSheet(title: Text(StreamMenuLocalized("settings.performance_overlay_position.title")),
                            buttons: items.map { item in
                    .default(Text(item.title)) {
                        guard viewModel.performanceOverlayPositionSelection != item.actualSelection else {
                            return
                        }
                        viewModel.performanceOverlayPositionSelection = item.actualSelection
                        onPerformanceOverlayPositionChange(item.actualSelection)
                    }
                } + [.cancel(Text(StreamMenuLocalized("common.cancel")))])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var performanceOverlayMarginSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(StreamMenuLocalizedFormat("settings.performance_overlay_margin.label", Int(viewModel.performanceOverlayMargin)))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.72))

            Slider(value: Binding(get: {
                viewModel.performanceOverlayMargin
            }, set: { newValue in
                let steppedValue = Double(Int(newValue.rounded()))
                guard viewModel.performanceOverlayMargin != steppedValue else {
                    return
                }
                viewModel.performanceOverlayMargin = steppedValue
                onPerformanceOverlayMarginChange(steppedValue)
            }), in: 0...150, step: 1)
            .accentColor(Color(red: 0.50, green: 0.45, blue: 0.94))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chunkedItems(columnCount: Int) -> [[StreamActionSheetItem]] {
        guard columnCount > 0 else {
            return []
        }

        var result: [[StreamActionSheetItem]] = []
        var currentIndex = 0

        while currentIndex < viewModel.items.count {
            let endIndex = min(currentIndex + columnCount, viewModel.items.count)
            result.append(Array(viewModel.items[currentIndex..<endIndex]))
            currentIndex = endIndex
        }

        return result
    }
}

private struct StreamActionSheetCardView: View {
    let item: StreamActionSheetItem
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(item.destructive ? 0.14 : 0.09))
                        .frame(width: 42, height: 42)

                    Image(systemName: item.symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(item.destructive ? Color(red: 0.96, green: 0.46, blue: 0.46) : .white)
                }

                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(item.destructive ? 0.10 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(item.destructive ? 0.14 : 0.09), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct StreamShortcutPanelView: View {
    @ObservedObject var viewModel: StreamShortcutPanelViewModel
    let isLandscape: Bool
    let onSelect: (String) -> Void
    let onSubmit: (String, [String], [NSNumber]) -> Void
    let onDelete: (String) -> Void
    let onCancel: () -> Void

    private let horizontalPadding: CGFloat = 18
    private let verticalSpacing: CGFloat = 12
    private let horizontalSpacing: CGFloat = 12
    private let cardHeight: CGFloat = 88
    private let maxSelectedKeys = 5

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 18)

                if viewModel.isAddingItem {
                    addForm(in: geometry)
                } else {
                    listContent(in: geometry)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(viewModel.isAddingItem ? StreamMenuLocalized("stream.shortcuts.add_title") : viewModel.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 12)

            if !viewModel.isAddingItem {
                compactShortcutListSelector

                Button(action: beginAdding) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.82))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func listContent(in geometry: GeometryProxy) -> some View {
        let columnCount = isLandscape ? 5 : 3
        let contentWidth = max(geometry.size.width - horizontalPadding * 2, 0)
        let cardWidth = max(floor((contentWidth - CGFloat(columnCount - 1) * horizontalSpacing) / CGFloat(columnCount)), 88)
        let rows = chunkedItems(columnCount: columnCount)

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: verticalSpacing) {
                if displayedItems.isEmpty {
                    emptyState
                } else {
                    ForEach(0..<rows.count, id: \.self) { rowIndex in
                        HStack(spacing: horizontalSpacing) {
                            ForEach(0..<rows[rowIndex].count, id: \.self) { itemIndex in
                                let item = rows[rowIndex][itemIndex]
                                StreamShortcutCardView(item: item,
                                                       width: cardWidth,
                                                       height: cardHeight,
                                                       onDelete: item.deletable ? {
                                                           onDelete(item.identifier)
                                                       } : nil) {
                                    onSelect(item.identifier)
                                }
                            }

                            if rows[rowIndex].count < columnCount {
                                ForEach(0..<(columnCount - rows[rowIndex].count), id: \.self) { _ in
                                    Color.clear
                                        .frame(width: cardWidth, height: cardHeight)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 20)
        }
    }

    private var compactShortcutListSelector: some View {
        SegmentedOptionsControl(items: [StreamMenuLocalized("stream.shortcuts.segment.builtin"),
                                        StreamMenuLocalized("stream.shortcuts.segment.custom")],
                                selection: viewModel.listSelection,
                                fontSize: 12) { selection in
            viewModel.listSelection = selection
        }
        .frame(width: 122, height: 28)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "command.square")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.78))

            Text(viewModel.listSelection == 0 ? StreamMenuLocalized("stream.shortcuts.empty_builtin_title") : StreamMenuLocalized("stream.shortcuts.empty_custom_title"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text(viewModel.listSelection == 0 ? StreamMenuLocalized("stream.shortcuts.empty_builtin_message") : StreamMenuLocalized("stream.shortcuts.empty_custom_message"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func addForm(in geometry: GeometryProxy) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(StreamMenuLocalized("stream.shortcuts.name"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.72))

                    TextField(StreamMenuLocalized("stream.shortcuts.name_placeholder"), text: Binding(get: {
                        viewModel.draftTitle
                    }, set: { newValue in
                        viewModel.draftTitle = String(newValue.prefix(18))
                    }))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(StreamMenuLocalizedFormat("stream.shortcuts.selected_keys", viewModel.selectedKeyCodes.count, maxSelectedKeys))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.72))

                    if viewModel.selectedKeyLabels.isEmpty {
                        Text(StreamMenuLocalized("stream.shortcuts.selected_keys_hint"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.62))
                            .padding(.vertical, 4)
                    } else {
                        selectedKeyWrap
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(StreamMenuLocalized("stream.shortcuts.choose_keys"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.72))

                    HStack(spacing: 10) {
                        modeChip(title: StreamMenuLocalized("stream.shortcuts.fn_mode"),
                                 isActive: viewModel.fnModeEnabled,
                                 activeColor: Color(red: 0.33, green: 0.68, blue: 0.24)) {
                            viewModel.fnModeEnabled.toggle()
                        }

                        Spacer(minLength: 0)
                    }

                    selectableKeyboard(in: geometry)
                }

                HStack(spacing: 12) {
                    Button(action: cancelAdding) {
                        Text(StreamMenuLocalized("common.cancel"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: submitDraft) {
                        Text(StreamMenuLocalized("stream.virtual_buttons.save"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(canSubmitDraft ? Color(red: 0.50, green: 0.45, blue: 0.94) : Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!canSubmitDraft)
                    .opacity(canSubmitDraft ? 1.0 : 0.7)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 20)
        }
    }

    private func selectableKeyboard(in geometry: GeometryProxy) -> some View {
        let contentWidth = max(geometry.size.width - horizontalPadding * 2, 0)
        let rowSpacing: CGFloat = 8
        let keySpacing: CGFloat = 8
        let rowHeight: CGFloat = 38
        let rows = selectableKeyRows

        return VStack(spacing: rowSpacing) {
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                let row = rows[rowIndex]
                let totalUnits = max(row.reduce(CGFloat.zero) { $0 + $1.widthUnits }, 1)
                let unitWidth = max((contentWidth - CGFloat(max(row.count - 1, 0)) * keySpacing) / totalUnits, 24)

                HStack(spacing: keySpacing) {
                    ForEach(row) { key in
                        virtualKeyButton(key: key,
                                         width: max(unitWidth * key.widthUnits, 28),
                                         height: rowHeight)
                    }
                }
            }
        }
    }

    private var selectedKeyWrap: some View {
        let rows = chunkedSelectedKeys(columnCount: isLandscape ? 5 : 3)
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: 8) {
                    ForEach(rows[rowIndex], id: \.self) { keyLabel in
                        selectedKeyChip(label: keyLabel)
                    }
                }
            }
        }
    }

    private func selectedKeyChip(label: String) -> some View {
        Button(action: {
            removeSelectedKey(label: label)
        }) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.76))
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.10))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func modeChip(title: String,
                          isActive: Bool,
                          activeColor: Color,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? activeColor : Color.white.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(isActive ? 0.0 : 0.10), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func virtualKeyButton(key: StreamVirtualButtonSelectableKey, width: CGFloat, height: CGFloat) -> some View {
        let displayLabel = activeLabel(for: key)
        let isSelected = viewModel.selectedKeyLabels.contains(displayLabel)

        return Button(action: {
            appendSelectedKey(key)
        }) {
            Text(displayLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color(red: 0.50, green: 0.45, blue: 0.94) : Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(isSelected ? 0.0 : 0.10), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isSelected || viewModel.selectedKeyCodes.count >= maxSelectedKeys)
    }

    private var canSubmitDraft: Bool {
        !viewModel.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.selectedKeyCodes.isEmpty
    }

    private func beginAdding() {
        viewModel.isAddingItem = true
        viewModel.draftTitle = ""
        viewModel.fnModeEnabled = false
        viewModel.selectedKeyLabels = []
        viewModel.selectedKeyCodes = []
    }

    private func cancelAdding() {
        viewModel.isAddingItem = false
        viewModel.draftTitle = ""
        viewModel.fnModeEnabled = false
        viewModel.selectedKeyLabels = []
        viewModel.selectedKeyCodes = []
    }

    private func appendSelectedKey(_ key: StreamVirtualButtonSelectableKey) {
        let keyLabel = activeLabel(for: key)
        let keyCode = activeKeyCode(for: key)

        guard !viewModel.selectedKeyLabels.contains(keyLabel) else {
            return
        }
        guard viewModel.selectedKeyCodes.count < maxSelectedKeys else {
            return
        }
        viewModel.selectedKeyLabels.append(keyLabel)
        viewModel.selectedKeyCodes.append(NSNumber(value: keyCode))
    }

    private func removeSelectedKey(label: String) {
        guard let index = viewModel.selectedKeyLabels.firstIndex(of: label) else {
            return
        }
        viewModel.selectedKeyLabels.remove(at: index)
        if index < viewModel.selectedKeyCodes.count {
            viewModel.selectedKeyCodes.remove(at: index)
        }
    }

    private func submitDraft() {
        guard canSubmitDraft else {
            return
        }
        viewModel.listSelection = 1
        onSubmit(viewModel.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                 viewModel.selectedKeyLabels,
                 viewModel.selectedKeyCodes)
        cancelAdding()
    }

    private func activeLabel(for key: StreamVirtualButtonSelectableKey) -> String {
        if viewModel.fnModeEnabled, let altLabel = key.altLabel {
            return altLabel
        }
        return key.label
    }

    private func activeKeyCode(for key: StreamVirtualButtonSelectableKey) -> Int {
        if viewModel.fnModeEnabled, let altKeyCode = key.altKeyCode {
            return altKeyCode
        }
        return key.keyCode
    }

    private func chunkedItems(columnCount: Int) -> [[StreamShortcutPanelItem]] {
        let values = displayedItems
        guard columnCount > 0 else {
            return []
        }

        var result: [[StreamShortcutPanelItem]] = []
        var currentIndex = 0

        while currentIndex < values.count {
            let endIndex = min(currentIndex + columnCount, values.count)
            result.append(Array(values[currentIndex..<endIndex]))
            currentIndex = endIndex
        }

        return result
    }

    private var displayedItems: [StreamShortcutPanelItem] {
        viewModel.listSelection == 0 ? viewModel.builtInItems : viewModel.customItems
    }

    private func chunkedSelectedKeys(columnCount: Int) -> [[String]] {
        let values = viewModel.selectedKeyLabels
        guard columnCount > 0 else { return [] }
        var result: [[String]] = []
        var currentIndex = 0
        while currentIndex < values.count {
            let endIndex = min(currentIndex + columnCount, values.count)
            result.append(Array(values[currentIndex..<endIndex]))
            currentIndex = endIndex
        }
        return result
    }

    private var selectableKeyRows: [[StreamVirtualButtonSelectableKey]] {
        [
            [
                .init(id: "esc", label: "Esc", keyCode: 0x1B, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "1", label: "1", keyCode: 0x31, altLabel: "F1", altKeyCode: 0x70, widthUnits: 1.0),
                .init(id: "2", label: "2", keyCode: 0x32, altLabel: "F2", altKeyCode: 0x71, widthUnits: 1.0),
                .init(id: "3", label: "3", keyCode: 0x33, altLabel: "F3", altKeyCode: 0x72, widthUnits: 1.0),
                .init(id: "4", label: "4", keyCode: 0x34, altLabel: "F4", altKeyCode: 0x73, widthUnits: 1.0),
                .init(id: "5", label: "5", keyCode: 0x35, altLabel: "F5", altKeyCode: 0x74, widthUnits: 1.0),
                .init(id: "6", label: "6", keyCode: 0x36, altLabel: "F6", altKeyCode: 0x75, widthUnits: 1.0),
                .init(id: "7", label: "7", keyCode: 0x37, altLabel: "F7", altKeyCode: 0x76, widthUnits: 1.0),
                .init(id: "8", label: "8", keyCode: 0x38, altLabel: "F8", altKeyCode: 0x77, widthUnits: 1.0),
                .init(id: "9", label: "9", keyCode: 0x39, altLabel: "F9", altKeyCode: 0x78, widthUnits: 1.0),
                .init(id: "0", label: "0", keyCode: 0x30, altLabel: "F10", altKeyCode: 0x79, widthUnits: 1.0),
                .init(id: "minus", label: "-", keyCode: 0xBD, altLabel: "F11", altKeyCode: 0x7A, widthUnits: 1.0),
                .init(id: "equal", label: "=", keyCode: 0xBB, altLabel: "F12", altKeyCode: 0x7B, widthUnits: 1.0),
                .init(id: "tick", label: "`", keyCode: 0xC0, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "backspace", label: "⌫", keyCode: 0x08, altLabel: nil, altKeyCode: nil, widthUnits: 1.6)
            ],
            [
                .init(id: "tab", label: "Tab", keyCode: 0x09, altLabel: nil, altKeyCode: nil, widthUnits: 1.5),
                .init(id: "q", label: "Q", keyCode: 0x51, altLabel: "0", altKeyCode: 0x60, widthUnits: 1.0),
                .init(id: "w", label: "W", keyCode: 0x57, altLabel: "1", altKeyCode: 0x61, widthUnits: 1.0),
                .init(id: "e", label: "E", keyCode: 0x45, altLabel: "2", altKeyCode: 0x62, widthUnits: 1.0),
                .init(id: "r", label: "R", keyCode: 0x52, altLabel: "3", altKeyCode: 0x63, widthUnits: 1.0),
                .init(id: "t", label: "T", keyCode: 0x54, altLabel: "4", altKeyCode: 0x64, widthUnits: 1.0),
                .init(id: "y", label: "Y", keyCode: 0x59, altLabel: "5", altKeyCode: 0x65, widthUnits: 1.0),
                .init(id: "u", label: "U", keyCode: 0x55, altLabel: "6", altKeyCode: 0x66, widthUnits: 1.0),
                .init(id: "i", label: "I", keyCode: 0x49, altLabel: "Prt", altKeyCode: 0x2C, widthUnits: 1.0),
                .init(id: "o", label: "O", keyCode: 0x4F, altLabel: "Scr", altKeyCode: 0x91, widthUnits: 1.0),
                .init(id: "p", label: "P", keyCode: 0x50, altLabel: "Pause", altKeyCode: 0x13, widthUnits: 1.0),
                .init(id: "openBracket", label: "[", keyCode: 0xDB, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "closeBracket", label: "]", keyCode: 0xDD, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "backslash", label: "\\", keyCode: 0xDC, altLabel: nil, altKeyCode: nil, widthUnits: 1.5)
            ],
            [
                .init(id: "caps", label: "Caps", keyCode: 0x14, altLabel: nil, altKeyCode: nil, widthUnits: 1.75),
                .init(id: "a", label: "A", keyCode: 0x41, altLabel: "7", altKeyCode: 0x67, widthUnits: 1.0),
                .init(id: "s", label: "S", keyCode: 0x53, altLabel: "8", altKeyCode: 0x68, widthUnits: 1.0),
                .init(id: "d", label: "D", keyCode: 0x44, altLabel: "9", altKeyCode: 0x69, widthUnits: 1.0),
                .init(id: "f", label: "F", keyCode: 0x46, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "g", label: "G", keyCode: 0x47, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "h", label: "H", keyCode: 0x48, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "j", label: "J", keyCode: 0x4A, altLabel: "Ins", altKeyCode: 0x2D, widthUnits: 1.0),
                .init(id: "k", label: "K", keyCode: 0x4B, altLabel: "Home", altKeyCode: 0x24, widthUnits: 1.0),
                .init(id: "l", label: "L", keyCode: 0x4C, altLabel: "PgUp", altKeyCode: 0x21, widthUnits: 1.0),
                .init(id: "semicolon", label: ";", keyCode: 0xBA, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "quote", label: "'", keyCode: 0xDE, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "enter", label: "Enter", keyCode: 0x0D, altLabel: nil, altKeyCode: nil, widthUnits: 2.0)
            ],
            [
                .init(id: "leftShift", label: "Shift", keyCode: 0xA0, altLabel: nil, altKeyCode: nil, widthUnits: 1.75),
                .init(id: "z", label: "Z", keyCode: 0x5A, altLabel: "/", altKeyCode: 0x6F, widthUnits: 1.0),
                .init(id: "x", label: "X", keyCode: 0x58, altLabel: "*", altKeyCode: 0x6A, widthUnits: 1.0),
                .init(id: "c", label: "C", keyCode: 0x43, altLabel: "+", altKeyCode: 0x6B, widthUnits: 1.0),
                .init(id: "v", label: "V", keyCode: 0x56, altLabel: "-", altKeyCode: 0x6D, widthUnits: 1.0),
                .init(id: "b", label: "B", keyCode: 0x42, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "n", label: "N", keyCode: 0x4E, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "m", label: "M", keyCode: 0x4D, altLabel: "Del", altKeyCode: 0x2E, widthUnits: 1.0),
                .init(id: "comma", label: ",", keyCode: 0xBC, altLabel: "End", altKeyCode: 0x23, widthUnits: 1.0),
                .init(id: "period", label: ".", keyCode: 0xBE, altLabel: "PgDn", altKeyCode: 0x22, widthUnits: 1.0),
                .init(id: "slash", label: "/", keyCode: 0xBF, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "numLock", label: "NumLk", keyCode: 0x90, altLabel: "rShift", altKeyCode: 0xA1, widthUnits: 1.0),
                .init(id: "up", label: "↑", keyCode: 0x26, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "delete", label: "Del", keyCode: 0x2E, altLabel: nil, altKeyCode: nil, widthUnits: 1.0)
            ],
            [
                .init(id: "leftCtrl", label: "Ctrl", keyCode: 0xA2, altLabel: nil, altKeyCode: nil, widthUnits: 1.75),
                .init(id: "leftWin", label: "Win", keyCode: 0x5B, altLabel: nil, altKeyCode: nil, widthUnits: 1.25),
                .init(id: "leftAlt", label: "Alt", keyCode: 0xA4, altLabel: nil, altKeyCode: nil, widthUnits: 1.25),
                .init(id: "space", label: "Space", keyCode: 0x20, altLabel: nil, altKeyCode: nil, widthUnits: 5.25),
                .init(id: "rightAlt", label: "Alt", keyCode: 0xA5, altLabel: nil, altKeyCode: nil, widthUnits: 1.25),
                .init(id: "rightWin", label: "rWin", keyCode: 0x5C, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "left", label: "←", keyCode: 0x25, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "down", label: "↓", keyCode: 0x28, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "right", label: "→", keyCode: 0x27, altLabel: nil, altKeyCode: nil, widthUnits: 1.0)
            ]
        ]
    }
}

private struct StreamShortcutCardView: View {
    let item: StreamShortcutPanelItem
    let width: CGFloat
    let height: CGFloat
    let onDelete: (() -> Void)?
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                VStack(spacing: 0) {
                    Spacer(minLength: 8)

                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(colors: [
                                    Color.white.opacity(0.16),
                                    Color.white.opacity(0.08)
                                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 40, height: 40)

                        Image(systemName: item.symbolName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 3) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        if !item.subtitle.isEmpty {
                            Text(item.subtitle)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.72))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .padding(.top, 9)

                    Spacer(minLength: 10)
                }
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(colors: [
                                Color.white.opacity(0.11),
                                Color.white.opacity(0.06)
                            ], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.10), radius: 14, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(colors: [
                                Color.white.opacity(0.16),
                                Color.clear
                            ], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.96, green: 0.46, blue: 0.46))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 8)
                .padding(.trailing, 8)
            }
        }
    }
}

private struct StreamVirtualButtonsPanelView: View {
    @ObservedObject var viewModel: StreamVirtualButtonsPanelViewModel
    let isLandscape: Bool
    let onToggleEditing: (Bool) -> Void
    let onDelete: (String) -> Void
    let onUpdate: (String, String, Double, Double, Double) -> Void
    let onOpacityChange: (Double) -> Void
    let onSubmit: (String, [String], [NSNumber]) -> Void
    let onSubmitMouse: (String, String, String) -> Void
    let onSubmitDirectional: (String, String, String) -> Void
    let onCancel: () -> Void

    private let horizontalPadding: CGFloat = 18
    private let cardSpacing: CGFloat = 12
    private let maxSelectedKeys = 5
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                        .padding(.bottom, 16)

                    if viewModel.isAddingItem {
                        addForm(in: geometry)
                    } else {
                        listContent(in: geometry)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)

                if viewModel.isShowingMousePicker {
                    Color.black.opacity(0.36)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            viewModel.isShowingMousePicker = false
                        }

                    mouseButtonPickerOverlay(maxWidth: min(geometry.size.width - 40, 360))
                }

                if viewModel.isShowingTouchpadPicker {
                    Color.black.opacity(0.36)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            viewModel.isShowingTouchpadPicker = false
                        }

                    touchpadButtonPickerOverlay(maxWidth: min(geometry.size.width - 40, 360))
                }

                if viewModel.isShowingDirectionalPicker {
                    Color.black.opacity(0.36)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            viewModel.isShowingDirectionalPicker = false
                        }

                    directionalControlPickerOverlay(maxWidth: min(geometry.size.width - 40, 360))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(viewModel.isAddingItem ? StreamMenuLocalized("stream.virtual_buttons.add_title") : viewModel.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer(minLength: 12)

            if !viewModel.isAddingItem {
                Button(action: {
                    viewModel.isEditingEnabled.toggle()
                    onToggleEditing(viewModel.isEditingEnabled)
                }) {
                    Text(viewModel.isEditingEnabled ? StreamMenuLocalized("stream.virtual_buttons.finish_editing") : StreamMenuLocalized("stream.virtual_buttons.edit_mode"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(
                            Capsule()
                                .fill(viewModel.isEditingEnabled ? Color(red: 0.50, green: 0.45, blue: 0.94) : Color.white.opacity(0.08))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(viewModel.isEditingEnabled ? 0.0 : 0.10), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: beginAdding) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.82))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func listContent(in geometry: GeometryProxy) -> some View {
        let columnCount = isLandscape ? 4 : 3
        let contentWidth = max(geometry.size.width - horizontalPadding * 2, 0)
        let cardWidth = max(floor((contentWidth - CGFloat(columnCount - 1) * cardSpacing) / CGFloat(columnCount)), 120)
        let cardHeight = floor(cardWidth * 0.5)
        let rows = chunkedItems(columnCount: columnCount)

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(StreamMenuLocalized("stream.virtual_buttons.opacity"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.78))

                        Spacer(minLength: 8)

                        Text(String(format: "%.0f%%", viewModel.buttonOpacity * 100.0))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.66))
                    }

                    Slider(value: Binding(get: {
                        viewModel.buttonOpacity
                    }, set: { newValue in
                        viewModel.buttonOpacity = newValue
                        onOpacityChange(newValue)
                    }), in: 0.05...1.0, step: 0.05)
                    .accentColor(Color(red: 0.50, green: 0.45, blue: 0.94))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

                if viewModel.isEditingEnabled {
                    HStack(spacing: 10) {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.84))

                        Text(StreamMenuLocalized("stream.virtual_buttons.drag_hint"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.72))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                }

                if viewModel.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "keyboard.badge.ellipsis")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.78))

                        Text(StreamMenuLocalized("stream.virtual_buttons.empty_title"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Text(StreamMenuLocalized("stream.virtual_buttons.empty_message"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.68))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    ForEach(0..<rows.count, id: \.self) { rowIndex in
                        HStack(spacing: cardSpacing) {
                            ForEach(0..<rows[rowIndex].count, id: \.self) { itemIndex in
                                let item = rows[rowIndex][itemIndex]
                                StreamVirtualButtonCardView(item: item,
                                                            width: cardWidth,
                                                            height: cardHeight) {
                                    onDelete(item.identifier)
                                }
                            }

                            if rows[rowIndex].count < columnCount {
                                ForEach(0..<(columnCount - rows[rowIndex].count), id: \.self) { _ in
                                    Color.clear
                                        .frame(width: cardWidth, height: cardHeight)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 20)
        }
    }

    private func addForm(in geometry: GeometryProxy) -> some View {
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(StreamMenuLocalized("stream.virtual_buttons.name"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.72))

                    TextField(StreamMenuLocalized("stream.virtual_buttons.name_placeholder"), text: Binding(get: {
                        viewModel.draftTitle
                    }, set: { newValue in
                        viewModel.draftTitle = String(newValue.prefix(18))
                    }))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(StreamMenuLocalizedFormat("stream.shortcuts.selected_keys", viewModel.selectedKeyCodes.count, maxSelectedKeys))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.72))

                    if viewModel.selectedKeyLabels.isEmpty {
                        Text(StreamMenuLocalized("stream.shortcuts.selected_keys_hint"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.62))
                            .padding(.vertical, 4)
                    } else {
                        selectedKeyWrap
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(StreamMenuLocalized("stream.shortcuts.choose_keys"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.72))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            modeChip(title: StreamMenuLocalized("stream.shortcuts.fn_mode"),
                                     isActive: viewModel.fnModeEnabled,
                                     activeColor: Color(red: 0.33, green: 0.68, blue: 0.24)) {
                                viewModel.fnModeEnabled.toggle()
                            }

                            Button(action: {
                                viewModel.isShowingMousePicker = true
                            }) {
                                HStack(spacing: 6) {
                                    mousePickerIcon(for: selectableMouseItems[0], size: 13)
                                    Text(StreamMenuLocalized("stream.virtual_buttons.mouse_buttons"))
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                viewModel.isShowingTouchpadPicker = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "rectangle.roundedtop")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(StreamMenuLocalized("stream.virtual_buttons.touchpad_buttons"))
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                viewModel.isShowingDirectionalPicker = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "circle.grid.cross")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(StreamMenuLocalized("stream.virtual_buttons.directional_controls"))
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    selectableKeyboard(in: geometry)
                }

                HStack(spacing: 12) {
                    Button(action: cancelAdding) {
                        Text(StreamMenuLocalized("common.cancel"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: submitDraft) {
                        Text(StreamMenuLocalized("stream.virtual_buttons.save"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(canSubmitDraft ? Color(red: 0.50, green: 0.45, blue: 0.94) : Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!canSubmitDraft)
                    .opacity(canSubmitDraft ? 1.0 : 0.7)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 20)
        }
    }

    private func selectableKeyboard(in geometry: GeometryProxy) -> some View {
        let contentWidth = max(geometry.size.width - horizontalPadding * 2, 0)
        let rowSpacing: CGFloat = 8
        let keySpacing: CGFloat = 8
        let rowHeight: CGFloat = 38
        let rows = selectableKeyRows

        return VStack(spacing: rowSpacing) {
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                let row = rows[rowIndex]
                let totalUnits = max(row.reduce(CGFloat.zero) { $0 + $1.widthUnits }, 1)
                let unitWidth = max((contentWidth - CGFloat(max(row.count - 1, 0)) * keySpacing) / totalUnits, 24)

                HStack(spacing: keySpacing) {
                    ForEach(row) { key in
                        virtualKeyButton(key: key,
                                         width: max(unitWidth * key.widthUnits, 28),
                                         height: rowHeight)
                    }
                }
            }
        }
    }

    private var selectedKeyWrap: some View {
        let rows = chunkedSelectedKeys(columnCount: isLandscape ? 5 : 3)
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: 8) {
                    ForEach(rows[rowIndex], id: \.self) { keyLabel in
                        selectedKeyChip(label: keyLabel)
                    }
                }
            }
        }
    }

    private func selectedKeyChip(label: String) -> some View {
        Button(action: {
            removeSelectedKey(label: label)
        }) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.76))
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.10))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func modeChip(title: String,
                          isActive: Bool,
                          activeColor: Color,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? activeColor : Color.white.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(isActive ? 0.0 : 0.10), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func virtualKeyButton(key: StreamVirtualButtonSelectableKey, width: CGFloat, height: CGFloat) -> some View {
        let displayLabel = activeLabel(for: key)
        let isSelected = viewModel.selectedKeyLabels.contains(displayLabel)

        return Button(action: {
            appendSelectedKey(key)
        }) {
            Text(displayLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color(red: 0.50, green: 0.45, blue: 0.94) : Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(isSelected ? 0.0 : 0.10), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isSelected || viewModel.selectedKeyCodes.count >= maxSelectedKeys)
    }

    private var canSubmitDraft: Bool {
        !viewModel.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.selectedKeyCodes.isEmpty
    }

    private func beginAdding() {
        viewModel.isAddingItem = true
        if viewModel.isEditingEnabled {
            viewModel.isEditingEnabled = false
            onToggleEditing(false)
        }
        viewModel.draftTitle = ""
        viewModel.fnModeEnabled = false
        viewModel.selectedKeyLabels = []
        viewModel.selectedKeyCodes = []
    }

    private func cancelAdding() {
        viewModel.isAddingItem = false
        viewModel.draftTitle = ""
        viewModel.fnModeEnabled = false
        viewModel.selectedKeyLabels = []
        viewModel.selectedKeyCodes = []
        viewModel.isShowingMousePicker = false
        viewModel.isShowingTouchpadPicker = false
        viewModel.isShowingDirectionalPicker = false
    }

    private func appendSelectedKey(_ key: StreamVirtualButtonSelectableKey) {
        let keyLabel = activeLabel(for: key)
        let keyCode = activeKeyCode(for: key)

        guard !viewModel.selectedKeyLabels.contains(keyLabel) else {
            return
        }
        guard viewModel.selectedKeyCodes.count < maxSelectedKeys else {
            return
        }
        viewModel.selectedKeyLabels.append(keyLabel)
        viewModel.selectedKeyCodes.append(NSNumber(value: keyCode))
    }

    private func removeSelectedKey(label: String) {
        guard let index = viewModel.selectedKeyLabels.firstIndex(of: label) else {
            return
        }
        viewModel.selectedKeyLabels.remove(at: index)
        if index < viewModel.selectedKeyCodes.count {
            viewModel.selectedKeyCodes.remove(at: index)
        }
    }

    private func submitDraft() {
        guard canSubmitDraft else {
            return
        }
        onSubmit(viewModel.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                 viewModel.selectedKeyLabels,
                 viewModel.selectedKeyCodes)
        cancelAdding()
    }

    private func submitMouseDraft(item: StreamVirtualMouseSelectableItem) {
        let typedTitle = viewModel.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = typedTitle.isEmpty ? item.title : typedTitle
        onSubmitMouse(resolvedTitle, item.id, item.subtitle)
        cancelAdding()
    }

    private func submitTouchpadDraft(item: StreamVirtualMouseSelectableItem) {
        let typedTitle = viewModel.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = typedTitle.isEmpty ? item.title : typedTitle
        onSubmitMouse(resolvedTitle, item.id, item.subtitle)
        cancelAdding()
    }

    private func submitDirectionalDraft(item: StreamVirtualDirectionalSelectableItem) {
        let typedTitle = viewModel.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = typedTitle.isEmpty ? item.title : typedTitle
        onSubmitDirectional(resolvedTitle, item.id, item.subtitle)
        cancelAdding()
    }

    private func activeLabel(for key: StreamVirtualButtonSelectableKey) -> String {
        if viewModel.fnModeEnabled, let altLabel = key.altLabel {
            return altLabel
        }
        return key.label
    }

    private func activeKeyCode(for key: StreamVirtualButtonSelectableKey) -> Int {
        if viewModel.fnModeEnabled, let altKeyCode = key.altKeyCode {
            return altKeyCode
        }
        return key.keyCode
    }

    private func chunkedItems(columnCount: Int) -> [[StreamVirtualButtonPanelItem]] {
        guard columnCount > 0 else { return [] }
        var result: [[StreamVirtualButtonPanelItem]] = []
        var currentIndex = 0
        while currentIndex < viewModel.items.count {
            let endIndex = min(currentIndex + columnCount, viewModel.items.count)
            result.append(Array(viewModel.items[currentIndex..<endIndex]))
            currentIndex = endIndex
        }
        return result
    }

    private func chunkedSelectedKeys(columnCount: Int) -> [[String]] {
        let values = viewModel.selectedKeyLabels
        guard columnCount > 0 else { return [] }
        var result: [[String]] = []
        var currentIndex = 0
        while currentIndex < values.count {
            let endIndex = min(currentIndex + columnCount, values.count)
            result.append(Array(values[currentIndex..<endIndex]))
            currentIndex = endIndex
        }
        return result
    }

    private var selectableMouseItems: [StreamVirtualMouseSelectableItem] {
        [
            .init(id: "mouse_left", title: StreamMenuLocalized("stream.virtual_buttons.mouse.left"), subtitle: StreamMenuLocalized("stream.virtual_buttons.mouse.left_subtitle"), assetName: "ic_mouse_left", symbol: "cursorarrow.click"),
            .init(id: "mouse_left", title: StreamMenuLocalized("stream.virtual_buttons.mouse.left"), subtitle: StreamMenuLocalized("stream.virtual_buttons.mouse.left_subtitle"), assetName: "ic_mouse_left", symbol: "cursorarrow.click"),
            .init(id: "mouse_left_lock", title: StreamMenuLocalized("stream.virtual_buttons.mouse.left_lock"), subtitle: StreamMenuLocalized("stream.virtual_buttons.mouse.left_lock_subtitle"), assetName: "ic_mouse_left_p", symbol: "cursorarrow.click"),
            .init(id: "mouse_right", title: StreamMenuLocalized("stream.virtual_buttons.mouse.right"), subtitle: StreamMenuLocalized("stream.virtual_buttons.mouse.right_subtitle"), assetName: "ic_mouse_right", symbol: "cursorarrow.rays"),
            .init(id: "mouse_right_lock", title: StreamMenuLocalized("stream.virtual_buttons.mouse.right_lock"), subtitle: StreamMenuLocalized("stream.virtual_buttons.mouse.right_lock_subtitle"), assetName: "ic_mouse_right_p", symbol: "cursorarrow.rays"),
            .init(id: "mouse_middle", title: StreamMenuLocalized("stream.virtual_buttons.mouse.middle"), subtitle: StreamMenuLocalized("stream.virtual_buttons.mouse.middle_subtitle"), assetName: "ic_mouse_middle", symbol: "circle.grid.2x1"),
            .init(id: "mouse_scroll_up", title: StreamMenuLocalized("stream.virtual_buttons.mouse.scroll_up"), subtitle: StreamMenuLocalized("stream.virtual_buttons.mouse.scroll_up_subtitle"), assetName: "ic_mouse_scroll_up", symbol: "arrow.up.to.line"),
            .init(id: "mouse_scroll_down", title: StreamMenuLocalized("stream.virtual_buttons.mouse.scroll_down"), subtitle: StreamMenuLocalized("stream.virtual_buttons.mouse.scroll_down_subtitle"), assetName: "ic_mouse_scroll_down", symbol: "arrow.down.to.line")
        ]
    }

    private var selectableTouchpadItems: [StreamVirtualMouseSelectableItem] {
        [
            .init(id: "touchpad_move", title: StreamMenuLocalized("stream.virtual_buttons.touchpad.one"), subtitle: StreamMenuLocalized("stream.virtual_buttons.touchpad.one_subtitle"), assetName: "", symbol: "hand.draw"),
            .init(id: "touchpad_left_drag", title: StreamMenuLocalized("stream.virtual_buttons.touchpad.two"), subtitle: StreamMenuLocalized("stream.virtual_buttons.touchpad.two_subtitle"), assetName: "", symbol: "hand.tap"),
            .init(id: "touchpad_right_drag", title: StreamMenuLocalized("stream.virtual_buttons.touchpad.three"), subtitle: StreamMenuLocalized("stream.virtual_buttons.touchpad.three_subtitle"), assetName: "", symbol: "hand.point.up.left"),
            .init(id: "touchpad_tap_left", title: StreamMenuLocalized("stream.virtual_buttons.touchpad.four"), subtitle: StreamMenuLocalized("stream.virtual_buttons.touchpad.four_subtitle"), assetName: "", symbol: "hand.tap.fill")
        ]
    }

    private var selectableDirectionalItems: [StreamVirtualDirectionalSelectableItem] {
        [
            .init(id: "joystick_wasd", title: StreamMenuLocalized("stream.virtual_buttons.directional.joystick_wasd"), subtitle: StreamMenuLocalized("stream.virtual_buttons.directional.joystick_wasd_subtitle"), symbol: "circle.circle"),
            .init(id: "joystick_arrows", title: StreamMenuLocalized("stream.virtual_buttons.directional.joystick_arrows"), subtitle: StreamMenuLocalized("stream.virtual_buttons.directional.joystick_arrows_subtitle"), symbol: "circle.circle.fill"),
            .init(id: "dpad_wasd", title: StreamMenuLocalized("stream.virtual_buttons.directional.dpad_wasd"), subtitle: StreamMenuLocalized("stream.virtual_buttons.directional.dpad_wasd_subtitle"), symbol: "plus.square"),
            .init(id: "dpad_arrows", title: StreamMenuLocalized("stream.virtual_buttons.directional.dpad_arrows"), subtitle: StreamMenuLocalized("stream.virtual_buttons.directional.dpad_arrows_subtitle"), symbol: "plus.square.fill")
        ]
    }

    @ViewBuilder
    private func mousePickerIcon(for item: StreamVirtualMouseSelectableItem, size: CGFloat) -> some View {
        if let image = UIImage(named: item.assetName) {
            Image(uiImage: image)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: item.symbol)
                .font(.system(size: size * 0.72, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private func mouseButtonPickerOverlay(maxWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(StreamMenuLocalized("stream.virtual_buttons.add_mouse_title"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer(minLength: 8)

                Button(action: {
                    viewModel.isShowingMousePicker = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.82))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            Text(StreamMenuLocalized("stream.virtual_buttons.add_mouse_message"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.68))

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 10) {
                    ForEach(selectableMouseItems) { item in
                        Button(action: {
                            submitMouseDraft(item: item)
                        }) {
                            HStack(spacing: 12) {
                                mousePickerIcon(for: item, size: 18)
                                    .frame(width: 36, height: 36)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(item.subtitle)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color.white.opacity(0.66))
                                }

                                Spacer(minLength: 8)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.trailing, 2)
            }
            .frame(maxHeight: 280)
        }
        .padding(18)
        .frame(maxWidth: maxWidth)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.16, green: 0.16, blue: 0.18).opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.26), radius: 18, x: 0, y: 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func touchpadButtonPickerOverlay(maxWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(StreamMenuLocalized("stream.virtual_buttons.add_touchpad_title"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer(minLength: 8)

                Button(action: {
                    viewModel.isShowingTouchpadPicker = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.82))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            Text(StreamMenuLocalized("stream.virtual_buttons.add_touchpad_message"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.68))

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 10) {
                    ForEach(selectableTouchpadItems) { item in
                        Button(action: {
                            submitTouchpadDraft(item: item)
                        }) {
                            HStack(spacing: 12) {
                                mousePickerIcon(for: item, size: 18)
                                    .frame(width: 36, height: 36)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(item.subtitle)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color.white.opacity(0.66))
                                }

                                Spacer(minLength: 8)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.trailing, 2)
            }
            .frame(maxHeight: 280)
        }
        .padding(18)
        .frame(maxWidth: maxWidth)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.16, green: 0.16, blue: 0.18).opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.26), radius: 18, x: 0, y: 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func directionalControlPickerOverlay(maxWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(StreamMenuLocalized("stream.virtual_buttons.add_directional_title"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer(minLength: 8)

                Button(action: {
                    viewModel.isShowingDirectionalPicker = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.82))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            Text(StreamMenuLocalized("stream.virtual_buttons.add_directional_message"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.68))

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 10) {
                    ForEach(selectableDirectionalItems) { item in
                        Button(action: {
                            submitDirectionalDraft(item: item)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(item.subtitle)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color.white.opacity(0.66))
                                }

                                Spacer(minLength: 8)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.trailing, 2)
            }
            .frame(maxHeight: 280)
        }
        .padding(18)
        .frame(maxWidth: maxWidth)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.16, green: 0.16, blue: 0.18).opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.26), radius: 18, x: 0, y: 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var selectableKeyRows: [[StreamVirtualButtonSelectableKey]] {
        [
            [
                .init(id: "esc", label: "Esc", keyCode: 0x1B, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "1", label: "1", keyCode: 0x31, altLabel: "F1", altKeyCode: 0x70, widthUnits: 1.0),
                .init(id: "2", label: "2", keyCode: 0x32, altLabel: "F2", altKeyCode: 0x71, widthUnits: 1.0),
                .init(id: "3", label: "3", keyCode: 0x33, altLabel: "F3", altKeyCode: 0x72, widthUnits: 1.0),
                .init(id: "4", label: "4", keyCode: 0x34, altLabel: "F4", altKeyCode: 0x73, widthUnits: 1.0),
                .init(id: "5", label: "5", keyCode: 0x35, altLabel: "F5", altKeyCode: 0x74, widthUnits: 1.0),
                .init(id: "6", label: "6", keyCode: 0x36, altLabel: "F6", altKeyCode: 0x75, widthUnits: 1.0),
                .init(id: "7", label: "7", keyCode: 0x37, altLabel: "F7", altKeyCode: 0x76, widthUnits: 1.0),
                .init(id: "8", label: "8", keyCode: 0x38, altLabel: "F8", altKeyCode: 0x77, widthUnits: 1.0),
                .init(id: "9", label: "9", keyCode: 0x39, altLabel: "F9", altKeyCode: 0x78, widthUnits: 1.0),
                .init(id: "0", label: "0", keyCode: 0x30, altLabel: "F10", altKeyCode: 0x79, widthUnits: 1.0),
                .init(id: "minus", label: "-", keyCode: 0xBD, altLabel: "F11", altKeyCode: 0x7A, widthUnits: 1.0),
                .init(id: "equal", label: "=", keyCode: 0xBB, altLabel: "F12", altKeyCode: 0x7B, widthUnits: 1.0),
                .init(id: "tick", label: "`", keyCode: 0xC0, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "backspace", label: "⌫", keyCode: 0x08, altLabel: nil, altKeyCode: nil, widthUnits: 1.6)
            ],
            [
                .init(id: "tab", label: "Tab", keyCode: 0x09, altLabel: nil, altKeyCode: nil, widthUnits: 1.5),
                .init(id: "q", label: "Q", keyCode: 0x51, altLabel: "0", altKeyCode: 0x60, widthUnits: 1.0),
                .init(id: "w", label: "W", keyCode: 0x57, altLabel: "1", altKeyCode: 0x61, widthUnits: 1.0),
                .init(id: "e", label: "E", keyCode: 0x45, altLabel: "2", altKeyCode: 0x62, widthUnits: 1.0),
                .init(id: "r", label: "R", keyCode: 0x52, altLabel: "3", altKeyCode: 0x63, widthUnits: 1.0),
                .init(id: "t", label: "T", keyCode: 0x54, altLabel: "4", altKeyCode: 0x64, widthUnits: 1.0),
                .init(id: "y", label: "Y", keyCode: 0x59, altLabel: "5", altKeyCode: 0x65, widthUnits: 1.0),
                .init(id: "u", label: "U", keyCode: 0x55, altLabel: "6", altKeyCode: 0x66, widthUnits: 1.0),
                .init(id: "i", label: "I", keyCode: 0x49, altLabel: "Prt", altKeyCode: 0x2C, widthUnits: 1.0),
                .init(id: "o", label: "O", keyCode: 0x4F, altLabel: "Scr", altKeyCode: 0x91, widthUnits: 1.0),
                .init(id: "p", label: "P", keyCode: 0x50, altLabel: "Pause", altKeyCode: 0x13, widthUnits: 1.0),
                .init(id: "openBracket", label: "[", keyCode: 0xDB, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "closeBracket", label: "]", keyCode: 0xDD, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "backslash", label: "\\", keyCode: 0xDC, altLabel: nil, altKeyCode: nil, widthUnits: 1.5)
            ],
            [
                .init(id: "caps", label: "Caps", keyCode: 0x14, altLabel: nil, altKeyCode: nil, widthUnits: 1.75),
                .init(id: "a", label: "A", keyCode: 0x41, altLabel: "7", altKeyCode: 0x67, widthUnits: 1.0),
                .init(id: "s", label: "S", keyCode: 0x53, altLabel: "8", altKeyCode: 0x68, widthUnits: 1.0),
                .init(id: "d", label: "D", keyCode: 0x44, altLabel: "9", altKeyCode: 0x69, widthUnits: 1.0),
                .init(id: "f", label: "F", keyCode: 0x46, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "g", label: "G", keyCode: 0x47, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "h", label: "H", keyCode: 0x48, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "j", label: "J", keyCode: 0x4A, altLabel: "Ins", altKeyCode: 0x2D, widthUnits: 1.0),
                .init(id: "k", label: "K", keyCode: 0x4B, altLabel: "Home", altKeyCode: 0x24, widthUnits: 1.0),
                .init(id: "l", label: "L", keyCode: 0x4C, altLabel: "PgUp", altKeyCode: 0x21, widthUnits: 1.0),
                .init(id: "semicolon", label: ";", keyCode: 0xBA, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "quote", label: "'", keyCode: 0xDE, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "enter", label: "Enter", keyCode: 0x0D, altLabel: nil, altKeyCode: nil, widthUnits: 2.0)
            ],
            [
                .init(id: "leftShift", label: "Shift", keyCode: 0xA0, altLabel: nil, altKeyCode: nil, widthUnits: 1.75),
                .init(id: "z", label: "Z", keyCode: 0x5A, altLabel: "/", altKeyCode: 0x6F, widthUnits: 1.0),
                .init(id: "x", label: "X", keyCode: 0x58, altLabel: "*", altKeyCode: 0x6A, widthUnits: 1.0),
                .init(id: "c", label: "C", keyCode: 0x43, altLabel: "+", altKeyCode: 0x6B, widthUnits: 1.0),
                .init(id: "v", label: "V", keyCode: 0x56, altLabel: "-", altKeyCode: 0x6D, widthUnits: 1.0),
                .init(id: "b", label: "B", keyCode: 0x42, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "n", label: "N", keyCode: 0x4E, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "m", label: "M", keyCode: 0x4D, altLabel: "Del", altKeyCode: 0x2E, widthUnits: 1.0),
                .init(id: "comma", label: ",", keyCode: 0xBC, altLabel: "End", altKeyCode: 0x23, widthUnits: 1.0),
                .init(id: "period", label: ".", keyCode: 0xBE, altLabel: "PgDn", altKeyCode: 0x22, widthUnits: 1.0),
                .init(id: "slash", label: "/", keyCode: 0xBF, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "numLock", label: "NumLk", keyCode: 0x90, altLabel: "rShift", altKeyCode: 0xA1, widthUnits: 1.0),
                .init(id: "up", label: "↑", keyCode: 0x26, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "delete", label: "Del", keyCode: 0x2E, altLabel: nil, altKeyCode: nil, widthUnits: 1.0)
            ],
            [
                .init(id: "leftCtrl", label: "Ctrl", keyCode: 0xA2, altLabel: nil, altKeyCode: nil, widthUnits: 1.75),
                .init(id: "leftWin", label: "Win", keyCode: 0x5B, altLabel: nil, altKeyCode: nil, widthUnits: 1.25),
                .init(id: "leftAlt", label: "Alt", keyCode: 0xA4, altLabel: nil, altKeyCode: nil, widthUnits: 1.25),
                .init(id: "space", label: "Space", keyCode: 0x20, altLabel: nil, altKeyCode: nil, widthUnits: 5.25),
                .init(id: "rightAlt", label: "Alt", keyCode: 0xA5, altLabel: nil, altKeyCode: nil, widthUnits: 1.25),
                .init(id: "rightWin", label: "rWin", keyCode: 0x5C, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "left", label: "←", keyCode: 0x25, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "down", label: "↓", keyCode: 0x28, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "right", label: "→", keyCode: 0x27, altLabel: nil, altKeyCode: nil, widthUnits: 1.0)
            ]
        ]
    }
}

private struct StreamVirtualButtonCardView: View {
    let item: StreamVirtualButtonPanelItem
    let width: CGFloat
    let height: CGFloat
    let onDelete: () -> Void

    init(item: StreamVirtualButtonPanelItem,
         width: CGFloat,
         height: CGFloat,
         onDelete: @escaping () -> Void) {
        self.item = item
        self.width = width
        self.height = height
        self.onDelete = onDelete
    }

    var body: some View {
        let actualHeight = floor(width * 0.42)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(item.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.68))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.96, green: 0.46, blue: 0.46))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: width, height: actualHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(colors: [
                        Color.white.opacity(0.11),
                        Color.white.opacity(0.06)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipped()
    }
}

private struct StreamVirtualKeyboardKeyDefinition: Identifiable, Hashable {
    let id: String
    let baseLabel: String
    let baseKeyCode: Int
    let shiftLabel: String?
    let altLabel: String?
    let altKeyCode: Int?
    let widthUnits: CGFloat

    var activeKeyCode: Int {
        baseKeyCode
    }
}

private struct StreamVirtualKeyboardRowDefinition: Identifiable {
    let id: String
    let keys: [StreamVirtualKeyboardKeyDefinition]
}

private struct StreamVirtualKeyboardPanelView: View {
    @ObservedObject var viewModel: StreamVirtualKeyboardPanelViewModel
    let isLandscape: Bool
    let onSendKeyCodes: ([NSNumber]) -> Void
    let onShowSystemKeyboard: () -> Void
    let onCancel: () -> Void

    private let horizontalPadding: CGFloat = 16
    private let rowSpacing: CGFloat = 7
    private let keySpacing: CGFloat = 8
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var usesHorizontalKeyboardCanvas: Bool { !isLandscape && !isPad }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                VStack(spacing: 8) {
                    controlsRow

                    keyboardCanvas(in: geometry)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom * 0.5, 8))
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
    }

    @ViewBuilder
    private func keyboardCanvas(in geometry: GeometryProxy) -> some View {
        let availableWidth = max(geometry.size.width - horizontalPadding * 2, 0)
        let contentWidth = keyboardContentWidth(for: availableWidth)
        let rowHeight = keyboardRowHeight

        if usesHorizontalKeyboardCanvas {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: rowSpacing) {
                    ForEach(keyboardRows) { row in
                        keyboardRow(row,
                                    availableWidth: contentWidth,
                                    rowHeight: rowHeight)
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
            }
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: rowSpacing) {
                    ForEach(keyboardRows) { row in
                        keyboardRow(row,
                                    availableWidth: contentWidth,
                                    rowHeight: rowHeight)
                    }
                }
            }
        }
    }

    private var keyboardRowHeight: CGFloat {
        if isPad {
            return isLandscape ? 46 : 42
        }

        return isLandscape ? 44 : 38
    }

    private func keyboardContentWidth(for availableWidth: CGFloat) -> CGFloat {
        if usesHorizontalKeyboardCanvas {
            return max(availableWidth, 760)
        }

        return availableWidth
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(viewModel.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer(minLength: 12)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.82))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 10) {
            modeChip(title: StreamMenuLocalized("stream.virtual_keyboard.combination_mode"),
                     isActive: viewModel.combinationModeEnabled,
                     activeColor: Color(red: 0.36, green: 0.36, blue: 0.68)) {
                viewModel.combinationModeEnabled.toggle()
                if !viewModel.combinationModeEnabled {
                    viewModel.selectedModifierKeyCodes.removeAll()
                }
            }

            modeChip(title: StreamMenuLocalized("stream.shortcuts.fn_mode"),
                     isActive: viewModel.fnModeEnabled,
                     activeColor: Color(red: 0.33, green: 0.68, blue: 0.24)) {
                viewModel.fnModeEnabled.toggle()
            }

            modeChip(title: StreamMenuLocalized("stream.virtual_keyboard.system_keyboard"),
                     isActive: false,
                     activeColor: Color(red: 0.38, green: 0.58, blue: 0.94)) {
                onShowSystemKeyboard()
            }

            Spacer(minLength: 0)
        }
    }

    private func modeChip(title: String,
                          isActive: Bool,
                          activeColor: Color,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? activeColor : Color.white.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(isActive ? 0.0 : 0.10), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func keyboardRow(_ row: StreamVirtualKeyboardRowDefinition,
                             availableWidth: CGFloat,
                             rowHeight: CGFloat) -> some View {
        let totalUnits = max(row.keys.reduce(CGFloat.zero) { $0 + $1.widthUnits }, 1)
        let unitWidth = max((availableWidth - CGFloat(max(row.keys.count - 1, 0)) * keySpacing) / totalUnits, 28)

        return HStack(spacing: keySpacing) {
            ForEach(row.keys) { key in
                StreamVirtualKeyboardKeyView(key: key,
                                             width: max(unitWidth * key.widthUnits, 28),
                                             height: rowHeight,
                                             fnModeEnabled: viewModel.fnModeEnabled,
                                             isModifierSelected: viewModel.selectedModifierKeyCodes.contains(activeKeyCode(for: key)),
                                             action: {
                                                 handleTap(for: key)
                                             })
            }
        }
    }

    private func handleTap(for key: StreamVirtualKeyboardKeyDefinition) {
        let keyCode = activeKeyCode(for: key)

        if viewModel.combinationModeEnabled && modifierKeyCodes.contains(keyCode) {
            if viewModel.selectedModifierKeyCodes.contains(keyCode) {
                viewModel.selectedModifierKeyCodes.remove(keyCode)
            } else {
                viewModel.selectedModifierKeyCodes.insert(keyCode)
            }
            return
        }

        var keyCodes = Array(viewModel.selectedModifierKeyCodes).map { NSNumber(value: $0) }
        keyCodes.append(NSNumber(value: keyCode))
        onSendKeyCodes(keyCodes)

        if viewModel.combinationModeEnabled {
            viewModel.selectedModifierKeyCodes.removeAll()
        }
    }

    private func activeKeyCode(for key: StreamVirtualKeyboardKeyDefinition) -> Int {
        if viewModel.fnModeEnabled, let altKeyCode = key.altKeyCode {
            return altKeyCode
        }
        return key.baseKeyCode
    }

    private var modifierKeyCodes: Set<Int> {
        [0xA2, 0xA3, 0xA4, 0xA5, 0xA0, 0xA1, 0x5B, 0x5C, 0x90]
    }

    private var keyboardRows: [StreamVirtualKeyboardRowDefinition] {
        [
            StreamVirtualKeyboardRowDefinition(id: "row1", keys: [
                .init(id: "esc", baseLabel: "Esc", baseKeyCode: 0x1B, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "1", baseLabel: "1", baseKeyCode: 0x31, shiftLabel: "!", altLabel: "F1", altKeyCode: 0x70, widthUnits: 1.0),
                .init(id: "2", baseLabel: "2", baseKeyCode: 0x32, shiftLabel: "@", altLabel: "F2", altKeyCode: 0x71, widthUnits: 1.0),
                .init(id: "3", baseLabel: "3", baseKeyCode: 0x33, shiftLabel: "#", altLabel: "F3", altKeyCode: 0x72, widthUnits: 1.0),
                .init(id: "4", baseLabel: "4", baseKeyCode: 0x34, shiftLabel: "$", altLabel: "F4", altKeyCode: 0x73, widthUnits: 1.0),
                .init(id: "5", baseLabel: "5", baseKeyCode: 0x35, shiftLabel: "%", altLabel: "F5", altKeyCode: 0x74, widthUnits: 1.0),
                .init(id: "6", baseLabel: "6", baseKeyCode: 0x36, shiftLabel: "^", altLabel: "F6", altKeyCode: 0x75, widthUnits: 1.0),
                .init(id: "7", baseLabel: "7", baseKeyCode: 0x37, shiftLabel: "&", altLabel: "F7", altKeyCode: 0x76, widthUnits: 1.0),
                .init(id: "8", baseLabel: "8", baseKeyCode: 0x38, shiftLabel: "*", altLabel: "F8", altKeyCode: 0x77, widthUnits: 1.0),
                .init(id: "9", baseLabel: "9", baseKeyCode: 0x39, shiftLabel: "(", altLabel: "F9", altKeyCode: 0x78, widthUnits: 1.0),
                .init(id: "0", baseLabel: "0", baseKeyCode: 0x30, shiftLabel: ")", altLabel: "F10", altKeyCode: 0x79, widthUnits: 1.0),
                .init(id: "minus", baseLabel: "-", baseKeyCode: 0xBD, shiftLabel: "_", altLabel: "F11", altKeyCode: 0x7A, widthUnits: 1.0),
                .init(id: "equal", baseLabel: "=", baseKeyCode: 0xBB, shiftLabel: "+", altLabel: "F12", altKeyCode: 0x7B, widthUnits: 1.0),
                .init(id: "tick", baseLabel: "`", baseKeyCode: 0xC0, shiftLabel: "~", altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "backspace", baseLabel: "⌫", baseKeyCode: 0x08, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.6)
            ]),
            StreamVirtualKeyboardRowDefinition(id: "row2", keys: [
                .init(id: "tab", baseLabel: "Tab", baseKeyCode: 0x09, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.5),
                .init(id: "q", baseLabel: "Q", baseKeyCode: 0x51, shiftLabel: nil, altLabel: "0", altKeyCode: 0x60, widthUnits: 1.0),
                .init(id: "w", baseLabel: "W", baseKeyCode: 0x57, shiftLabel: nil, altLabel: "1", altKeyCode: 0x61, widthUnits: 1.0),
                .init(id: "e", baseLabel: "E", baseKeyCode: 0x45, shiftLabel: nil, altLabel: "2", altKeyCode: 0x62, widthUnits: 1.0),
                .init(id: "r", baseLabel: "R", baseKeyCode: 0x52, shiftLabel: nil, altLabel: "3", altKeyCode: 0x63, widthUnits: 1.0),
                .init(id: "t", baseLabel: "T", baseKeyCode: 0x54, shiftLabel: nil, altLabel: "4", altKeyCode: 0x64, widthUnits: 1.0),
                .init(id: "y", baseLabel: "Y", baseKeyCode: 0x59, shiftLabel: nil, altLabel: "5", altKeyCode: 0x65, widthUnits: 1.0),
                .init(id: "u", baseLabel: "U", baseKeyCode: 0x55, shiftLabel: nil, altLabel: "6", altKeyCode: 0x66, widthUnits: 1.0),
                .init(id: "i", baseLabel: "I", baseKeyCode: 0x49, shiftLabel: nil, altLabel: "Prt", altKeyCode: 0x2C, widthUnits: 1.0),
                .init(id: "o", baseLabel: "O", baseKeyCode: 0x4F, shiftLabel: nil, altLabel: "Scr", altKeyCode: 0x91, widthUnits: 1.0),
                .init(id: "p", baseLabel: "P", baseKeyCode: 0x50, shiftLabel: nil, altLabel: "Pause", altKeyCode: 0x13, widthUnits: 1.0),
                .init(id: "openBracket", baseLabel: "[", baseKeyCode: 0xDB, shiftLabel: "{", altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "closeBracket", baseLabel: "]", baseKeyCode: 0xDD, shiftLabel: "}", altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "backslash", baseLabel: "\\", baseKeyCode: 0xDC, shiftLabel: "|", altLabel: nil, altKeyCode: nil, widthUnits: 1.5)
            ]),
            StreamVirtualKeyboardRowDefinition(id: "row3", keys: [
                .init(id: "caps", baseLabel: "Caps", baseKeyCode: 0x14, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.75),
                .init(id: "a", baseLabel: "A", baseKeyCode: 0x41, shiftLabel: nil, altLabel: "7", altKeyCode: 0x67, widthUnits: 1.0),
                .init(id: "s", baseLabel: "S", baseKeyCode: 0x53, shiftLabel: nil, altLabel: "8", altKeyCode: 0x68, widthUnits: 1.0),
                .init(id: "d", baseLabel: "D", baseKeyCode: 0x44, shiftLabel: nil, altLabel: "9", altKeyCode: 0x69, widthUnits: 1.0),
                .init(id: "f", baseLabel: "F", baseKeyCode: 0x46, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "g", baseLabel: "G", baseKeyCode: 0x47, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "h", baseLabel: "H", baseKeyCode: 0x48, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "j", baseLabel: "J", baseKeyCode: 0x4A, shiftLabel: nil, altLabel: "Ins", altKeyCode: 0x2D, widthUnits: 1.0),
                .init(id: "k", baseLabel: "K", baseKeyCode: 0x4B, shiftLabel: nil, altLabel: "Home", altKeyCode: 0x24, widthUnits: 1.0),
                .init(id: "l", baseLabel: "L", baseKeyCode: 0x4C, shiftLabel: nil, altLabel: "PgUp", altKeyCode: 0x21, widthUnits: 1.0),
                .init(id: "semicolon", baseLabel: ";", baseKeyCode: 0xBA, shiftLabel: ":", altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "quote", baseLabel: "'", baseKeyCode: 0xDE, shiftLabel: "\"", altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "enter", baseLabel: "Enter", baseKeyCode: 0x0D, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 2.0)
            ]),
            StreamVirtualKeyboardRowDefinition(id: "row4", keys: [
                .init(id: "leftShift", baseLabel: "Shift", baseKeyCode: 0xA0, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.75),
                .init(id: "z", baseLabel: "Z", baseKeyCode: 0x5A, shiftLabel: nil, altLabel: "/", altKeyCode: 0x6F, widthUnits: 1.0),
                .init(id: "x", baseLabel: "X", baseKeyCode: 0x58, shiftLabel: nil, altLabel: "*", altKeyCode: 0x6A, widthUnits: 1.0),
                .init(id: "c", baseLabel: "C", baseKeyCode: 0x43, shiftLabel: nil, altLabel: "+", altKeyCode: 0x6B, widthUnits: 1.0),
                .init(id: "v", baseLabel: "V", baseKeyCode: 0x56, shiftLabel: nil, altLabel: "-", altKeyCode: 0x6D, widthUnits: 1.0),
                .init(id: "b", baseLabel: "B", baseKeyCode: 0x42, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "n", baseLabel: "N", baseKeyCode: 0x4E, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "m", baseLabel: "M", baseKeyCode: 0x4D, shiftLabel: nil, altLabel: "Del", altKeyCode: 0x2E, widthUnits: 1.0),
                .init(id: "comma", baseLabel: ",", baseKeyCode: 0xBC, shiftLabel: "<", altLabel: "End", altKeyCode: 0x23, widthUnits: 1.0),
                .init(id: "period", baseLabel: ".", baseKeyCode: 0xBE, shiftLabel: ">", altLabel: "PgDn", altKeyCode: 0x22, widthUnits: 1.0),
                .init(id: "slash", baseLabel: "/", baseKeyCode: 0xBF, shiftLabel: "?", altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "numLock", baseLabel: "NumLk", baseKeyCode: 0x90, shiftLabel: nil, altLabel: "rShift", altKeyCode: 0xA1, widthUnits: 1.0),
                .init(id: "up", baseLabel: "↑", baseKeyCode: 0x26, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "delete", baseLabel: "Del", baseKeyCode: 0x2E, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.0)
            ]),
            StreamVirtualKeyboardRowDefinition(id: "row5", keys: [
                .init(id: "leftCtrl", baseLabel: "Ctrl", baseKeyCode: 0xA2, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.75),
                .init(id: "leftWin", baseLabel: "Win", baseKeyCode: 0x5B, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.25),
                .init(id: "leftAlt", baseLabel: "Alt", baseKeyCode: 0xA4, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.25),
                .init(id: "space", baseLabel: "", baseKeyCode: 0x20, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 5.25),
                .init(id: "rightAlt", baseLabel: "Alt", baseKeyCode: 0xA5, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.25),
                .init(id: "rightWin", baseLabel: "rWin", baseKeyCode: 0x5C, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "left", baseLabel: "←", baseKeyCode: 0x25, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "down", baseLabel: "↓", baseKeyCode: 0x28, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.0),
                .init(id: "right", baseLabel: "→", baseKeyCode: 0x27, shiftLabel: nil, altLabel: nil, altKeyCode: nil, widthUnits: 1.0)
            ])
        ]
    }
}

private struct StreamVirtualKeyboardKeyView: View {
    let key: StreamVirtualKeyboardKeyDefinition
    let width: CGFloat
    let height: CGFloat
    let fnModeEnabled: Bool
    let isModifierSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundFill)

                VStack(spacing: 0) {
                    HStack {
                        if let shiftLabel = key.shiftLabel, !shiftLabel.isEmpty {
                            Text(shiftLabel)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.66))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 7)
                    .padding(.top, 6)

                    Spacer(minLength: 0)

                    if key.baseLabel.isEmpty {
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(Color.white.opacity(0.9))
                            .frame(width: min(width * 0.40, 54), height: 4)
                    } else {
                        Text(key.baseLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    Spacer(minLength: 0)

                    HStack {
                        Spacer(minLength: 0)
                        if let altLabel = key.altLabel, !altLabel.isEmpty {
                            Text(altLabel)
                                .font(.system(size: 10, weight: .medium))
                                .italic()
                                .foregroundColor(fnModeEnabled && key.altKeyCode != nil ? Color(red: 0.64, green: 0.86, blue: 0.45) : Color.white.opacity(0.74))
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.bottom, 6)
                }
            }
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var backgroundFill: LinearGradient {
        if isModifierSelected {
            return LinearGradient(colors: [
                Color(red: 0.40, green: 0.39, blue: 0.84),
                Color(red: 0.30, green: 0.29, blue: 0.70)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        if fnModeEnabled && key.altKeyCode != nil {
            return LinearGradient(colors: [
                Color(red: 0.22, green: 0.30, blue: 0.18),
                Color(red: 0.18, green: 0.24, blue: 0.16)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        return LinearGradient(colors: [
            Color.white.opacity(0.11),
            Color.white.opacity(0.05)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var borderColor: Color {
        if isModifierSelected {
            return Color.white.opacity(0.0)
        }
        return Color.white.opacity(0.10)
    }
}

@objcMembers
final class StreamActionSheetHostingViewController: UIViewController {
    weak var delegate: StreamActionSheetHostingViewControllerDelegate?

    private let viewModel = StreamActionSheetViewModel()
    private let dimmingView = UIView()
    private let panelContainerView = UIView()
    private var hostingController: UIHostingController<StreamActionSheetPanelView>?
    private var metadataTimer: Timer?
    private var touchModeToastHideWorkItem: DispatchWorkItem?
    private var isLandscapeLayout = false
    @objc var touchModeSelection: NSNumber = 0
    @objc var videoAlignmentSelection: NSNumber = 0
    @objc var videoAlignmentMargin: NSNumber = 0
    @objc var extendedPerformanceMetricsEnabled: Bool = false
    @objc var performanceOverlayPositionSelection: NSNumber = 0
    @objc var performanceOverlayMargin: NSNumber = 0
    @objc var audioHapticsEnabled: Bool = false
    @objc var audioHapticsOutputTargetSelection: NSNumber = 0
    @objc var audioHapticsStrength: NSNumber = 100
    @objc var audioHapticsVoiceFilterSelection: NSNumber = 0
    @objc var audioHapticsKeepControllerRumble: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        view.backgroundColor = .clear

        buildViewHierarchy()
        installHostingControllerIfNeeded()
        startMetadataUpdates()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        dimmingView.frame = view.bounds

        let bounds = view.bounds
        let bottomInset = view.safeAreaInsets.bottom
        let newIsLandscapeLayout = bounds.width > bounds.height
        if newIsLandscapeLayout != isLandscapeLayout {
            isLandscapeLayout = newIsLandscapeLayout
            refreshPanelRootView()
        }
        else {
            isLandscapeLayout = newIsLandscapeLayout
        }

        let panelWidth = isLandscapeLayout ? bounds.width * 0.8 : bounds.width
        let panelHeight = isLandscapeLayout ? bounds.height * 0.75 : bounds.height * 0.6
        let panelX = floor((bounds.width - panelWidth) / 2.0)
        let panelContainerHeight = panelHeight + bottomInset
        let panelY = bounds.height - panelContainerHeight

        panelContainerView.frame = CGRect(x: panelX, y: panelY, width: panelWidth, height: panelContainerHeight)
    }

    deinit {
        metadataTimer?.invalidate()
    }

    func configure(title: String, subtitle: String, items: [StreamActionSheetItem]) {
        viewModel.title = title
        viewModel.items = items
        viewModel.touchModeSelection = touchModeSelection.intValue
        viewModel.videoAlignmentSelection = videoAlignmentSelection.intValue
        viewModel.videoAlignmentMargin = videoAlignmentMargin.doubleValue
        viewModel.extendedPerformanceMetricsEnabled = extendedPerformanceMetricsEnabled
        viewModel.performanceOverlayPositionSelection = performanceOverlayPositionSelection.intValue
        viewModel.performanceOverlayMargin = performanceOverlayMargin.doubleValue
        viewModel.audioHapticsEnabled = audioHapticsEnabled
        viewModel.audioHapticsOutputTargetSelection = audioHapticsOutputTargetSelection.intValue
        viewModel.audioHapticsStrength = audioHapticsStrength.doubleValue
        viewModel.audioHapticsVoiceFilterSelection = audioHapticsVoiceFilterSelection.intValue
        viewModel.audioHapticsKeepControllerRumble = audioHapticsKeepControllerRumble
        updateMetadata()
        refreshPanelRootView()
    }

    @objc func showToastWithText(_ text: String) {
        touchModeToastHideWorkItem?.cancel()
        viewModel.touchModeToastText = text

        let workItem = DispatchWorkItem { [weak self] in
            self?.viewModel.touchModeToastText = nil
        }
        touchModeToastHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1, execute: workItem)
    }

    private func buildViewHierarchy() {
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cancelTapped)))
        view.addSubview(dimmingView)

        panelContainerView.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 0.94)
        panelContainerView.layer.cornerRadius = 30
        panelContainerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panelContainerView.layer.masksToBounds = true
        panelContainerView.layer.borderWidth = 1
        panelContainerView.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        view.addSubview(panelContainerView)
    }

    private func installHostingControllerIfNeeded() {
        let controller = EdgeIgnoringHostingController(rootView: makePanelRootView())
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.backgroundColor = .clear

        addChild(controller)
        panelContainerView.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: panelContainerView.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: panelContainerView.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: panelContainerView.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: panelContainerView.bottomAnchor)
        ])
        controller.didMove(toParent: self)
        hostingController = controller
    }

    private func refreshPanelRootView() {
        hostingController?.rootView = makePanelRootView()
    }

    private func makePanelRootView() -> StreamActionSheetPanelView {
        StreamActionSheetPanelView(viewModel: viewModel,
                                   isLandscape: isLandscapeLayout,
                                   onSelect: { [weak self] identifier in
                                       guard let self = self else {
                                           return
                                       }

                                       self.delegate?.streamActionSheetHostingViewController(self, didSelectActionWithIdentifier: identifier)
                                   },
                                   onTouchModeChange: { [weak self] selection in
                                       guard let self = self else {
                                           return
                                       }

                                       self.touchModeSelection = NSNumber(value: selection)
                                       // Kept for later debugging if we need a visible touch-mode hint again.
                                       // self.showTouchModeToast(for: selection)
                                       self.delegate?.streamActionSheetHostingViewController(self, didChangeTouchModeSelection: selection)
                                   },
                                   onVideoAlignmentChange: { [weak self] selection in
                                       guard let self = self else {
                                           return
                                       }

                                       self.videoAlignmentSelection = NSNumber(value: selection)
                                       self.delegate?.streamActionSheetHostingViewController(self, didChangeVideoAlignmentSelection: selection)
                                   },
                                   onVideoAlignmentMarginChange: { [weak self] margin in
                                       guard let self = self else {
                                           return
                                       }

                                       self.videoAlignmentMargin = NSNumber(value: margin)
                                       self.delegate?.streamActionSheetHostingViewController(self, didChangeVideoAlignmentMargin: margin)
                                   },
                                   onExtendedPerformanceMetricsChange: { [weak self] enabled in
                                       guard let self = self else {
                                           return
                                       }

                                       self.extendedPerformanceMetricsEnabled = enabled
                                       self.delegate?.streamActionSheetHostingViewController(self, didChangeExtendedPerformanceMetricsEnabled: enabled)
                                   },
                                   onPerformanceOverlayPositionChange: { [weak self] selection in
                                       guard let self = self else {
                                           return
                                       }

                                       self.performanceOverlayPositionSelection = NSNumber(value: selection)
                                       self.delegate?.streamActionSheetHostingViewController(self, didChangePerformanceOverlayPositionSelection: selection)
                                   },
                                   onPerformanceOverlayMarginChange: { [weak self] margin in
                                       guard let self = self else {
                                           return
                                       }

                                       self.performanceOverlayMargin = NSNumber(value: margin)
                                       self.delegate?.streamActionSheetHostingViewController(self, didChangePerformanceOverlayMargin: margin)
                                   },
                                   onAudioHapticsEnabledChange: { [weak self] enabled in
                                       guard let self = self else {
                                           return
                                       }

                                       self.audioHapticsEnabled = enabled
                                       self.delegate?.streamActionSheetHostingViewController(self, didChangeAudioHapticsEnabled: enabled)
                                   },
                                   onAudioHapticsOutputTargetChange: { [weak self] selection in
                                       guard let self = self else {
                                           return
                                       }

                                       self.audioHapticsOutputTargetSelection = NSNumber(value: selection)
                                       self.delegate?.streamActionSheetHostingViewController(self, didChangeAudioHapticsOutputTarget: selection)
                                   },
                                   onAudioHapticsStrengthChange: { [weak self] strength in
                                       guard let self = self else {
                                           return
                                       }

                                       self.audioHapticsStrength = NSNumber(value: strength)
                                       self.delegate?.streamActionSheetHostingViewController(self, didChangeAudioHapticsStrength: strength)
                                   },
                                   onAudioHapticsVoiceFilterSelectionChange: { [weak self] selection in
                                       guard let self = self else {
                                           return
                                       }

                                       self.audioHapticsVoiceFilterSelection = NSNumber(value: selection)
                                       self.delegate?.streamActionSheetHostingViewController(self, didChangeAudioHapticsVoiceFilterSelection: selection)
                                   },
                                   onAudioHapticsKeepControllerRumbleChange: { [weak self] enabled in
                                       guard let self = self else {
                                           return
                                       }

                                       self.audioHapticsKeepControllerRumble = enabled
                                       self.delegate?.streamActionSheetHostingViewController(self, didChangeAudioHapticsKeepControllerRumble: enabled)
                                   },
                                   onCancel: { [weak self] in
                                       guard let self = self else {
                                           return
                                       }

                                       self.delegate?.streamActionSheetHostingViewControllerDidCancel(self)
                                   })
    }

    private func startMetadataUpdates() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateMetadata()
        metadataTimer = Timer.scheduledTimer(timeInterval: 1.0,
                                             target: self,
                                             selector: #selector(updateMetadata),
                                             userInfo: nil,
                                             repeats: true)
    }

    @objc private func cancelTapped() {
        delegate?.streamActionSheetHostingViewControllerDidCancel(self)
    }

    @objc private func updateMetadata() {
        let currentDate = Date()
        viewModel.weekdayText = Self.weekdayFormatter.string(from: currentDate)
        viewModel.dateText = Self.dateFormatter.string(from: currentDate)
        viewModel.timeText = Self.timeFormatter.string(from: currentDate)

        let batteryLevel = UIDevice.current.batteryLevel
        viewModel.batteryText = batteryLevel >= 0 ? "\(Int(round(batteryLevel * 100)))%" : "--%"
    }

    private func touchModeTitle(for selection: Int) -> String {
        switch selection {
        case 1:
            return StreamMenuLocalized("stream.touch_mode.mouse")
        case 2:
            return StreamMenuLocalized("stream.touch_mode.multitouch")
        case 3:
            return StreamMenuLocalized("stream.touch_mode.disabled")
        default:
            return StreamMenuLocalized("stream.touch_mode.trackpad")
        }
    }

    private func showTouchModeToast(for selection: Int) {
        showToastWithText(StreamMenuLocalizedFormat("stream.touch_mode.toast", touchModeTitle(for: selection)))
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

@objcMembers
final class StreamShortcutPanelHostingViewController: UIViewController {
    weak var delegate: StreamShortcutPanelHostingViewControllerDelegate?

    private let viewModel = StreamShortcutPanelViewModel()
    private let dimmingView = UIView()
    private let panelContainerView = UIView()
    private var hostingController: UIHostingController<StreamShortcutPanelView>?
    private var isLandscapeLayout = false

    override func viewDidLoad() {
        super.viewDidLoad()
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        view.backgroundColor = .clear

        buildViewHierarchy()
        installHostingControllerIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        dimmingView.frame = view.bounds

        let bounds = view.bounds
        let bottomInset = view.safeAreaInsets.bottom
        let newIsLandscapeLayout = bounds.width > bounds.height
        if newIsLandscapeLayout != isLandscapeLayout {
            isLandscapeLayout = newIsLandscapeLayout
            refreshPanelRootView()
        } else {
            isLandscapeLayout = newIsLandscapeLayout
        }

        let panelWidth = bounds.width
        let panelHeight = bounds.height * 0.6
        let panelContainerHeight = panelHeight + bottomInset
        panelContainerView.frame = CGRect(x: 0,
                                          y: bounds.height - panelContainerHeight,
                                          width: panelWidth,
                                          height: panelContainerHeight)
    }

    func configure(title: String, builtInItems: [StreamShortcutPanelItem], customItems: [StreamShortcutPanelItem]) {
        viewModel.title = title
        viewModel.builtInItems = builtInItems
        viewModel.customItems = customItems
        refreshPanelRootView()
    }

    private func buildViewHierarchy() {
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cancelTapped)))
        view.addSubview(dimmingView)

        panelContainerView.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 0.94)
        panelContainerView.layer.cornerRadius = 30
        panelContainerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panelContainerView.layer.masksToBounds = true
        panelContainerView.layer.borderWidth = 1
        panelContainerView.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        view.addSubview(panelContainerView)
    }

    private func installHostingControllerIfNeeded() {
        let controller = EdgeIgnoringHostingController(rootView: makePanelRootView())
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.backgroundColor = .clear

        addChild(controller)
        panelContainerView.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: panelContainerView.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: panelContainerView.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: panelContainerView.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: panelContainerView.bottomAnchor)
        ])
        controller.didMove(toParent: self)
        hostingController = controller
    }

    private func refreshPanelRootView() {
        hostingController?.rootView = makePanelRootView()
    }

    private func makePanelRootView() -> StreamShortcutPanelView {
        StreamShortcutPanelView(viewModel: viewModel,
                                isLandscape: isLandscapeLayout,
                                onSelect: { [weak self] identifier in
                                    guard let self = self else { return }
                                    self.delegate?.streamShortcutPanelHostingViewController(self, didSelectItemWithIdentifier: identifier)
                                },
                                onSubmit: { [weak self] title, keyLabels, keyCodes in
                                    guard let self = self else { return }
                                    self.delegate?.streamShortcutPanelHostingViewController(self,
                                                                                           didSubmitItemWithTitle: title,
                                                                                           keyLabels: keyLabels,
                                                                                           keyCodes: keyCodes)
                                },
                                onDelete: { [weak self] identifier in
                                    guard let self = self else { return }
                                    self.delegate?.streamShortcutPanelHostingViewController(self,
                                                                                           didDeleteItemWithIdentifier: identifier)
                                },
                                onCancel: { [weak self] in
                                    guard let self = self else { return }
                                    self.delegate?.streamShortcutPanelHostingViewControllerDidCancel(self)
                                })
    }

    @objc private func cancelTapped() {
        delegate?.streamShortcutPanelHostingViewControllerDidCancel(self)
    }
}

@objcMembers
final class StreamVirtualKeyboardPanelHostingViewController: UIViewController {
    weak var delegate: StreamVirtualKeyboardPanelHostingViewControllerDelegate?

    private let viewModel = StreamVirtualKeyboardPanelViewModel()
    private let dimmingView = UIView()
    private let panelContainerView = UIView()
    private var hostingController: UIHostingController<StreamVirtualKeyboardPanelView>?
    private var isLandscapeLayout = false

    override func viewDidLoad() {
        super.viewDidLoad()
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        view.backgroundColor = .clear

        buildViewHierarchy()
        installHostingControllerIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        dimmingView.frame = view.bounds

        let bounds = view.bounds
        let isPhone = traitCollection.userInterfaceIdiom == .phone
        let newIsLandscapeLayout = bounds.width > bounds.height
        if newIsLandscapeLayout != isLandscapeLayout {
            isLandscapeLayout = newIsLandscapeLayout
            refreshPanelRootView()
        } else {
            isLandscapeLayout = newIsLandscapeLayout
        }

        let panelWidth = bounds.width
        let panelHeightRatio: CGFloat = isPhone ? (isLandscapeLayout ? 0.95 : 0.50) : (isLandscapeLayout ? 0.50 : 0.40)
        let panelHeight = bounds.height * panelHeightRatio
        let panelContainerHeight = panelHeight
        panelContainerView.frame = CGRect(x: 0,
                                          y: bounds.height - panelContainerHeight,
                                          width: panelWidth,
                                          height: panelContainerHeight)
    }

    func configure(title: String) {
        viewModel.title = title
        refreshPanelRootView()
    }

    private func buildViewHierarchy() {
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cancelTapped)))
        view.addSubview(dimmingView)

        panelContainerView.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 0.94)
        panelContainerView.layer.cornerRadius = 30
        panelContainerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panelContainerView.layer.masksToBounds = true
        panelContainerView.layer.borderWidth = 1
        panelContainerView.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        view.addSubview(panelContainerView)
    }

    private func installHostingControllerIfNeeded() {
        let controller = EdgeIgnoringHostingController(rootView: makePanelRootView())
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.backgroundColor = .clear

        addChild(controller)
        panelContainerView.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: panelContainerView.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: panelContainerView.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: panelContainerView.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: panelContainerView.bottomAnchor)
        ])
        controller.didMove(toParent: self)
        hostingController = controller
    }

    private func refreshPanelRootView() {
        hostingController?.rootView = makePanelRootView()
    }

    private func makePanelRootView() -> StreamVirtualKeyboardPanelView {
        StreamVirtualKeyboardPanelView(viewModel: viewModel,
                                       isLandscape: isLandscapeLayout,
                                       onSendKeyCodes: { [weak self] keyCodes in
                                           guard let self = self else { return }
                                           self.delegate?.streamVirtualKeyboardPanelHostingViewController(self, didSubmitKeyCodes: keyCodes)
                                       },
                                       onShowSystemKeyboard: { [weak self] in
                                           guard let self = self else { return }
                                           self.delegate?.streamVirtualKeyboardPanelHostingViewControllerDidRequestSystemKeyboard(self)
                                       },
                                       onCancel: { [weak self] in
                                           guard let self = self else { return }
                                           self.delegate?.streamVirtualKeyboardPanelHostingViewControllerDidCancel(self)
                                       })
    }

    @objc private func cancelTapped() {
        delegate?.streamVirtualKeyboardPanelHostingViewControllerDidCancel(self)
    }
}

@objcMembers
final class StreamVirtualButtonsPanelHostingViewController: UIViewController {
    weak var delegate: StreamVirtualButtonsPanelHostingViewControllerDelegate?

    private let viewModel = StreamVirtualButtonsPanelViewModel()
    private let dimmingView = UIView()
    private let panelContainerView = UIView()
    private var hostingController: UIHostingController<StreamVirtualButtonsPanelView>?
    private var isLandscapeLayout = false

    override func viewDidLoad() {
        super.viewDidLoad()
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        view.backgroundColor = .clear

        buildViewHierarchy()
        installHostingControllerIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        dimmingView.frame = view.bounds

        let bounds = view.bounds
        let bottomInset = view.safeAreaInsets.bottom
        let newIsLandscapeLayout = bounds.width > bounds.height
        if newIsLandscapeLayout != isLandscapeLayout {
            isLandscapeLayout = newIsLandscapeLayout
            refreshPanelRootView()
        } else {
            isLandscapeLayout = newIsLandscapeLayout
        }

        let panelWidth = bounds.width
        let panelHeightRatio: CGFloat = traitCollection.userInterfaceIdiom == .pad ? 0.60 : 0.68
        let panelHeight = bounds.height * panelHeightRatio
        let panelContainerHeight = panelHeight + bottomInset
        panelContainerView.frame = CGRect(x: 0,
                                          y: bounds.height - panelContainerHeight,
                                          width: panelWidth,
                                          height: panelContainerHeight)
    }

    func configure(title: String, items: [StreamVirtualButtonPanelItem], isEditingEnabled: Bool, buttonOpacity: Double) {
        viewModel.title = title
        viewModel.items = items
        viewModel.isEditingEnabled = isEditingEnabled
        viewModel.buttonOpacity = buttonOpacity
        refreshPanelRootView()
    }

    private func buildViewHierarchy() {
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cancelTapped)))
        view.addSubview(dimmingView)

        panelContainerView.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 0.94)
        panelContainerView.layer.cornerRadius = 30
        panelContainerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panelContainerView.layer.masksToBounds = true
        panelContainerView.layer.borderWidth = 1
        panelContainerView.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        view.addSubview(panelContainerView)
    }

    private func installHostingControllerIfNeeded() {
        let controller = EdgeIgnoringHostingController(rootView: makePanelRootView())
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.backgroundColor = .clear

        addChild(controller)
        panelContainerView.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: panelContainerView.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: panelContainerView.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: panelContainerView.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: panelContainerView.bottomAnchor)
        ])
        controller.didMove(toParent: self)
        hostingController = controller
    }

    private func refreshPanelRootView() {
        hostingController?.rootView = makePanelRootView()
    }

    private func makePanelRootView() -> StreamVirtualButtonsPanelView {
        StreamVirtualButtonsPanelView(viewModel: viewModel,
                                      isLandscape: isLandscapeLayout,
                                      onToggleEditing: { [weak self] enabled in
                                          guard let self = self else { return }
                                          self.delegate?.streamVirtualButtonsPanelHostingViewController(self, didChangeEditingEnabled: enabled)
                                      },
                                      onDelete: { [weak self] identifier in
                                          guard let self = self else { return }
                                          self.delegate?.streamVirtualButtonsPanelHostingViewController(self, didDeleteItemWithIdentifier: identifier)
                                      },
                                      onUpdate: { [weak self] identifier, shape, scale, widthScale, heightScale in
                                          guard let self = self else { return }
                                          self.delegate?.streamVirtualButtonsPanelHostingViewController(self,
                                                                                                        didUpdateItemWithIdentifier: identifier,
                                                                                                        shape: shape,
                                                                                                        scale: scale,
                                                                                                        widthScale: widthScale,
                                                                                                        heightScale: heightScale)
                                      },
                                      onOpacityChange: { [weak self] opacity in
                                          guard let self = self else { return }
                                          self.delegate?.streamVirtualButtonsPanelHostingViewController(self, didChangeButtonOpacity: opacity)
                                      },
                                      onSubmit: { [weak self] title, keyLabels, keyCodes in
                                          guard let self = self else { return }
                                          self.delegate?.streamVirtualButtonsPanelHostingViewController(self,
                                                                                                        didSubmitItemWithTitle: title,
                                                                                                        keyLabels: keyLabels,
                                                                                                        keyCodes: keyCodes)
                                      },
                                      onSubmitMouse: { [weak self] title, mouseActionIdentifier, subtitle in
                                          guard let self = self else { return }
                                          self.delegate?.streamVirtualButtonsPanelHostingViewController(self,
                                                                                                        didSubmitMouseItemWithTitle: title,
                                                                                                        mouseActionIdentifier: mouseActionIdentifier,
                                                                                                        subtitle: subtitle)
                                      },
                                      onSubmitDirectional: { [weak self] title, controlActionIdentifier, subtitle in
                                          guard let self = self else { return }
                                          self.delegate?.streamVirtualButtonsPanelHostingViewController(self,
                                                                                                        didSubmitDirectionalItemWithTitle: title,
                                                                                                        controlActionIdentifier: controlActionIdentifier,
                                                                                                        subtitle: subtitle)
                                      },
                                      onCancel: { [weak self] in
                                          guard let self = self else { return }
                                          self.delegate?.streamVirtualButtonsPanelHostingViewControllerDidCancel(self)
                                      })
    }

    @objc private func cancelTapped() {
        delegate?.streamVirtualButtonsPanelHostingViewControllerDidCancel(self)
    }
}
