import UIKit
#if canImport(SwiftUI)
import SwiftUI

private func MainFrameHostListLocalized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

@objcMembers
final class MainFrameHostListItemSnapshot: NSObject {
    var title: String = ""
    var subtitle: String = ""
    var statusText: String = ""
    var statusStyle: Int = 0
    var showsActivity: Bool = false
    var addCard: Bool = false
}

@objc protocol MainFrameHostListHostingViewControllerDelegate: NSObjectProtocol {
    func mainFrameHostListHostingViewController(_ controller: MainFrameHostListHostingViewController, didSelectItemAt index: Int)
    func mainFrameHostListHostingViewController(_ controller: MainFrameHostListHostingViewController, didLongPressItemAt index: Int)
}

@available(iOS 13.0, *)
private struct MainFrameHostListRootView: View {
    @Environment(\.colorScheme) private var colorScheme
    let items: [MainFrameHostListItemSnapshot]
    let onSelect: (Int) -> Void
    let onLongPress: (Int) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 18) {
                if items.isEmpty {
                    emptyState
                } else {
                    headerSection

                    VStack(spacing: 16) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            MainFrameHostRowView(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelect(index)
                                }
                                .onLongPressGesture(minimumDuration: 0.6) {
                                    if !item.addCard {
                                        onLongPress(index)
                                    }
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
        .background(Color.clear)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                colorScheme == .dark ? Color(red: 0.20, green: 0.18, blue: 0.28) : Color(red: 0.94, green: 0.92, blue: 1.0),
                                colorScheme == .dark ? Color(red: 0.14, green: 0.13, blue: 0.22) : Color.white.opacity(0.95)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 78, height: 78)

                Image(systemName: "display")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? Color(red: 0.82, green: 0.75, blue: 0.98) : Color(red: 0.34, green: 0.28, blue: 0.50))
            }

            VStack(spacing: 8) {
                Text(MainFrameHostListLocalized("home.empty.title"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.95) : Color(red: 0.26, green: 0.20, blue: 0.37))
                    .multilineTextAlignment(.center)

                Text(MainFrameHostListLocalized("home.empty.subtitle"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.70) : Color(red: 0.40, green: 0.34, blue: 0.52))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 34)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.90),
                            colorScheme == .dark ? Color(red: 0.16, green: 0.14, blue: 0.24).opacity(0.92) : Color(red: 0.97, green: 0.95, blue: 1.0).opacity(0.84)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.74), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.05), radius: 16, x: 0, y: 8)
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(MainFrameHostListLocalized("home.list.header.title"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.96) : Color(red: 0.24, green: 0.18, blue: 0.35))

                Text(MainFrameHostListLocalized("home.list.header.subtitle"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.68) : Color(red: 0.41, green: 0.35, blue: 0.54))
                    .lineSpacing(2)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Image(systemName: "display.2")
                    .font(.system(size: 13, weight: .semibold))
                Text(String(format: MainFrameHostListLocalized("home.list.header.count"), items.count))
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(colorScheme == .dark ? Color(red: 0.87, green: 0.82, blue: 1.0) : Color(red: 0.35, green: 0.28, blue: 0.49))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.88))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.72), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }
}

@available(iOS 13.0, *)
private struct MainFrameHostRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: MainFrameHostListItemSnapshot

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 56, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(iconStrokeColor, lineWidth: 1)
                    )

                Circle()
                    .fill(iconInnerBackground)
                    .frame(width: 36, height: 36)

                if item.showsActivity {
                    MainFrameActivityIndicator()
                } else {
                    Image(systemName: item.addCard ? "plus" : "desktopcomputer")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconForeground)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 10) {
                    Text(item.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.95) : Color(red: 0.26, green: 0.20, blue: 0.37))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !item.statusText.isEmpty {
                        Text(item.statusText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(statusForeground)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(statusBackground)
                            .clipShape(Capsule())
                            .fixedSize(horizontal: true, vertical: true)
                    }
                }

                Text(item.subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.70) : Color(red: 0.40, green: 0.34, blue: 0.52))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.24) : Color.black.opacity(0.22))
                .frame(width: 18, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.72), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.06), radius: 14, x: 0, y: 6)
    }

    private var cardBackground: LinearGradient {
        return LinearGradient(
            gradient: Gradient(colors: [
                colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.88),
                colorScheme == .dark ? Color(red: 0.16, green: 0.14, blue: 0.24).opacity(0.92) : Color(red: 0.96, green: 0.93, blue: 1.00).opacity(0.78)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var iconBackground: LinearGradient {
        let colors: [Color]
        if item.addCard {
            colors = [
                Color(red: 0.41, green: 0.52, blue: 0.95),
                Color(red: 0.29, green: 0.37, blue: 0.80)
            ]
        }
        else {
            switch item.statusStyle {
            case 1:
                colors = [
                    Color(red: 0.24, green: 0.63, blue: 0.40),
                    Color(red: 0.15, green: 0.43, blue: 0.27)
                ]
            case 2:
                colors = [
                    colorScheme == .dark ? Color(red: 0.38, green: 0.40, blue: 0.46) : Color(red: 0.72, green: 0.74, blue: 0.80),
                    colorScheme == .dark ? Color(red: 0.24, green: 0.26, blue: 0.31) : Color(red: 0.53, green: 0.56, blue: 0.63)
                ]
            default:
                colors = [
                    colorScheme == .dark ? Color(red: 0.34, green: 0.31, blue: 0.46) : Color(red: 0.63, green: 0.57, blue: 0.82),
                    colorScheme == .dark ? Color(red: 0.21, green: 0.20, blue: 0.31) : Color(red: 0.45, green: 0.41, blue: 0.66)
                ]
            }
        }

        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var iconInnerBackground: Color {
        if item.addCard {
            return Color.white.opacity(colorScheme == .dark ? 0.18 : 0.24)
        }

        return Color.white.opacity(colorScheme == .dark ? 0.14 : 0.22)
    }

    private var iconStrokeColor: Color {
        Color.white.opacity(colorScheme == .dark ? 0.10 : 0.28)
    }

    private var iconForeground: Color {
        if item.addCard {
            return Color.white.opacity(0.96)
        }

        switch item.statusStyle {
        case 1:
            return colorScheme == .dark ? Color(red: 0.89, green: 0.98, blue: 0.91) : Color.white.opacity(0.98)
        case 2:
            return colorScheme == .dark ? Color(red: 0.95, green: 0.96, blue: 0.98) : Color.white.opacity(0.98)
        default:
            return colorScheme == .dark ? Color(red: 0.94, green: 0.92, blue: 1.00) : Color.white.opacity(0.98)
        }
    }

    private var statusBackground: Color {
        switch item.statusStyle {
        case 1:
            return colorScheme == .dark ? Color(red: 0.12, green: 0.25, blue: 0.18) : Color(red: 0.87, green: 0.96, blue: 0.90)
        case 2:
            return colorScheme == .dark ? Color(red: 0.18, green: 0.19, blue: 0.23) : Color(red: 0.92, green: 0.93, blue: 0.96)
        default:
            return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
        }
    }

    private var statusForeground: Color {
        switch item.statusStyle {
        case 1:
            return colorScheme == .dark ? Color(red: 0.60, green: 0.86, blue: 0.67) : Color(red: 0.18, green: 0.46, blue: 0.28)
        case 2:
            return colorScheme == .dark ? Color(red: 0.82, green: 0.85, blue: 0.90) : Color(red: 0.40, green: 0.43, blue: 0.49)
        default:
            return colorScheme == .dark ? Color.white.opacity(0.72) : Color(red: 0.34, green: 0.30, blue: 0.42)
        }
    }
}

@available(iOS 13.0, *)
private struct MainFrameActivityIndicator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let view = UIActivityIndicatorView(style: .large)
        view.color = .white
        view.startAnimating()
        return view
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        uiView.startAnimating()
    }
}

@objcMembers
@available(iOS 13.0, *)
final class MainFrameHostListHostingViewController: UIViewController {
    weak var delegate: MainFrameHostListHostingViewControllerDelegate?

    private var items: [MainFrameHostListItemSnapshot] = []
    private var hostingController: UIHostingController<MainFrameHostListRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        installHostingControllerIfNeeded()
    }

    func configure(withItems items: [MainFrameHostListItemSnapshot]) {
        self.items = items
        if isViewLoaded {
            installHostingControllerIfNeeded()
        }
    }

    private func installHostingControllerIfNeeded() {
        let rootView = MainFrameHostListRootView(
            items: items,
            onSelect: { [weak self] index in
                guard let self else { return }
                self.delegate?.mainFrameHostListHostingViewController(self, didSelectItemAt: index)
            },
            onLongPress: { [weak self] index in
                guard let self else { return }
                self.delegate?.mainFrameHostListHostingViewController(self, didLongPressItemAt: index)
            }
        )

        if let hostingController {
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
