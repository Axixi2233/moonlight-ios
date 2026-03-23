import UIKit
#if canImport(SwiftUI)
import SwiftUI

@available(iOS 13.0, *)
private struct AboutPurpleBackground: View {
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
private struct AboutLinkItem: Identifiable {
    let id = UUID()
    let title: String
    let systemIconName: String
    let assetName: String
    let urlString: String
}

@available(iOS 13.0, *)
private struct AboutInfoCard: View {
    let appName: String
    let subtitle: String
    let versionText: String

    var body: some View {
        VStack(spacing: 0) {
            Image("LaunchIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 78, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 6)
                .padding(.top, 22)

            Text(appName)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(red: 0.27, green: 0.20, blue: 0.40))
                .padding(.top, 14)

            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(red: 0.43, green: 0.35, blue: 0.60))
                .padding(.top, 8)

            Text(versionText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(red: 0.36, green: 0.30, blue: 0.50))
                .padding(.top, 18)
                .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.90),
                            Color(red: 0.96, green: 0.93, blue: 1.00).opacity(0.80)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
    }
}

@available(iOS 13.0, *)
private struct AboutLinkButton: View {
    let item: AboutLinkItem

    var body: some View {
        Button(action: {
            guard let url = URL(string: item.urlString) else { return }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.88))

                Group {
                    if UIImage(named: item.assetName) != nil {
                        Image(item.assetName)
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    } else {
                        Image(systemName: item.systemIconName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(red: 0.28, green: 0.22, blue: 0.42))
                    }
                }
            }
            .frame(width: 44, height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.68), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

@available(iOS 13.0, *)
private struct AboutPlatformRow: View {
    let items: [AboutLinkItem]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(items) { item in
                AboutLinkButton(item: item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

@available(iOS 13.0, *)
private struct AboutActionCard: View {
    let title: String
    let subtitle: String
    let iconName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.84))
                        .frame(width: 52, height: 52)

                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(red: 0.31, green: 0.23, blue: 0.46))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.28, green: 0.22, blue: 0.42))

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(red: 0.43, green: 0.35, blue: 0.60))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.22))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.76))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.62), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

@available(iOS 13.0, *)
private struct AboutRootView: View {
    let requestGamepadTest: () -> Void

    private let links: [AboutLinkItem] = [
        AboutLinkItem(title: "Bilibili", systemIconName: "play.rectangle.fill", assetName: "AboutBilibiliIcon", urlString: "https://space.bilibili.com/16893379"),
        AboutLinkItem(title: "小红书", systemIconName: "book.closed.fill", assetName: "AboutXiaohongshuIcon", urlString: "https://www.xiaohongshu.com/user/profile/5d21be61000000001600b878"),
        AboutLinkItem(title: "抖音", systemIconName: "music.note.tv.fill", assetName: "AboutDouyinIcon", urlString: "https://v.douyin.com/zm9GLKUfBW8/")
    ]

    private var appName: String {
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !displayName.isEmpty {
            return displayName
        }
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, !name.isEmpty {
            return name
        }
        return "Moonlight"
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        if build.isEmpty || build == version {
            return "版本号：\(version)"
        }
        return "版本号：\(version) (\(build))"
    }

    var body: some View {
        ZStack {
            AboutPurpleBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    AboutInfoCard(
                        appName: appName,
                        subtitle: "一款流畅易用的 Moonlight 串流客户端",
                        versionText: versionText
                    )

                    AboutActionCard(
                        title: "手柄测试",
                        subtitle: "实时查看摇杆、按键和扳机状态，手柄震动，体感测试。",
                        iconName: "gamecontroller.fill",
                        action: requestGamepadTest
                    )

                    VStack(alignment: .leading, spacing: 14) {
                        Text("在这里找到开发者")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 0.35, green: 0.29, blue: 0.50))

                        AboutPlatformRow(items: links)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.76))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.62), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 8)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
        }
    }
}

@objcMembers
@available(iOS 13.0, *)
final class AboutHostingViewController: UIViewController {
    private var hostingController: UIHostingController<AboutRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        title = "关于"
        installHostingControllerIfNeeded()
        applyNavigationBarAppearance()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyNavigationBarAppearance()
    }

    private func installHostingControllerIfNeeded() {
        let rootView = AboutRootView(requestGamepadTest: { [weak self] in
            guard let self = self else { return }
            let controller = GamepadTestHostingViewController()
            self.navigationController?.pushViewController(controller, animated: true)
        })
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

    private func applyNavigationBarAppearance() {
        let navigationBar = navigationController?.navigationBar
        guard let navigationBar else { return }

        let accentColor = UIColor(red: 0.31, green: 0.23, blue: 0.46, alpha: 1.0)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: accentColor,
            .font: UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        ]

        navigationBar.tintColor = accentColor
        navigationBar.titleTextAttributes = titleAttributes

        let appearance = UINavigationBarAppearance()
        appearance.titleTextAttributes = titleAttributes

        if #available(iOS 26.0, *) {
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            appearance.shadowColor = .clear
        } else {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(red: 0.98, green: 0.96, blue: 1.0, alpha: 0.96)
            appearance.shadowColor = UIColor(red: 0.73, green: 0.69, blue: 0.82, alpha: 0.22)
        }

        navigationBar.standardAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        if #available(iOS 15.0, *) {
            navigationBar.compactScrollEdgeAppearance = appearance
        }
    }
}
#endif
