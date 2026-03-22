import UIKit
#if canImport(SwiftUI)
import SwiftUI

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
    let items: [MainFrameHostListItemSnapshot]
    let onSelect: (Int) -> Void
    let onLongPress: (Int) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
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
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.clear)
    }
}

@available(iOS 13.0, *)
private struct MainFrameHostRowView: View {
    let item: MainFrameHostListItemSnapshot

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 56, height: 56)

                if item.showsActivity {
                    MainFrameActivityIndicator()
                } else {
                    Image(systemName: "display")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 10) {
                    Text(item.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(red: 0.26, green: 0.20, blue: 0.37))
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
                    .foregroundColor(Color(red: 0.40, green: 0.34, blue: 0.52))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.black.opacity(0.22))
                .frame(width: 18, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 6)
    }

    private var cardBackground: LinearGradient {
        return LinearGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(0.88),
                Color(red: 0.96, green: 0.93, blue: 1.00).opacity(0.78)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var iconBackground: Color {
        switch item.statusStyle {
        case 1:
            return Color(red: 0.17, green: 0.43, blue: 0.29)
        case 2:
            return Color(red: 0.46, green: 0.24, blue: 0.18)
        default:
            return Color(red: 0.22, green: 0.24, blue: 0.29)
        }
    }

    private var statusBackground: Color {
        switch item.statusStyle {
        case 1:
            return Color(red: 0.87, green: 0.96, blue: 0.90)
        case 2:
            return Color(red: 0.99, green: 0.90, blue: 0.86)
        default:
            return Color.black.opacity(0.06)
        }
    }

    private var statusForeground: Color {
        switch item.statusStyle {
        case 1:
            return Color(red: 0.18, green: 0.46, blue: 0.28)
        case 2:
            return Color(red: 0.74, green: 0.29, blue: 0.20)
        default:
            return Color(red: 0.34, green: 0.30, blue: 0.42)
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
