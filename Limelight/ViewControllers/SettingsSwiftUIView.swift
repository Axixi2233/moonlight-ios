import UIKit
#if canImport(SwiftUI)
import SwiftUI

@objcMembers
final class SettingsFormSnapshot: NSObject {
    var bitrateValues: [NSNumber] = []
    var bitrateSliderIndex: Int = 0
    var bitrateKbps: Int = 10000
    var bitrateMinimumKbps: Int = 10000
    var bitrateMaximumKbps: Int = 500000

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

    var absoluteTouchMode: Bool = false
    var optimizeGames: Bool = true
    var multiController: Bool = false
    var swapABXYButtons: Bool = false
    var playAudioOnPC: Bool = false
    var btMouseSupport: Bool = false
    var statsOverlay: Bool = false
    var rumblePhone: Bool = false
    var showRumblePhoneOption: Bool = false
    var multiTouchScreen: Bool = false
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

    @Published var absoluteTouchMode: Bool = false
    @Published var optimizeGames: Bool = true
    @Published var multiController: Bool = false
    @Published var swapABXYButtons: Bool = false
    @Published var playAudioOnPC: Bool = false
    @Published var btMouseSupport: Bool = false
    @Published var statsOverlay: Bool = false
    @Published var rumblePhone: Bool = false
    @Published var showRumblePhoneOption: Bool = false
    @Published var multiTouchScreen: Bool = false
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
    @Published var virtualButtonSchemeSelection: Int = 0
    @Published var virtualGamepadSchemeSelection: Int = 0
    @Published var virtualGamepadOpacity: Double = 52

    func apply(snapshot: SettingsFormSnapshot) {
        bitrateValues = snapshot.bitrateValues.map { $0.intValue }
        bitrateKbps = snapshot.bitrateKbps
        bitrateMinimumKbps = snapshot.bitrateMinimumKbps
        bitrateMaximumKbps = snapshot.bitrateMaximumKbps
        syncBitrateSliderPositionFromBitrate()

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

        absoluteTouchMode = snapshot.absoluteTouchMode
        optimizeGames = snapshot.optimizeGames
        multiController = snapshot.multiController
        swapABXYButtons = snapshot.swapABXYButtons
        playAudioOnPC = snapshot.playAudioOnPC
        btMouseSupport = snapshot.btMouseSupport
        statsOverlay = snapshot.statsOverlay
        rumblePhone = snapshot.rumblePhone
        showRumblePhoneOption = snapshot.showRumblePhoneOption
        multiTouchScreen = snapshot.multiTouchScreen
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
        snapshot.absoluteTouchMode = absoluteTouchMode
        snapshot.optimizeGames = optimizeGames
        snapshot.multiController = multiController
        snapshot.swapABXYButtons = swapABXYButtons
        snapshot.playAudioOnPC = playAudioOnPC
        snapshot.btMouseSupport = btMouseSupport
        snapshot.statsOverlay = statsOverlay
        snapshot.rumblePhone = rumblePhone
        snapshot.showRumblePhoneOption = showRumblePhoneOption
        snapshot.multiTouchScreen = multiTouchScreen
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
        snapshot.virtualButtonSchemeSelection = virtualButtonSchemeSelection
        snapshot.virtualGamepadSchemeSelection = virtualGamepadSchemeSelection
        snapshot.virtualGamepadOpacity = Int(virtualGamepadOpacity.rounded())
        return snapshot
    }

    var bitrateLabel: String {
        String(format: "码率: %.1f Mbps", Double(bitrateKbps) / 1000.0)
    }

    var touchSensitivityLabel: String {
        String(format: "触控灵敏度(百分比): %.1f", touchSensitivity)
    }

    var customResolutionLabel: String {
        if customResolutionWidth > 0, customResolutionHeight > 0 {
            return "\(customResolutionWidth) x \(customResolutionHeight)"
        }
        return "未设置"
    }

    var selectedResolutionTitle: String {
        let clampedIndex = min(max(selectedResolutionIndex, 0), max(resolutionTitles.count - 1, 0))
        guard resolutionTitles.indices.contains(clampedIndex) else {
            return "未选择"
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
            .navigationBarItems(trailing: Button("完成") {
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
                Section(header: Text("画面设置")) {
                    choiceSection(
                        title: "分辨率",
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
                        Text("设置自定义分辨率: \(model.customResolutionLabel)")
                    }

//                    Button(action: {
//                        openExternalURL("https://moonlight-stream.org/custom-resolution")
//                    }) {
//                        Text("查看分辨率说明")
//                    }

                    segmentedSection(title: "帧率", selection: bindingForFramerate(), labels: model.framerateOptions.map { "\($0) FPS" })

                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.bitrateLabel)
                            .font(.headline)
                        Slider(value: bitrateSliderBinding(), in: 0...1) { _ in
                            model.updateBitrateFromSlider()
                        }
                    }

                    segmentedSection(title: "解码器", selection: codecSelection(), labels: model.codecTitles)

                    if model.hdrSupported {
                        Toggle("HDR (Beta)", isOn: $model.enableHdr).font(.headline)
                    } else {
                        Text("HDR 当前设备不支持")
                            .foregroundColor(.secondary)
                    }

                    segmentedSection(title: "视频帧数调节", selection: boolSelection($model.useFramePacing), labels: ["低延迟", "流畅视频"])
                    segmentedSection(title: "画面位置", selection: $model.videoAlignmentSelection, labels: model.videoAlignmentTitles)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("画面位置边距 \(Int(model.videoAlignmentMargin))")
                            .font(.headline)
                        Slider(value: $model.videoAlignmentMargin, in: 0...150, step: 1)
                    }
                }

                Section(header: Text("输入设置")) {
                    segmentedSection(title: "触控模式", selection: touchModeSelection(), labels: model.touchModeTitles)

                    Toggle("优化游戏设置", isOn: $model.optimizeGames).font(.headline)
                    Toggle("多控制器模式", isOn: $model.multiController).font(.headline)
                    Toggle("交换 A/B 和 X/Y 按钮", isOn: $model.swapABXYButtons).font(.headline)
                    Toggle("在电脑上播放声音", isOn: $model.playAudioOnPC).font(.headline)
                    Toggle("Citrix X1 鼠标支持", isOn: $model.btMouseSupport).font(.headline)
                    segmentedSection(title: "陀螺仪选项", selection: $model.motionMode, labels: ["自动", "设备", "手柄"])
                }

                Section(header: Text("其他设置")) {
                    if model.showRumblePhoneOption {
                        Toggle("启用机身震动", isOn: $model.rumblePhone).font(.headline)
                    }
                    Toggle("性能信息", isOn: $model.statsOverlay).font(.headline)
                    Toggle("悬浮球", isOn: $model.floatingMenuEnabled).font(.headline)
                    choiceSection(
                        title: "虚拟按钮方案",
                        subtitle: model.virtualButtonSchemeTitle,
                        options: Array(model.virtualButtonSchemeTitles.enumerated()),
                        selectedIndex: model.virtualButtonSchemeSelection
                    ) { index in
                        model.virtualButtonSchemeSelection = index
                    } isDisabled: { _ in false }
                    choiceSection(
                        title: "虚拟手柄方案",
                        subtitle: model.virtualGamepadSchemeTitle,
                        options: Array(model.virtualGamepadSchemeTitles.enumerated()),
                        selectedIndex: model.virtualGamepadSchemeSelection
                    ) { index in
                        model.virtualGamepadSchemeSelection = index
                    } isDisabled: { _ in false }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("虚拟手柄透明度 \(Int(model.virtualGamepadOpacity))%")
                            .font(.headline)
                        Slider(value: $model.virtualGamepadOpacity, in: 5...100, step: 1)
                    }
                    choiceSection(
                        title: "性能信息位置",
                        subtitle: model.performanceOverlayPositionTitle,
                        options: Array(model.performanceOverlayPositionTitles.enumerated()),
                        selectedIndex: model.performanceOverlayPositionSelection
                    ) { index in
                        model.performanceOverlayPositionSelection = index
                    } isDisabled: { _ in false }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("性能信息边距 \(Int(model.performanceOverlayMargin))")
                            .font(.headline)
                        Slider(value: $model.performanceOverlayMargin, in: 0...150, step: 1)
                    }
                    Toggle("外接显示器模式", isOn: $model.externalMonitor).font(.headline)
                    Toggle("虚拟显示器", isOn: virtualDisplayToggle()).font(.headline)
                    Toggle("启用触控灵敏度", isOn: $model.enableTouchSensitivity).font(.headline)
                    Toggle("触控灵敏度全局生效", isOn: $model.touchSensitivityGlobal).font(.headline)
                    if model.enableTouchSensitivity {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.touchSensitivityLabel)
                                .font(.headline)
                            Slider(value: $model.touchSensitivity, in: 10...300, step: 1)
                        }
                    }
                }

//                Section(header: Text("关于")) {
//                    Button(action: {
//                        openExternalURL("https://space.bilibili.com/16893379")
//                    }) {
//                        Text("阿西西的日常@2025")
//                    }
//                }
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
    var touchModeTitles: [String] {
        ["触控板", "普通鼠标", "多点触控"]
    }

    var touchModeSelectionIndex: Int {
        if !absoluteTouchMode {
            return 0
        }
        return multiTouchScreen ? 2 : 1
    }

    var touchModeTitle: String {
        guard touchModeTitles.indices.contains(touchModeSelectionIndex) else {
            return "触控板"
        }
        return touchModeTitles[touchModeSelectionIndex]
    }

    func setTouchModeSelectionIndex(_ index: Int) {
        switch index {
        case 0:
            absoluteTouchMode = false
            multiTouchScreen = false
        case 1:
            absoluteTouchMode = true
            multiTouchScreen = false
        case 2:
            absoluteTouchMode = true
            multiTouchScreen = true
        default:
            absoluteTouchMode = false
            multiTouchScreen = false
        }
    }

    var codecDisplayTitle: String {
        guard let index = codecValues.firstIndex(of: preferredCodecValue), codecTitles.indices.contains(index) else {
            return "自动"
        }
        return codecTitles[index]
    }

    var selectedCodecIndex: Int {
        codecValues.firstIndex(of: preferredCodecValue) ?? max(codecValues.count - 1, 0)
    }

    var videoAlignmentTitles: [String] {
        ["居中", "顶部居中", "底部居中"]
    }

    var performanceOverlayPositionTitles: [String] {
        ["顶部居中", "顶部居左", "顶部居右", "底部居中", "底部居左", "底部居右"]
    }

    var performanceOverlayPositionTitle: String {
        guard performanceOverlayPositionTitles.indices.contains(performanceOverlayPositionSelection) else {
            return "顶部居中"
        }
        return performanceOverlayPositionTitles[performanceOverlayPositionSelection]
    }

    var virtualButtonSchemeTitles: [String] {
        ["方案 1", "方案 2", "方案 3", "方案 4", "方案 5"]
    }

    var virtualButtonSchemeTitle: String {
        guard virtualButtonSchemeTitles.indices.contains(virtualButtonSchemeSelection) else {
            return "方案 1"
        }
        return virtualButtonSchemeTitles[virtualButtonSchemeSelection]
    }

    var virtualGamepadSchemeTitles: [String] {
        ["方案 1", "方案 2", "方案 3", "方案 4", "方案 5"]
    }

    var virtualGamepadSchemeTitle: String {
        guard virtualGamepadSchemeTitles.indices.contains(virtualGamepadSchemeSelection) else {
            return "方案 1"
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
