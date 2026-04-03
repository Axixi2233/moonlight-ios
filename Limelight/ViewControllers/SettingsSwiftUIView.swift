import UIKit
#if canImport(SwiftUI)
import SwiftUI
import VideoToolbox

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
    var rendererSelection: Int = 0
    var supportsMetalRenderer: Bool = false
    var supportsMetalFx: Bool = false
    var supportsPictureInPicture: Bool = false
    var metalFxScalingSelection: Int = 0
    var metalFxSharpenSelection: Int = 1
    var metalFxColorModeSelection: Int = 0
    var pictureInPictureEnabled: Bool = false
    var streamOrientationSelection: Int = 0
    var gameMenuShortcutSelection: Int = 0
    var longPressStartForGameMenuEnabled: Bool = false
    var audioHapticsEnabled: Bool = false
    var audioHapticsOutputTarget: Int = 0
    var audioHapticsStrength: Int = 100
    var audioHapticsVoiceFilterSelection: Int = 0
    var audioHapticsKeepControllerRumble: Bool = false
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
    @Published var rendererSelection: Int = 0
    @Published var supportsMetalRenderer: Bool = false
    @Published var supportsMetalFx: Bool = false
    @Published var supportsPictureInPicture: Bool = false
    @Published var metalFxScalingSelection: Int = 0
    @Published var metalFxSharpenSelection: Int = 1
    @Published var metalFxColorModeSelection: Int = 0
    @Published var pictureInPictureEnabled: Bool = false
    @Published var streamOrientationSelection: Int = 0
    @Published var gameMenuShortcutSelection: Int = 0
    @Published var longPressStartForGameMenuEnabled: Bool = false
    @Published var audioHapticsEnabled: Bool = false
    @Published var audioHapticsOutputTarget: Int = 0
    @Published var audioHapticsStrength: Double = 100
    @Published var audioHapticsVoiceFilterSelection: Int = 0
    @Published var audioHapticsKeepControllerRumble: Bool = false
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
        rendererSelection = snapshot.rendererSelection
        supportsMetalRenderer = snapshot.supportsMetalRenderer
        supportsMetalFx = snapshot.supportsMetalFx
        supportsPictureInPicture = snapshot.supportsPictureInPicture
        metalFxScalingSelection = snapshot.metalFxScalingSelection
        metalFxSharpenSelection = snapshot.metalFxSharpenSelection
        metalFxColorModeSelection = snapshot.metalFxColorModeSelection
        pictureInPictureEnabled = snapshot.pictureInPictureEnabled
        streamOrientationSelection = snapshot.streamOrientationSelection
        gameMenuShortcutSelection = snapshot.gameMenuShortcutSelection
        longPressStartForGameMenuEnabled = snapshot.longPressStartForGameMenuEnabled
        audioHapticsEnabled = snapshot.audioHapticsEnabled
        audioHapticsOutputTarget = snapshot.audioHapticsOutputTarget
        audioHapticsStrength = Double(snapshot.audioHapticsStrength)
        audioHapticsVoiceFilterSelection = snapshot.audioHapticsVoiceFilterSelection
        audioHapticsKeepControllerRumble = snapshot.audioHapticsKeepControllerRumble
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
        snapshot.rendererSelection = rendererSelection
        snapshot.supportsMetalRenderer = supportsMetalRenderer
        snapshot.supportsMetalFx = supportsMetalFx
        snapshot.supportsPictureInPicture = supportsPictureInPicture
        snapshot.metalFxScalingSelection = metalFxScalingSelection
        snapshot.metalFxSharpenSelection = metalFxSharpenSelection
        snapshot.metalFxColorModeSelection = metalFxColorModeSelection
        snapshot.pictureInPictureEnabled = pictureInPictureEnabled
        snapshot.streamOrientationSelection = streamOrientationSelection
        snapshot.gameMenuShortcutSelection = gameMenuShortcutSelection
        snapshot.longPressStartForGameMenuEnabled = longPressStartForGameMenuEnabled
        snapshot.audioHapticsEnabled = audioHapticsEnabled
        snapshot.audioHapticsOutputTarget = audioHapticsOutputTarget
        snapshot.audioHapticsStrength = Int(audioHapticsStrength.rounded())
        snapshot.audioHapticsVoiceFilterSelection = audioHapticsVoiceFilterSelection
        snapshot.audioHapticsKeepControllerRumble = audioHapticsKeepControllerRumble
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                colorScheme == .dark
                    ? Color(red: 0.14, green: 0.12, blue: 0.20)
                    : Color(red: 0.95, green: 0.89, blue: 0.99),
                colorScheme == .dark
                    ? Color(red: 0.18, green: 0.15, blue: 0.27)
                    : Color(red: 0.86, green: 0.78, blue: 0.98),
                colorScheme == .dark
                    ? Color(red: 0.26, green: 0.22, blue: 0.39)
                    : Color(red: 0.70, green: 0.63, blue: 0.93)
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
    @State private var pendingSelectionIndex: Int?

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
        .sheet(
            isPresented: $isPresentingSelectionSheet,
            onDismiss: {
                guard let pendingSelectionIndex else { return }
                self.pendingSelectionIndex = nil
                DispatchQueue.main.async {
                    onSelect(pendingSelectionIndex)
                }
            }
        ) {
            ChoiceSelectionSheet(
                title: title,
                subtitle: subtitle,
                options: options,
                selectedIndex: selectedIndex,
                onSelect: { index in
                    pendingSelectionIndex = index
                },
                isDisabled: isDisabled
            )
        }
    }
}

@available(iOS 13.0, *)
private struct CustomResolutionSheet: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var colorScheme

    @Binding var widthText: String
    @Binding var heightText: String
    let currentResolutionLabel: String
    let maxDimension: Int
    let onApply: (Int, Int) -> Void

    private var parsedWidth: Int? {
        Int(widthText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var parsedHeight: Int? {
        Int(heightText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var canApply: Bool {
        guard let parsedWidth, let parsedHeight else {
            return false
        }
        return parsedWidth > 0 && parsedHeight > 0
    }

    private var titleColor: Color {
        colorScheme == .dark
            ? Color(red: 0.95, green: 0.92, blue: 1.00)
            : Color(red: 0.20, green: 0.15, blue: 0.31)
    }

    private var subtitleColor: Color {
        colorScheme == .dark
            ? Color(red: 0.78, green: 0.74, blue: 0.88)
            : Color(red: 0.36, green: 0.31, blue: 0.47)
    }

    private var accentLabelColor: Color {
        colorScheme == .dark
            ? Color(red: 0.78, green: 0.70, blue: 0.96)
            : Color(red: 0.42, green: 0.36, blue: 0.54)
    }

    private var cardFillColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.72)
    }

    private var noteCardFillColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.68)
    }

    private var cardStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.55)
    }

    private var textFieldFillColor: Color {
        colorScheme == .dark
            ? Color(red: 0.17, green: 0.15, blue: 0.24)
            : Color.white.opacity(0.94)
    }

    private var textFieldStrokeColor: Color {
        colorScheme == .dark
            ? Color(red: 0.43, green: 0.37, blue: 0.58)
            : Color(red: 0.79, green: 0.73, blue: 0.90)
    }

    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.28) : Color.black.opacity(0.06)
    }

    var body: some View {
        NavigationView {
            ZStack {
                SettingsPurpleBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(SettingsLocalized("settings.custom_resolution.alert_title"))
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(titleColor)

                            Text(SettingsLocalized("settings.custom_resolution.subtitle"))
                                .font(.subheadline)
                                .foregroundColor(subtitleColor)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text(SettingsLocalized("settings.custom_resolution.current"))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(accentLabelColor)

                            Text(currentResolutionLabel)
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundColor(titleColor)

                            Text(SettingsLocalizedFormat("settings.custom_resolution.range", maxDimension))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(cardFillColor)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(cardStrokeColor, lineWidth: 1)
                        )
                        .shadow(color: cardShadowColor, radius: 12, x: 0, y: 6)

                        HStack(alignment: .top, spacing: 12) {
                            resolutionField(
                                title: SettingsLocalized("settings.custom_resolution.width_label"),
                                placeholder: SettingsLocalized("settings.custom_resolution.width_placeholder"),
                                text: $widthText
                            )

                            resolutionField(
                                title: SettingsLocalized("settings.custom_resolution.height_label"),
                                placeholder: SettingsLocalized("settings.custom_resolution.height_placeholder"),
                                text: $heightText
                            )
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                Text(SettingsLocalized("settings.custom_resolution.note_title"))
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(accentLabelColor)

                            Text(SettingsLocalized("settings.custom_resolution.note_body"))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(noteCardFillColor)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(cardStrokeColor, lineWidth: 1)
                        )
                        .shadow(color: cardShadowColor, radius: 12, x: 0, y: 6)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                }
            }
            .navigationBarTitle(Text(SettingsLocalized("settings.custom_resolution.alert_title")), displayMode: .inline)
            .navigationBarItems(
                leading: Button(SettingsLocalized("common.cancel")) {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(SettingsLocalized("common.done")) {
                    guard let parsedWidth, let parsedHeight else { return }
                    let clampedWidth = min(max(parsedWidth, 256), maxDimension)
                    let clampedHeight = min(max(parsedHeight, 256), maxDimension)
                    onApply(clampedWidth, clampedHeight)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(!canApply)
            )
        }
    }

    private func resolutionField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(accentLabelColor)

            TextField(placeholder, text: text)
                .keyboardType(.numberPad)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .foregroundColor(titleColor)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(textFieldFillColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(textFieldStrokeColor, lineWidth: 1)
                )
                .font(.system(size: 18, weight: .semibold, design: .rounded))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(cardStrokeColor, lineWidth: 1)
        )
        .shadow(color: cardShadowColor, radius: 12, x: 0, y: 6)
    }
}

@available(iOS 13.0, *)
private struct SettingsRootView: View {
    @ObservedObject var model: SettingsFormViewModel
    let openExternalURL: (String) -> Void

    @State private var isPresentingCustomResolutionSheet = false
    @State private var customResolutionWidthText = ""
    @State private var customResolutionHeightText = ""

    private var maxCustomResolutionDimension: Int {
        if #available(iOS 11.0, tvOS 11.0, *), VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC) {
            return 8192
        }
        return 4096
    }

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
                            presentCustomResolutionSheet()
                        } else {
                            model.selectedResolutionIndex = index
                        }
                    } isDisabled: { index in
                        index == 5 && !model.isFourKResolutionEnabled
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
                    if model.supportsMetalRenderer {
                        segmentedSection(
                            title: SettingsLocalized("settings.renderer.title"),
                            description: SettingsLocalized("settings.renderer.description"),
                            selection: $model.rendererSelection,
                            labels: model.rendererTitles
                        )

                        if model.rendererSelection == 1 && model.supportsMetalFx {
                            segmentedSection(
                                title: SettingsLocalized("settings.metalfx_scaling.title"),
                                description: SettingsLocalized("settings.metalfx_scaling.description"),
                                selection: metalFxScalingSelection(),
                                labels: model.metalFxScalingTitles
                            )

                            segmentedSection(
                                title: SettingsLocalized("settings.metalfx_color_mode.title"),
                                description: SettingsLocalized("settings.metalfx_color_mode.description"),
                                selection: $model.metalFxColorModeSelection,
                                labels: model.metalFxColorModeTitles
                            )

                            segmentedSection(
                                title: SettingsLocalized("settings.metalfx_sharpen.title"),
                                description: SettingsLocalized("settings.metalfx_sharpen.description"),
                                selection: $model.metalFxSharpenSelection,
                                labels: model.metalFxSharpenTitles
                            )
                        }
                    }

                    if model.hdrSupported {
                        Toggle("HDR (Beta)", isOn: $model.enableHdr).font(.headline)
                    } else {
                        Text(SettingsLocalized("settings.hdr.unsupported"))
                            .foregroundColor(.secondary)
                    }

                    segmentedSection(title: SettingsLocalized("settings.frame_pacing.title"), selection: boolSelection($model.useFramePacing), labels: [SettingsLocalized("settings.frame_pacing.low_latency"), SettingsLocalized("settings.frame_pacing.smooth_video")])

                    segmentedSection(
                        title: SettingsLocalized("settings.stream_orientation.title"),
                        selection: $model.streamOrientationSelection,
                        labels: model.streamOrientationTitles
                    )

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
                    descriptiveToggle(title: SettingsLocalized("settings.capture_mouse_cursor.toggle"),
                                      description: SettingsLocalized("settings.capture_mouse_cursor.description"),
                                      isOn: $model.captureMouseCursor)
                    descriptiveToggle(title: SettingsLocalized("settings.remote_mouse_mode.toggle"),
                                      description: SettingsLocalized("settings.remote_mouse_mode.description"),
                                      isOn: $model.remoteMouseMode)
                    if !model.remoteMouseMode {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.relativeMouseSensitivityLabel)
                                .font(.headline)
                            Slider(value: $model.relativeMouseSensitivity, in: 50...300, step: 1)
                        }
                    }
                    segmentedSection(
                        title: SettingsLocalized("settings.game_menu_shortcut.title"),
                        description: SettingsLocalized("settings.game_menu_shortcut.description"),
                        selection: $model.gameMenuShortcutSelection,
                        labels: model.gameMenuShortcutTitles
                    )
                    descriptiveToggle(title: SettingsLocalized("settings.game_menu_start_hold.toggle"),
                                      description: SettingsLocalized("settings.game_menu_start_hold.description"),
                                      isOn: $model.longPressStartForGameMenuEnabled)
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
                    if model.supportsPictureInPicture {
                        descriptiveToggle(title: SettingsLocalized("settings.picture_in_picture.toggle"),
                                          description: SettingsLocalized("settings.picture_in_picture.description"),
                                          isOn: $model.pictureInPictureEnabled)
                    }
                    descriptiveToggle(title: SettingsLocalized("settings.external_monitor.toggle"),
                                      description: SettingsLocalized("settings.external_monitor.description"),
                                      isOn: $model.externalMonitor)
                    Toggle(SettingsLocalized("settings.virtual_display.toggle"), isOn: virtualDisplayToggle()).font(.headline)
                    descriptiveToggle(title: SettingsLocalized("settings.audio_haptics.enable"),
                                      description: SettingsLocalized("settings.audio_haptics.enable_description"),
                                      isOn: $model.audioHapticsEnabled)
                    if model.audioHapticsEnabled {
                        segmentedSection(
                            title: SettingsLocalized("settings.audio_haptics.output_target"),
                            selection: $model.audioHapticsOutputTarget,
                            labels: model.audioHapticsOutputTargetTitles
                        )
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.audioHapticsStrengthLabel)
                                .font(.headline)
                            Slider(value: $model.audioHapticsStrength, in: 25...200, step: 5)
                        }
                        segmentedSection(
                            title: SettingsLocalized("settings.audio_haptics.voice_filter"),
                            selection: $model.audioHapticsVoiceFilterSelection,
                            labels: model.audioHapticsVoiceFilterTitles
                        )
                        if model.audioHapticsOutputTarget == 1 {
                            descriptiveToggle(title: SettingsLocalized("settings.audio_haptics.keep_controller_rumble"),
                                              description: SettingsLocalized("settings.audio_haptics.keep_controller_rumble_description"),
                                              isOn: $model.audioHapticsKeepControllerRumble)
                        }
                    }
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
                    descriptiveToggle(title: SettingsLocalized("settings.stats_overlay.toggle"),
                                      description: SettingsLocalized("settings.stats_overlay.description"),
                                      isOn: $model.statsOverlay)
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
        .sheet(isPresented: $isPresentingCustomResolutionSheet) {
            CustomResolutionSheet(
                widthText: $customResolutionWidthText,
                heightText: $customResolutionHeightText,
                currentResolutionLabel: model.customResolutionLabel,
                maxDimension: maxCustomResolutionDimension
            ) { width, height in
                model.updateCustomResolution(width: width, height: height)
            }
        }
    }

    private func presentCustomResolutionSheet() {
        customResolutionWidthText = model.customResolutionWidth > 0 ? String(model.customResolutionWidth) : ""
        customResolutionHeightText = model.customResolutionHeight > 0 ? String(model.customResolutionHeight) : ""
        isPresentingCustomResolutionSheet = true
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

    private func metalFxScalingSelection() -> Binding<Int> {
        Binding(
            get: {
                switch model.metalFxScalingSelection {
                    case 3:
                        return 0
                    case 1:
                        return 2
                    case 2:
                        return 3
                    case 0:
                        fallthrough
                    default:
                        return 1
                }
            },
            set: { newIndex in
                switch newIndex {
                    case 0:
                        model.metalFxScalingSelection = 3
                    case 2:
                        model.metalFxScalingSelection = 1
                    case 3:
                        model.metalFxScalingSelection = 2
                    case 1:
                        fallthrough
                    default:
                        model.metalFxScalingSelection = 0
                }
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

    private func segmentedSection(title: String, description: String? = nil, selection: Binding<Int>, labels: [String], falseLabelIsEnabled: Bool = false, reverseBoolMeaning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            settingHeader(title: title, description: description)
            Picker(title, selection: selection) {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    Text(label).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    @ViewBuilder
    private func settingHeader(title: String, description: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            if let description, !description.isEmpty {
                Text(description)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func descriptiveToggle(title: String, description: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            settingHeader(title: title, description: description)
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

    var rendererTitles: [String] {
        [
            SettingsLocalized("settings.renderer.system"),
            SettingsLocalized("settings.renderer.metal")
        ]
    }

    var streamOrientationTitles: [String] {
        [
            SettingsLocalized("common.auto"),
            SettingsLocalized("settings.stream_orientation.landscape"),
            SettingsLocalized("settings.stream_orientation.portrait")
        ]
    }

    var gameMenuShortcutTitles: [String] {
        [
            SettingsLocalized("settings.game_menu_shortcut.none"),
            SettingsLocalized("settings.game_menu_shortcut.escape"),
            SettingsLocalized("settings.game_menu_shortcut.ctrl_alt_shift_q")
        ]
    }

    var audioHapticsOutputTargetTitles: [String] {
        [
            SettingsLocalized("common.device"),
            SettingsLocalized("common.controller")
        ]
    }

    var audioHapticsVoiceFilterTitles: [String] {
        [
            SettingsLocalized("common.off"),
            SettingsLocalized("settings.audio_haptics.voice_filter.low"),
            SettingsLocalized("settings.audio_haptics.voice_filter.medium"),
            SettingsLocalized("settings.audio_haptics.voice_filter.high")
        ]
    }

    var audioHapticsStrengthLabel: String {
        SettingsLocalizedFormat("settings.audio_haptics.strength", Int(audioHapticsStrength.rounded()))
    }

    var rendererTitle: String {
        guard rendererTitles.indices.contains(rendererSelection) else {
            return SettingsLocalized("settings.renderer.system")
        }
        return rendererTitles[rendererSelection]
    }

    var metalFxScalingTitles: [String] {
        [
            SettingsLocalized("common.off"),
            SettingsLocalized("common.auto"),
            SettingsLocalized("settings.metalfx_scaling.1_5x"),
            SettingsLocalized("settings.metalfx_scaling.2_0x")
        ]
    }

    var metalFxScalingTitle: String {
        let displayIndex: Int
        switch metalFxScalingSelection {
            case 3:
                displayIndex = 0
            case 1:
                displayIndex = 2
            case 2:
                displayIndex = 3
            case 0:
                fallthrough
            default:
                displayIndex = 1
        }

        guard metalFxScalingTitles.indices.contains(displayIndex) else {
            return SettingsLocalized("common.auto")
        }
        return metalFxScalingTitles[displayIndex]
    }

    var metalFxSharpenTitles: [String] {
        [
            SettingsLocalized("common.off"),
            SettingsLocalized("settings.metalfx_sharpen.standard"),
            SettingsLocalized("settings.metalfx_sharpen.strong")
        ]
    }

    var metalFxColorModeTitles: [String] {
        [
            SettingsLocalized("settings.metalfx_color_mode.perceptual"),
            SettingsLocalized("settings.metalfx_color_mode.linear"),
            SettingsLocalized("settings.metalfx_color_mode.hdr")
        ]
    }

    var metalFxSharpenTitle: String {
        guard metalFxSharpenTitles.indices.contains(metalFxSharpenSelection) else {
            return SettingsLocalized("settings.metalfx_sharpen.standard")
        }
        return metalFxSharpenTitles[metalFxSharpenSelection]
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
