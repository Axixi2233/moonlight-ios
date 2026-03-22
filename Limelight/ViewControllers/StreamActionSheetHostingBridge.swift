import SwiftUI
import UIKit

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
}

@objcMembers
final class StreamShortcutPanelItem: NSObject {
    var identifier: String = ""
    var title: String = ""
    var subtitle: String = ""
    var symbolName: String = "command"
}

@objc protocol StreamShortcutPanelHostingViewControllerDelegate: NSObjectProtocol {
    func streamShortcutPanelHostingViewControllerDidCancel(_ controller: StreamShortcutPanelHostingViewController)
    func streamShortcutPanelHostingViewController(_ controller: StreamShortcutPanelHostingViewController, didSelectItemWithIdentifier identifier: String)
}

@objc protocol StreamVirtualKeyboardPanelHostingViewControllerDelegate: NSObjectProtocol {
    func streamVirtualKeyboardPanelHostingViewControllerDidCancel(_ controller: StreamVirtualKeyboardPanelHostingViewController)
    func streamVirtualKeyboardPanelHostingViewController(_ controller: StreamVirtualKeyboardPanelHostingViewController, didSubmitKeyCodes keyCodes: [NSNumber])
    func streamVirtualKeyboardPanelHostingViewControllerDidRequestSystemKeyboard(_ controller: StreamVirtualKeyboardPanelHostingViewController)
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
    @Published var touchModeToastText: String? = nil
}

private final class StreamShortcutPanelViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var items: [StreamShortcutPanelItem] = []
}

private final class StreamVirtualKeyboardPanelViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var combinationModeEnabled: Bool = false
    @Published var fnModeEnabled: Bool = false
    @Published var selectedModifierKeyCodes: Set<Int> = []
}

private struct SegmentedOptionsControl: UIViewRepresentable {
    let items: [String]
    let selection: Int
    let onSelectionChange: (Int) -> Void

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
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
        ], for: .normal)
        control.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("触控模式")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.72))

            SegmentedOptionsControl(items: ["触控板", "鼠标", "多点触控"],
                                    selection: viewModel.touchModeSelection) { newValue in
                guard viewModel.touchModeSelection != newValue else {
                    return
                }
                viewModel.touchModeSelection = newValue
                onTouchModeChange(newValue)
            }
            .frame(height: 38)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var videoAlignmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("画面位置")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.72))

            SegmentedOptionsControl(items: ["居中", "顶部居中", "底部居中"],
                                    selection: viewModel.videoAlignmentSelection) { newValue in
                guard viewModel.videoAlignmentSelection != newValue else {
                    return
                }
                viewModel.videoAlignmentSelection = newValue
                onVideoAlignmentChange(newValue)
            }
            .frame(height: 38)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var videoAlignmentMarginSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("画面位置边距 \(Int(viewModel.videoAlignmentMargin))")
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
            Text("性能信息")
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
                Text("显示编码/客户端延迟")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .accentColor(Color(red: 0.50, green: 0.45, blue: 0.94))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var performanceOverlayPositionSection: some View {
        let items = [
            ["顶部居中", "顶部居左", "顶部居右"],
            ["底部居中", "底部居左", "底部居右"]
        ]

        return VStack(alignment: .leading, spacing: 10) {
            Text("性能信息位置")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.72))

            VStack(spacing: 8) {
                ForEach(0..<items.count, id: \.self) { rowIndex in
                    HStack(spacing: 8) {
                        ForEach(0..<items[rowIndex].count, id: \.self) { columnIndex in
                            let index = rowIndex * 3 + columnIndex
                            performanceOverlayPositionButton(index: index, title: items[rowIndex][columnIndex])
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func performanceOverlayPositionButton(index: Int, title: String) -> some View {
        let isSelected = viewModel.performanceOverlayPositionSelection == index

        return Button(action: {
            guard !isSelected else {
                return
            }
            viewModel.performanceOverlayPositionSelection = index
            onPerformanceOverlayPositionChange(index)
        }) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ?
                              Color(red: 0.50, green: 0.45, blue: 0.94) :
                              Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(isSelected ? 0.0 : 0.10), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var performanceOverlayMarginSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("性能信息边距 \(Int(viewModel.performanceOverlayMargin))")
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
    let onCancel: () -> Void

    private let horizontalPadding: CGFloat = 18
    private let verticalSpacing: CGFloat = 12
    private let horizontalSpacing: CGFloat = 12
    private let cardHeight: CGFloat = 88

    var body: some View {
        GeometryReader { geometry in
            let columnCount = isLandscape ? 5 : 3
            let contentWidth = max(geometry.size.width - horizontalPadding * 2, 0)
            let cardWidth = max(floor((contentWidth - CGFloat(columnCount - 1) * horizontalSpacing) / CGFloat(columnCount)), 88)
            let rows = chunkedItems(columnCount: columnCount)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 18)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: verticalSpacing) {
                        ForEach(0..<rows.count, id: \.self) { rowIndex in
                            HStack(spacing: horizontalSpacing) {
                                ForEach(0..<rows[rowIndex].count, id: \.self) { itemIndex in
                                    let item = rows[rowIndex][itemIndex]
                                    StreamShortcutCardView(item: item,
                                                           width: cardWidth,
                                                           height: cardHeight) {
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
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 20)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
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

    private func chunkedItems(columnCount: Int) -> [[StreamShortcutPanelItem]] {
        guard columnCount > 0 else {
            return []
        }

        var result: [[StreamShortcutPanelItem]] = []
        var currentIndex = 0

        while currentIndex < viewModel.items.count {
            let endIndex = min(currentIndex + columnCount, viewModel.items.count)
            result.append(Array(viewModel.items[currentIndex..<endIndex]))
            currentIndex = endIndex
        }

        return result
    }
}

private struct StreamShortcutCardView: View {
    let item: StreamShortcutPanelItem
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    var body: some View {
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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if !item.subtitle.isEmpty {
                        Text(item.subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.72))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
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
            modeChip(title: "组合键模式",
                     isActive: viewModel.combinationModeEnabled,
                     activeColor: Color(red: 0.36, green: 0.36, blue: 0.68)) {
                viewModel.combinationModeEnabled.toggle()
                if !viewModel.combinationModeEnabled {
                    viewModel.selectedModifierKeyCodes.removeAll()
                }
            }

            modeChip(title: "Fn 模式",
                     isActive: viewModel.fnModeEnabled,
                     activeColor: Color(red: 0.33, green: 0.68, blue: 0.24)) {
                viewModel.fnModeEnabled.toggle()
            }

            modeChip(title: "手机输入法",
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
            return "鼠标"
        case 2:
            return "多点触控"
        default:
            return "触控板"
        }
    }

    private func showTouchModeToast(for selection: Int) {
        showToastWithText("触控模式: \(touchModeTitle(for: selection))")
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

    func configure(title: String, items: [StreamShortcutPanelItem]) {
        viewModel.title = title
        viewModel.items = items
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
