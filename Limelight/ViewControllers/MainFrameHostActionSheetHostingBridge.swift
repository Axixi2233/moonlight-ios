import UIKit
#if canImport(SwiftUI)
import SwiftUI

private func MainFrameHostActionLocalized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

@objcMembers
final class MainFrameHostActionSheetItem: NSObject {
    var identifier: String = ""
    var title: String = ""
    var subtitle: String = ""
    var destructive: Bool = false
}

@objc protocol MainFrameHostActionSheetHostingViewControllerDelegate: NSObjectProtocol {
    func mainFrameHostActionSheetHostingViewController(_ controller: MainFrameHostActionSheetHostingViewController, didSelectActionWithIdentifier identifier: String)
    func mainFrameHostActionSheetHostingViewControllerDidCancel(_ controller: MainFrameHostActionSheetHostingViewController)
}

@available(iOS 13.0, *)
private struct MainFrameHostActionSheetRootView: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String
    let items: [MainFrameHostActionSheetItem]
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.22)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture(perform: onCancel)

                VStack(spacing: 0) {
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.14))
                        .frame(width: 44, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 18)

                    VStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.96) : .primary)
                            .multilineTextAlignment(.center)

                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.70) : .secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                                Button(action: {
                                    onSelect(item.identifier)
                                }) {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: item.subtitle.isEmpty ? 0 : 4) {
                                            Text(item.title)
                                                .font(.system(size: 17, weight: .semibold))
                                                .foregroundColor(item.destructive ? (colorScheme == .dark ? Color(red: 1.0, green: 0.48, blue: 0.42) : Color(red: 0.78, green: 0.18, blue: 0.14)) : (colorScheme == .dark ? Color.white.opacity(0.95) : .primary))

                                            if !item.subtitle.isEmpty {
                                                Text(item.subtitle)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.68) : .secondary)
                                            }
                                        }

                                        Spacer(minLength: 12)

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.24) : Color.black.opacity(0.22))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.94))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .frame(maxHeight: min(proxy.size.height * 0.55, 360))

                    Button(action: onCancel) {
                        Text(MainFrameHostActionLocalized("common.cancel"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.95) : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.96))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 16)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12))
                }
                .frame(maxWidth: 620)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            colorScheme == .dark ? Color(red: 0.15, green: 0.13, blue: 0.22) : Color(red: 0.97, green: 0.94, blue: 1.0),
                            colorScheme == .dark ? Color(red: 0.22, green: 0.19, blue: 0.31) : Color(red: 0.90, green: 0.85, blue: 0.99)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.clear, lineWidth: 1)
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.34 : 0.18), radius: 18, x: 0, y: -2)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

@objcMembers
@available(iOS 13.0, *)
final class MainFrameHostActionSheetHostingViewController: UIViewController {
    weak var delegate: MainFrameHostActionSheetHostingViewControllerDelegate?

    private var actionTitle: String = ""
    private var actionSubtitle: String = ""
    private var items: [MainFrameHostActionSheetItem] = []
    private var hostingController: UIHostingController<MainFrameHostActionSheetRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve

        installHostingControllerIfNeeded()
    }

    func configure(title: String, subtitle: String, items: [MainFrameHostActionSheetItem]) {
        actionTitle = title
        actionSubtitle = subtitle
        self.items = items

        if isViewLoaded {
            installHostingControllerIfNeeded()
        }
    }

    private func installHostingControllerIfNeeded() {
        let rootView = MainFrameHostActionSheetRootView(
            title: actionTitle,
            subtitle: actionSubtitle,
            items: items,
            onSelect: { [weak self] identifier in
                guard let self else { return }
                self.delegate?.mainFrameHostActionSheetHostingViewController(self, didSelectActionWithIdentifier: identifier)
            },
            onCancel: { [weak self] in
                guard let self else { return }
                self.delegate?.mainFrameHostActionSheetHostingViewControllerDidCancel(self)
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
