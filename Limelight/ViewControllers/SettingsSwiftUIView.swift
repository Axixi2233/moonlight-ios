import UIKit
#if canImport(SwiftUI)
import SwiftUI

private func SettingsLocalized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func SettingsLocalizedFormat(_ key: String, _ args: CVarArg...) -> String {
    String(format: SettingsLocalized(key), locale: Locale.current, arguments: args)
}

@objcMembers
final class SettingsFormSnapshot: NSObject {
    var bitrateValues: [NSNumber] = []
    var bitrateSliderIndex: Int = 0
    var bitrateKbps: Int = 10000
    var bitrateMinimumKbps: Int = 10000
    var bitrateMaximumKbps: Int = 500000
    var audioConfigSelection: Int = 1

    var framerateOptions: [NSNumber] = []
    var framerate: Int = 60

    var resolutionTitles: [String] = []
    var resolutionDetailTitles: [String] = []
    var selectedResolutionIndex: Int = 1
    var customResolutionWidth: Int = 0
    var customResolutionHeight: Int = 0
    var isFourKResolutionEnabled: Bool = true

    var codecTitles: [String] = []
    var codecValues: [NSNumber] = []
    var preferredCodecValue: Int = 0

    var hdrSupported: Bool = false
    var enableHdr: Bool = false
    var useFramePacing: Bool = false

    var touchModeSelection: Int = 0
    var optimizeGames: Bool = true
    var multiController: Bool = false
    var swapABXYButtons: Bool = false
    var playAudioOnPC: Bool = false
    var btMouseSupport: Bool = false
    var remoteMouseMode: Bool = false
    var captureMouseCursor: Bool = true
    var relativeMouseSensitivity: Int = 100
    var statsOverlay: Bool = false
    var rumbleModeSelection: Int = 0
    var externalMonitor: Bool = false
    var motionMode: Int = 0
    var virtualDisplayMode: Int = 0
    var enableTouchSensitivity: Bool = false
    var touchSensitivityGlobal: Bool = false
    var touchSensitivity: Int = 100
    var videoAlignmentSelection: Int = 0
    var videoAlignmentMargin: Int = 0
    var performanceOverlayPositionSelection: Int = 0
    var performanceOverlayMargin: Int = 6
    var floatingMenuEnabled: Bool = false
    var virtualButtonsEnabled: Bool = false
    var virtualGamepadEnabled: Bool = false
    var virtualButtonSchemeSelection: Int = 0
    var virtualGamepadSchemeSelection: Int = 0
    var virtualGamepadOpacity: Int = 52
}

@objc protocol SettingsHostingViewControllerDelegate: NSObjectProtocol {
    func settingsHostingViewControllerDidRequestCustomResolution(_ controller: SettingsHostingViewController)
    func settingsHostingViewController(_ controller: SettingsHostingViewController, didRequestOpenExternalURL urlString: String)
}

@available(iOS 13.0, *)
private final class SettingsFormViewModel: ObservableObject {
    @Published var bitrateValues: [Int] = []
    @Published var bitrateSliderIndex: Double = 0
    @Published var bitrateKbps: Int = 10000
    @Published var bitrateMinimumKbps: Int = 10000
    @Published var bitrateMaximumKbps: Int = 500000
    @Published var bitrateSliderPosition: Double = 0
    @Published var audioConfigSelection: Int = 1

    @Published var framerateOptions: [Int] = []
    @Published var framerate: Int = 60

    @Published var resolutionTitles: [String] = []
    @Published var resolutionDetailTitles: [String] = []
    @Published var selectedResolutionIndex: Int = 1
    @Published var customResolutionWidth: Int = 0
    @Published var customResolutionHeight: Int = 0
    @Published var isFourKResolutionEnabled: Bool = true

    @Published var codecTitles: [String] = []
    @Published var codecValues: [Int] = []
    @Published var preferredCodecValue: Int = 0

    @Published var hdrSupported: Bool = false
    @Published var enableHdr: Bool = false
    @Published var useFramePacing: Bool = false

    @Published var touchModeSelection: Int = 0
    @Published var optimizeGames: Bool = true
    @Published var multiController: Bool = false
    @Published var swapABXYButtons: Bool = false
    @Published var playAudioOnPC: Bool = false
    @Published var btMouseSupport: Bool = false
    @Published var remoteMouseMode: Bool = false
    @Published var captureMouseCursor: Bool = true
    @Published var relativeMouseSensitivity: Double = 100
    @Published var statsOverlay: Bool = false
    @Published var rumbleModeSelection: Int = 0
    @Published var externalMonitor: Bool = false
    @Published var motionMode: Int = 0
    @Published var virtualDisplayMode: Int = 0
    @Published var enableTouchSensitivity: Bool = false
    @Published var touchSensitivityGlobal: Bool = false
    @Published var touchSensitivity: Double = 100
    @Published var videoAlignmentSelection: Int = 0
    @Published var videoAlignmentMargin: Double = 0
    @Published var performanceOverlayPositionSelection: Int = 0
    @Published var performanceOverlayMargin: Double = 6
    @Published var floatingMenuEnabled: Bool = false
    @Published var virtualButtonsEnabled: Bool = false
    @Published var virtualGamepadEnabled: Bool = false
    @Published var virtualButtonSchemeSelection: Int = 0
    @Published var virtualGamepadSchemeSelection: Int = 0
    @Published var virtualGamepadOpacity: Double = 52

    func apply(snapshot: SettingsFormSnapshot) {
        bitrateValues = snapshot.bitrateValues.map { $0.intValue }
        bitrateKbps = snapshot.bitrateKbps
        bitrateMinimumKbps = snapshot.bitrateMinimumKbps
        bitrateMaximumKbps = snapshot.bitrateMaximumKbps
        syncBitrateSliderPositionFromBitrate()
        audioConfigSelection = snapshot.audioConfigSelection

        framerateOptions = snapshot.framerateOptions.map { $0.intValue }
        framerate = snapshot.framerate

        resolutionTitles = snapshot.resolutionTitles
        resolutionDetailTitles = snapshot.resolutionDetailTitles
        selectedResolutionIndex = snapshot.selectedResolutionIndex
        customResolutionWidth = snapshot.customResolutionWidth
        customResolutionHeight = snapshot.customResolutionHeight
        isFourKResolutionEnabled = snapshot.isFourKResolutionEnabled

        codecTitles = snapshot.codecTitles
        codecValues = snapshot.codecValues.map { $0.intValue }
        preferredCodecValue = snapshot.preferredCodecValue

        hdrSupported = snapshot.hdrSupported
        enableHdr = snapshot.enableHdr
        useFramePacing = snapshot.useFramePacing

        touchModeSelection = snapshot.touchModeSelection
        optimizeGames = snapshot.optimizeGames
        multiController = snapshot.multiController
        swapABXYButtons = snapshot.swapABXYButtons
        playAudioOnPC = snapshot.playAudioOnPC
        btMouseSupport = snapshot.btMouseSupport
        remoteMouseMode = snapshot.remoteMouseMode
        captureMouseCursor = snapshot.captureMouseCursor
        relativeMouseSensitivity = Double(snapshot.relativeMouseSensitivity)
        statsOverlay = snapshot.statsOverlay
        rumbleModeSelection = snapshot.rumbleModeSelection
        externalMonitor = snapshot.externalMonitor
        motionMode = snapshot.motionMode
        virtualDisplayMode = snapshot.virtualDisplayMode
        enableTouchSensitivity = snapshot.enableTouchSensitivity
        touchSensitivityGlobal = snapshot.touchSensitivityGlobal
        touchSensitivity = Double(snapshot.touchSensitivity)
        videoAlignmentSelection = snapshot.videoAlignmentSelection
        videoAlignmentMargin = Double(snapshot.videoAlignmentMargin)
        performanceOverlayPositionSelection = snapshot.performanceOverlayPositionSelection
        performanceOverlayMargin = Double(snapshot.performanceOverlayMargin)
        floatingMenuEnabled = snapshot.floatingMenuEnabled
        virtualButtonsEnabled = snapshot.virtualButtonsEnabled
        virtualGamepadEnabled = snapshot.virtualGamepadEnabled
        virtualButtonSchemeSelection = snapshot.virtualButtonSchemeSelection
        virtualGamepadSchemeSelection = snapshot.virtualGamepadSchemeSelection
        virtualGamepadOpacity = Double(snapshot.virtualGamepadOpacity)
    }

    func currentSnapshot() -> SettingsFormSnapshot {
        let snapshot = SettingsFormSnapshot()
        snapshot.bitrateValues = bitrateValues.map { NSNumber(value: $0) }
        snapshot.bitrateKbps = bitrateKbps
        snapshot.bitrateMinimumKbps = bitrateMinimumKbps
        snapshot.bitrateMaximumKbps = bitrateMaximumKbps
        snapshot.audioConfigSelection = audioConfigSelection
        snapshot.framerateOptions = framerateOptions.map { NSNumber(value: $0) }
        snapshot.framerate = framerate
        snapshot.resolutionTitles = resolutionTitles
        snapshot.resolutionDetailTitles = resolutionDetailTitles
        snapshot.selectedResolutionIndex = selectedResolutionIndex
        snapshot.customResolutionWidth = customResolutionWidth
        snapshot.customResolutionHeight = customResolutionHeight
        snapshot.isFourKResolutionEnabled = isFourKResolutionEnabled
        snapshot.codecTitles = codecTitles
        snapshot.codecValues = codecValues.map { NSNumber(value: $0) }
        snapshot.preferredCodecValue = preferredCodecValue
        snapshot.hdrSupported = hdrSupported
        snapshot.enableHdr = enableHdr
        snapshot.useFramePacing = useFramePacing
        snapshot.touchModeSelection = touchModeSelection
        snapshot.optimizeGames = optimizeGames
        snapshot.multiController = multiController
        snapshot.swapABXYButtons = swapABXYButtons
        snapshot.playAudioOnPC = playAudioOnPC
        snapshot.btMouseSupport = btMouseSupport
        snapshot.remoteMouseMode = remoteMouseMode
        snapshot.captureMouseCursor = captureMouseCursor
        snapshot.relativeMouseSensitivity = Int(relativeMouseSensitivity.rounded())
        snapshot.statsOverlay = statsOverlay
        snapshot.rumbleModeSelection = rumbleModeSelection
        snapshot.externalMonitor = externalMonitor
        snapshot.motionMode = motionMode
        snapshot.virtualDisplayMode = virtualDisplayMode
        snapshot.enableTouchSensitivity = enableTouchSensitivity
        snapshot.touchSensitivityGlobal = touchSensitivityGlobal
        snapshot.touchSensitivity = Int(touchSensitivity.rounded())
        snapshot.videoAlignmentSelection = videoAlignmentSelection
        snapshot.videoAlignmentMargin = Int(videoAlignmentMargin.rounded())
        snapshot.performanceOverlayPositionSelection = performanceOverlayPositionSelection
        snapshot.performanceOverlayMargin = Int(performanceOverlayMargin.rounded())
        snapshot.floatingMenuEnabled = floatingMenuEnabled
        snapshot.virtualButtonsEnabled = virtualButtonsEnabled
        snapshot.virtualGamepadEnabled = virtualGamepadEnabled
        snapshot.virtualButtonSchemeSelection = virtualButtonSchemeSelection
        snapshot.virtualGamepadSchemeSelection = virtualGamepadSchemeSelection
        snapshot.virtualGamepadOpacity = Int(virtualGamepadOpacity.rounded())
        return snapshot
    }

    var bitrateLabel: String {
        SettingsLocalizedFormat("settings.bitrate.label", Double(bitrateKbps) / 1000.0)
    }

    var touchSensitivityLabel: String {
        SettingsLocalizedFormat("settings.touch_sensitivity.label", touchSensitivity)
    }

    var relativeMouseSensitivityLabel: String {
        SettingsLocalizedFormat("settings.relative_mouse_sensitivity.label", relativeMouseSensitivity)
    }

    var customResolutionLabel: String {
        if customResolutionWidth > 0, customResolutionHeight > 0 {
            return "\(customResolutionWidth) x \(customResolutionHeight)"
        }
        return SettingsLocalized("common.not_set")
    }

    var selectedResolutionTitle: String {
        let clampedIndex = min(max(selectedResolutionIndex, 0), max(resolutionTitles.count - 1, 0))
        guard resolutionTitles.indices.contains(clampedIndex) else {
            return SettingsLocalized("common.not_selected")
        }
        let title = resolutionTitles[clampedIndex]
        let detail = resolutionDetailTitle(for: clampedIndex)
        if detail.isEmpty {
            return title
        }
        return "\(title) (\(detail))"
    }

    func updateBitrateFromSlider() {
        let minimum = max(bitrateMinimumKbps, 1)
        let maximum = max(bitrateMaximumKbps, minimum)
        let clampedPosition = min(max(bitrateSliderPosition, 0.0), 1.0)
        bitrateSliderPosition = clampedPosition

        guard minimum < maximum else {
            bitrateKbps = minimum
            return
        }

        let minLog = log(Double(minimum))
        let maxLog = log(Double(maximum))
        let bitrate = exp(minLog + (maxLog - minLog) * clampedPosition)
        bitrateKbps = Int(bitrate.rounded())
    }

    private func syncBitrateSliderPositionFromBitrate() {
        let minimum = max(bitrateMinimumKbps, 1)
        let maximum = max(bitrateMaximumKbps, minimum)
        let clampedBitrate = min(max(bitrateKbps, minimum), maximum)
        bitrateKbps = clampedBitrate

        guard minimum < maximum else {
            bitrateSliderPosition = 0.0
            bitrateSliderIndex = Double(clampedBitrate)
            return
        }

        let minLog = log(Double(minimum))
        let maxLog = log(Double(maximum))
        let valueLog = log(Double(clampedBitrate))
        bitrateSliderPosition = min(max((valueLog - minLog) / (maxLog - minLog), 0.0), 1.0)
        bitrateSliderIndex = Double(clampedBitrate)
    }

    func updateCustomResolution(width: Int, height: Int) {
        customResolutionWidth = width
        customResolutionHeight = height
        if !resolutionDetailTitles.isEmpty {
            let customIndex = resolutionDetailTitles.count - 1
            if resolutionDetailTitles.indices.contains(customIndex) {
                resolutionDetailTitles[customIndex] = "\(width) x \(height)"
            }
        }
        if !resolutionTitles.isEmpty {
            selectedResolutionIndex = resolutionTitles.count - 1
        }
    }

    private func resolutionDetailTitle(for index: Int) -> String {
        if index == resolutionTitles.count - 1, customResolutionWidth > 0, customResolutionHeight > 0 {
            return "\(customResolutionWidth) x \(customResolutionHeight)"
        }
        guard resolutionDetailTitles.indices.contains(index) else {
            return ""
        }
        return resolutionDetailTitles[index]
    }
}

@available(iOS 13.0, *)
private struct SettingsPurpleBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.95, green: 0.89, blue: 0.99),
                Color(red: 0.86, green: 0.78, blue: 0.98),
                Color(red: 0.70, green: 0.63, blue: 0.93)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .edgesIgnoringSafeArea(.all)
    }
}

@available(iOS 13.0, *)
private func configureSettingsTableAppearance() {
    UITableView.appearance().backgroundColor = .clear
    UITableView.appearance().tableFooterView = UIView(frame: .zero)
    UITableViewCell.appearance().backgroundColor = .clear
    UITableViewHeaderFooterView.appearance().tintColor = .clear
}

@available(iOS 13.0, *)
private struct ChoiceSelectionSheet: View {
    let title: String
    let subtitle: String
    let options: [(offset: Int, element: String)]
    let selectedIndex: Int
    let onSelect: (Int) -> Void
    let isDisabled: (Int) -> Bool

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                SettingsPurpleBackground()

                List {
                    Section(header: Text(subtitle)) {
                        ForEach(options, id: \.offset) { option in
                            Button(action: {
                                guard !isDisabled(option.offset) else { return }
                                onSelect(option.offset)
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack {
                                    Text(option.element)
                                        .foregroundColor(isDisabled(option.offset) ? .secondary : .primary)
                                    Spacer()
                                    if selectedIndex == option.offset {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isDisabled(option.offset))
                        }
                    }
                }
                .listStyle(GroupedListStyle())
                .background(Color.clear)
                .onAppear {
                    configureSettingsTableAppearance()
                }
            }
            .navigationBarTitle(Text(title), displayMode: .inline)
            .navigationBarItems(trailing: Button(SettingsLocalized("common.done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

@available(iOS 13.0, *)
private struct ChoiceSectionRow: View {
    let title: String
    let subtitle: String
    let options: [(offset: Int, element: String)]
    let selectedIndex: Int
    let onSelect: (Int) -> Void
    let isDisabled: (Int) -> Bool

    @State private var isPresentingSelectionSheet = false

    var body: some View {
        Button(action: {
            isPresentingSelectionSheet = true
        }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.secondary)
                }

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $isPresentingSelectionSheet) {
            ChoiceSelectionSheet(
                title: title,
                subtitle: subtitle,
                options: options,
                selectedIndex: selectedIndex,
                onSelect: onSelect,
                isDisabled: isDisabled
            )
        }
    }
}

@available(iOS 13.0, *)
private struct SettingsRootView: View {
    @ObservedObject var model: SettingsFormViewModel
    let requestCustomResolution: () -> Void
    let openExternalURL: (String) -> Void

    var body: some View {
        ZStack {
            SettingsPurpleBackground()

            Form {
                Section(header: Text(SettingsLocalized("settings.section.video"))) {
                    choiceSection(
                        title: SettingsLocalized("settings.resolution.title"),
                        subtitle: model.selectedResolutionTitle,
                        options: Array(model.resolutionTitles.enumerated()),
                        selectedIndex: model.selectedResolutionIndex
                    ) { index in
                        if index == model.resolutionTitles.count - 1 {
                            requestCustomResolution()
                        } else {
                            model.selectedResolutionIndex = index
                        }
                    } isDisabled: { index in
                        index == 5 && !model.isFourKResolutionEnabled
                    }

                    Button(action: {
                        requestCustomResolution()
                    }) {
                        Text(SettingsLocalizedFormat("settings.custom_resolution.button", model.customResolutionLabel))
                    }
                    segmentedSection(title: SettingsLocalized("settings.framerate.title"), selection: bindingForFramerate(), labels: model.framerateOptions.map { "\($0) FPS" })

                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.bitrateLabel)
                            .font(.headline)
                        Slider(value: bitrateSliderBinding(), in: 0...1) { _ in
                            model.updateBitrateFromSlider()
                        }
                    }

                    segmentedSection(title: SettingsLocalized("settings.codec.title"), selection: codecSelection(), labels: model.codecTitles)

                    if model.hdrSupported {
                        Toggle("HDR (Beta)", isOn: $model.enableHdr).font(.headline)
                    } else {
                        Text(SettingsLocalized("settings.hdr.unsupported"))
                            .foregroundColor(.secondary)
                    }

                    segmentedSection(title: SettingsLocalized("settings.frame_pacing.title"), selection: boolSelection($model.useFramePacing), labels: [SettingsLocalized("settings.frame_pacing.low_latency"), SettingsLocalized("settings.frame_pacing.smooth_video")])

                    segmentedSection(title: SettingsLocalized("settings.video_alignment.title"), selection: $model.videoAlignmentSelection, labels: model.videoAlignmentTitles)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(SettingsLocalizedFormat("settings.video_alignment_margin.label", Int(model.videoAlignmentMargin)))
                            .font(.headline)
                        Slider(value: $model.videoAlignmentMargin, in: 0...150, step: 1)
                    }

                }

                Section(header: Text(SettingsLocalized("settings.section.input"))) {
                    segmentedSection(title: SettingsLocalized("settings.touch_mode.title"), selection: touchModeSelection(), labels: model.touchModeTitles)
                    segmentedSection(title: SettingsLocalized("settings.motion_mode.title"), selection: $model.motionMode, labels: [SettingsLocalized("common.auto"), SettingsLocalized("common.device"), SettingsLocalized("common.controller")])
                    segmentedSection(title: SettingsLocalized("settings.rumble_mode.title"), selection: $model.rumbleModeSelection, labels: model.rumbleModeTitles)
                    Toggle(SettingsLocalized("settings.touch_sensitivity.toggle"), isOn: $model.enableTouchSensitivity).font(.headline)
                    Toggle(SettingsLocalized("settings.touch_sensitivity_global.toggle"), isOn: $model.touchSensitivityGlobal).font(.headline)
                    if model.enableTouchSensitivity {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.touchSensitivityLabel)
                                .font(.headline)
                            Slider(value: $model.touchSensitivity, in: 10...300, step: 1)
                        }
                    }
                    Toggle(SettingsLocalized("settings.multi_controller.toggle"), isOn: $model.multiController).font(.headline)
                    Toggle(SettingsLocalized("settings.swap_abxy.toggle"), isOn: $model.swapABXYButtons).font(.headline)
                    Toggle(SettingsLocalized("settings.bt_mouse_support.toggle"), isOn: $model.btMouseSupport).font(.headline)
                    Toggle(SettingsLocalized("settings.capture_mouse_cursor.toggle"), isOn: $model.captureMouseCursor).font(.headline)
                    Toggle(SettingsLocalized("settings.remote_mouse_mode.toggle"), isOn: $model.remoteMouseMode).font(.headline)
                    if !model.remoteMouseMode {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.relativeMouseSensitivityLabel)
                                .font(.headline)
                            Slider(value: $model.relativeMouseSensitivity, in: 50...300, step: 1)
                        }
                    }
                }

                Section(header: Text(SettingsLocalized("settings.section.advanced"))) {
                    choiceSection(
                        title: SettingsLocalized("settings.audio_config.title"),
                        subtitle: model.audioConfigTitle,
                        options: Array(model.audioConfigTitles.enumerated()),
                        selectedIndex: model.audioConfigSelection
                    ) { index in
                        model.audioConfigSelection = index
                    } isDisabled: { _ in false }
                    Toggle(SettingsLocalized("settings.play_audio_on_pc.toggle"), isOn: $model.playAudioOnPC).font(.headline)
                    Toggle(SettingsLocalized("settings.optimize_games.toggle"), isOn: $model.optimizeGames).font(.headline)
                    Toggle(SettingsLocalized("settings.floating_menu.toggle"), isOn: $model.floatingMenuEnabled).font(.headline)
                    Toggle(SettingsLocalized("settings.external_monitor.toggle"), isOn: $model.externalMonitor).font(.headline)
                    Toggle(SettingsLocalized("settings.virtual_display.toggle"), isOn: virtualDisplayToggle()).font(.headline)
                }

                Section(header: Text(SettingsLocalized("settings.section.virtual_controls"))) {
                    Toggle(SettingsLocalized("settings.virtual_buttons_enabled.toggle"), isOn: $model.virtualButtonsEnabled).font(.headline)
                    Toggle(SettingsLocalized("settings.virtual_gamepad_enabled.toggle"), isOn: $model.virtualGamepadEnabled).font(.headline)
                    choiceSection(
                        title: SettingsLocalized("settings.virtual_button_scheme.title"),
                        subtitle: model.virtualButtonSchemeTitle,
                        options: Array(model.virtualButtonSchemeTitles.enumerated()),
                        selectedIndex: model.virtualButtonSchemeSelection
                    ) { index in
                        model.virtualButtonSchemeSelection = index
                    } isDisabled: { _ in false }
                    choiceSection(
                        title: SettingsLocalized("settings.virtual_gamepad_scheme.title"),
                        subtitle: model.virtualGamepadSchemeTitle,
                        options: Array(model.virtualGamepadSchemeTitles.enumerated()),
                        selectedIndex: model.virtualGamepadSchemeSelection
                    ) { index in
                        model.virtualGamepadSchemeSelection = index
                    } isDisabled: { _ in false }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(SettingsLocalizedFormat("settings.virtual_gamepad_opacity.label", Int(model.virtualGamepadOpacity)))
                            .font(.headline)
                        Slider(value: $model.virtualGamepadOpacity, in: 5...100, step: 1)
                    }
                }

                Section(header: Text(SettingsLocalized("settings.section.performance_overlay"))) {
                    Toggle(SettingsLocalized("settings.stats_overlay.toggle"), isOn: $model.statsOverlay).font(.headline)
                    choiceSection(
                        title: SettingsLocalized("settings.performance_overlay_position.title"),
                        subtitle: model.performanceOverlayPositionTitle,
                        options: Array(model.performanceOverlayPositionTitles.enumerated()),
                        selectedIndex: model.performanceOverlayPositionSelection
                    ) { index in
                        model.performanceOverlayPositionSelection = index
                    } isDisabled: { _ in false }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(SettingsLocalizedFormat("settings.performance_overlay_margin.label", Int(model.performanceOverlayMargin)))
                            .font(.headline)
                        Slider(value: $model.performanceOverlayMargin, in: 0...150, step: 1)
                    }
                }
            }
            .background(Color.clear)
            .onAppear {
                configureSettingsTableAppearance()
            }
        }
    }

    private func bindingForFramerate() -> Binding<Int> {
        Binding(
            get: { model.framerateOptions.firstIndex(of: model.framerate) ?? 0 },
            set: { newIndex in
                guard model.framerateOptions.indices.contains(newIndex) else { return }
                model.framerate = model.framerateOptions[newIndex]
            }
        )
    }

    private func bitrateSliderBinding() -> Binding<Double> {
        Binding(
            get: { model.bitrateSliderPosition },
            set: { newValue in
                model.bitrateSliderPosition = newValue
                model.updateBitrateFromSlider()
            }
        )
    }

    private func codecSelection() -> Binding<Int> {
        Binding(
            get: { model.selectedCodecIndex },
            set: { newIndex in
                guard model.codecValues.indices.contains(newIndex) else { return }
                model.preferredCodecValue = model.codecValues[newIndex]
            }
        )
    }

    private func touchModeSelection() -> Binding<Int> {
        Binding(
            get: { model.touchModeSelectionIndex },
            set: { newIndex in
                model.setTouchModeSelectionIndex(newIndex)
            }
        )
    }

    private func virtualDisplayToggle() -> Binding<Bool> {
        Binding(
            get: { model.virtualDisplayMode != 0 },
            set: { isOn in
                model.virtualDisplayMode = isOn ? 1 : 0
            }
        )
    }

    private func boolSelection(_ value: Binding<Bool>) -> Binding<Int> {
        Binding(
            get: { value.wrappedValue ? 1 : 0 },
            set: { value.wrappedValue = ($0 == 1) }
        )
    }

    private func segmentedSection(title: String, selection: Binding<Int>, labels: [String], falseLabelIsEnabled: Bool = false, reverseBoolMeaning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Picker(title, selection: selection) {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    Text(label).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    @ViewBuilder
    private func choiceSection(title: String, subtitle: String, options: [(offset: Int, element: String)], selectedIndex: Int, onSelect: @escaping (Int) -> Void, isDisabled: @escaping (Int) -> Bool) -> some View {
        ChoiceSectionRow(
            title: title,
            subtitle: subtitle,
            options: options,
            selectedIndex: selectedIndex,
            onSelect: onSelect,
            isDisabled: isDisabled
        )
    }
}

@available(iOS 13.0, *)
private extension SettingsFormViewModel {
    var rumbleModeTitles: [String] {
        [SettingsLocalized("common.controller"), SettingsLocalized("common.device"), SettingsLocalized("common.off")]
    }

    var touchModeTitles: [String] {
        [
            SettingsLocalized("stream.touch_mode.trackpad"),
            SettingsLocalized("stream.touch_mode.mouse"),
            SettingsLocalized("stream.touch_mode.multitouch"),
            SettingsLocalized("stream.touch_mode.disabled")
        ]
    }

    var touchModeSelectionIndex: Int {
        min(max(touchModeSelection, 0), touchModeTitles.count - 1)
    }

    var touchModeTitle: String {
        guard touchModeTitles.indices.contains(touchModeSelectionIndex) else {
            return SettingsLocalized("stream.touch_mode.trackpad")
        }
        return touchModeTitles[touchModeSelectionIndex]
    }

    func setTouchModeSelectionIndex(_ index: Int) {
        touchModeSelection = min(max(index, 0), touchModeTitles.count - 1)
    }

    var codecDisplayTitle: String {
        guard let index = codecValues.firstIndex(of: preferredCodecValue), codecTitles.indices.contains(index) else {
            return SettingsLocalized("common.auto")
        }
        return codecTitles[index]
    }

    var selectedCodecIndex: Int {
        codecValues.firstIndex(of: preferredCodecValue) ?? max(codecValues.count - 1, 0)
    }

    var videoAlignmentTitles: [String] {
        [
            SettingsLocalized("settings.video_alignment.center"),
            SettingsLocalized("settings.video_alignment.top"),
            SettingsLocalized("settings.video_alignment.bottom")
        ]
    }

    var audioConfigTitles: [String] {
        [
            SettingsLocalized("settings.audio_config.stereo"),
            SettingsLocalized("settings.audio_config.surround_5_1"),
            SettingsLocalized("settings.audio_config.surround_7_1")
        ]
    }

    var audioConfigTitle: String {
        guard audioConfigTitles.indices.contains(audioConfigSelection) else {
            return SettingsLocalized("settings.audio_config.stereo")
        }
        return audioConfigTitles[audioConfigSelection]
    }

    var performanceOverlayPositionTitles: [String] {
        [
            SettingsLocalized("settings.performance_overlay_position.top_center"),
            SettingsLocalized("settings.performance_overlay_position.top_left"),
            SettingsLocalized("settings.performance_overlay_position.top_right"),
            SettingsLocalized("settings.performance_overlay_position.bottom_center"),
            SettingsLocalized("settings.performance_overlay_position.bottom_left"),
            SettingsLocalized("settings.performance_overlay_position.bottom_right")
        ]
    }

    var performanceOverlayPositionTitle: String {
        guard performanceOverlayPositionTitles.indices.contains(performanceOverlayPositionSelection) else {
            return SettingsLocalized("settings.performance_overlay_position.top_center")
        }
        return performanceOverlayPositionTitles[performanceOverlayPositionSelection]
    }

    var virtualButtonSchemeTitles: [String] {
        (1...5).map { SettingsLocalizedFormat("settings.scheme.title", $0) }
    }

    var virtualButtonSchemeTitle: String {
        guard virtualButtonSchemeTitles.indices.contains(virtualButtonSchemeSelection) else {
            return SettingsLocalizedFormat("settings.scheme.title", 1)
        }
        return virtualButtonSchemeTitles[virtualButtonSchemeSelection]
    }

    var virtualGamepadSchemeTitles: [String] {
        (1...5).map { SettingsLocalizedFormat("settings.scheme.title", $0) }
    }

    var virtualGamepadSchemeTitle: String {
        guard virtualGamepadSchemeTitles.indices.contains(virtualGamepadSchemeSelection) else {
            return SettingsLocalizedFormat("settings.scheme.title", 1)
        }
        return virtualGamepadSchemeTitles[virtualGamepadSchemeSelection]
    }
}

@objcMembers
@available(iOS 13.0, *)
final class SettingsHostingViewController: UIViewController {
    weak var delegate: SettingsHostingViewControllerDelegate?

    private let model = SettingsFormViewModel()
    private var hostingController: UIHostingController<SettingsRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        overrideUserInterfaceStyle = .light
        installHostingControllerIfNeeded()
    }

    func configure(with snapshot: SettingsFormSnapshot) {
        model.apply(snapshot: snapshot)
        if isViewLoaded {
            installHostingControllerIfNeeded()
        }
    }

    func currentSnapshot() -> SettingsFormSnapshot {
        model.currentSnapshot()
    }

    func updateCustomResolutionWidth(_ width: Int, height: Int) {
        model.updateCustomResolution(width: width, height: height)
    }

    private func installHostingControllerIfNeeded() {
        let rootView = SettingsRootView(
            model: model,
            requestCustomResolution: { [weak self] in
                guard let self = self else { return }
                self.delegate?.settingsHostingViewControllerDidRequestCustomResolution(self)
            },
            openExternalURL: { [weak self] urlString in
                guard let self = self else { return }
                self.delegate?.settingsHostingViewController(self, didRequestOpenExternalURL: urlString)
            }
        )

        if let hostingController = hostingController {
            hostingController.rootView = rootView
            return
        }

        let hostingController = UIHostingController(rootView: rootView)
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
    }
}
#endif
