import UIKit
#if canImport(SwiftUI)
import SwiftUI

@available(iOS 13.0, *)
private struct MainFrameAppCardView: View {
    let title: String
    let boxArt: UIImage?
    let hidden: Bool
    let running: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.52, green: 0.44, blue: 0.74))
                    .frame(width: size.width, height: size.height)

                if let boxArt {
                    Image(uiImage: boxArt)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                } else {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.64, green: 0.57, blue: 0.84),
                            Color(red: 0.49, green: 0.42, blue: 0.71)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: size.width, height: size.height)
                }

                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.15),
                        Color.black.opacity(0.75)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: size.width, height: size.height)

                VStack(alignment: .leading, spacing: 8) {
                    if running {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("运行中")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Capsule())
                    }

                    Spacer(minLength: 0)

                    MainFrameMarqueeText(
                        text: title.isEmpty ? "未命名应用" : title,
                        font: UIFont.systemFont(ofSize: 13, weight: .semibold)
                    )
                }
                .padding(12)
                .frame(width: size.width, height: size.height, alignment: .bottomLeading)
            }
            .frame(width: size.width, height: size.height, alignment: .bottomLeading)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(hidden ? 0.45 : 1.0)
        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
        .allowsHitTesting(false)
    }
}

@available(iOS 13.0, *)
private struct MainFrameMarqueeText: View {
    let text: String
    let font: UIFont

    var body: some View {
        MainFrameMarqueeTextRepresentable(text: text, font: font)
        .frame(height: 18)
    }
}

@available(iOS 13.0, *)
private struct MainFrameMarqueeTextRepresentable: UIViewRepresentable {
    let text: String
    let font: UIFont

    func makeUIView(context: Context) -> MainFrameMarqueeLabelView {
        let view = MainFrameMarqueeLabelView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: MainFrameMarqueeLabelView, context: Context) {
        uiView.configure(text: text, font: font)
    }
}

@available(iOS 13.0, *)
private final class MainFrameMarqueeLabelView: UIView {
    private let label = UILabel()
    private let duplicateLabel = UILabel()
    private let contentView = UIView()

    private let spacing: CGFloat = 24
    private let pointsPerSecond: CGFloat = 22

    private var currentText: String = ""
    private var currentFont: UIFont = UIFont.systemFont(ofSize: 13, weight: .semibold)

    override init(frame: CGRect) {
        super.init(frame: frame)

        clipsToBounds = true

        label.numberOfLines = 1
        duplicateLabel.numberOfLines = 1

        [label, duplicateLabel].forEach { titleLabel in
            titleLabel.textColor = .white
            titleLabel.shadowColor = UIColor.black.withAlphaComponent(0.35)
            titleLabel.shadowOffset = CGSize(width: 0, height: 1)
            contentView.addSubview(titleLabel)
        }

        addSubview(contentView)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(text: String, font: UIFont) {
        currentText = text
        currentFont = font

        [label, duplicateLabel].forEach { titleLabel in
            titleLabel.text = text
            titleLabel.font = font
        }

        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let availableWidth = bounds.width
        guard availableWidth > 0 else {
            return
        }

        let measuredWidth = ceil(label.sizeThatFits(CGSize(width: .greatestFiniteMagnitude, height: bounds.height)).width)
        let labelHeight = max(bounds.height, ceil(label.font.lineHeight))

        contentView.layer.removeAllAnimations()

        if measuredWidth <= availableWidth {
            label.frame = CGRect(x: 0, y: 0, width: availableWidth, height: labelHeight)
            duplicateLabel.isHidden = true
            contentView.frame = bounds
            return
        }

        duplicateLabel.isHidden = false
        label.frame = CGRect(x: 0, y: 0, width: measuredWidth, height: labelHeight)
        duplicateLabel.frame = CGRect(x: measuredWidth + spacing, y: 0, width: measuredWidth, height: labelHeight)
        contentView.frame = CGRect(x: 0, y: 0, width: measuredWidth * 2 + spacing, height: labelHeight)

        let distance = measuredWidth + spacing
        let duration = max(Double(distance / pointsPerSecond), 4.5)

        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = 0
        animation.toValue = -distance
        animation.duration = duration
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        contentView.layer.add(animation, forKey: "mainframe.marquee")
    }
}

@objcMembers
@available(iOS 13.0, *)
final class MainFrameAppCellHostingBridge: NSObject {
    private var hostingController: UIHostingController<MainFrameAppCardView>?

    func renderInView(_ containerView: UIView,
                      title: String,
                      boxArt: UIImage?,
                      hidden: Bool,
                      running: Bool) {
        let rootView = MainFrameAppCardView(
            title: title,
            boxArt: boxArt,
            hidden: hidden,
            running: running
        )

        if let hostingController {
            hostingController.rootView = rootView
            if hostingController.view.superview == nil {
                attach(hostingController: hostingController, to: containerView)
            }
            return
        }

        let hostingController = UIHostingController(rootView: rootView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        hostingController.view.isUserInteractionEnabled = false
        attach(hostingController: hostingController, to: containerView)
        self.hostingController = hostingController
    }

    private func attach(hostingController: UIHostingController<MainFrameAppCardView>, to containerView: UIView) {
        containerView.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
}
#endif
