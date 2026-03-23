import UIKit
#if canImport(SwiftUI)
import SwiftUI

@objc protocol MainFrameAddHostSheetHostingViewControllerDelegate: NSObjectProtocol {
    func mainFrameAddHostSheetHostingViewControllerDidCancel(_ controller: MainFrameAddHostSheetHostingViewController)
    func mainFrameAddHostSheetHostingViewController(_ controller: MainFrameAddHostSheetHostingViewController, didSubmitHostAddress hostAddress: String)
}

@available(iOS 13.0, *)
private struct MainFrameAddHostTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onReturn: () -> Void

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: MainFrameAddHostTextField

        init(parent: MainFrameAddHostTextField) {
            self.parent = parent
        }

        @objc func textDidChange(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onReturn()
            return false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.placeholder = placeholder
        textField.text = text
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .done
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.keyboardType = .URL
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.textColor = UIColor(red: 0.24, green: 0.18, blue: 0.35, alpha: 1.0)
        textField.font = .systemFont(ofSize: 16, weight: .semibold)
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
}

@available(iOS 13.0, *)
private struct MainFrameAddHostSheetRootView: View {
    @State private var hostAddress: String = ""

    let title: String
    let message: String
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    private var trimmedHostAddress: String {
        hostAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.black.opacity(0.14))
                    .frame(width: 44, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 18)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 18)

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(red: 0.39, green: 0.31, blue: 0.58))

                        MainFrameAddHostTextField(text: $hostAddress,
                                                  placeholder: "输入 IPv4 / IPv6 / 主机地址",
                                                  onReturn: submitIfPossible)
                            .frame(height: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.96))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )

                    HStack(spacing: 12) {
                        Button(action: onCancel) {
                            Text("取消")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white.opacity(0.96))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: submitIfPossible) {
                            Text("添加")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(trimmedHostAddress.isEmpty ? Color(red: 0.70, green: 0.65, blue: 0.80) : Color(red: 0.45, green: 0.35, blue: 0.72))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(trimmedHostAddress.isEmpty)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.97, green: 0.94, blue: 1.0),
                    Color(red: 0.90, green: 0.85, blue: 0.99)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func submitIfPossible() {
        guard !trimmedHostAddress.isEmpty else { return }
        onSubmit(trimmedHostAddress)
    }
}

@objcMembers
@available(iOS 13.0, *)
final class MainFrameAddHostSheetHostingViewController: UIViewController {
    weak var delegate: MainFrameAddHostSheetHostingViewControllerDelegate?

    private var sheetTitle: String = ""
    private var sheetMessage: String = ""
    private var hostingController: UIHostingController<MainFrameAddHostSheetRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.97, green: 0.94, blue: 1.0, alpha: 1.0)
        modalPresentationStyle = .pageSheet
        installHostingControllerIfNeeded()
        presentationController?.delegate = self

        if #available(iOS 15.0, *),
           let sheetPresentationController = presentationController as? UISheetPresentationController {
            sheetPresentationController.detents = [.medium(), .large()]
            sheetPresentationController.prefersGrabberVisible = true
            sheetPresentationController.preferredCornerRadius = 28
            sheetPresentationController.prefersScrollingExpandsWhenScrolledToEdge = false
        }
    }

    func configure(title: String, message: String) {
        sheetTitle = title
        sheetMessage = message

        if isViewLoaded {
            installHostingControllerIfNeeded()
        }
    }

    private func installHostingControllerIfNeeded() {
        let rootView = MainFrameAddHostSheetRootView(
            title: sheetTitle,
            message: sheetMessage,
            onSubmit: { [weak self] hostAddress in
                guard let self else { return }
                self.delegate?.mainFrameAddHostSheetHostingViewController(self, didSubmitHostAddress: hostAddress)
            },
            onCancel: { [weak self] in
                guard let self else { return }
                self.delegate?.mainFrameAddHostSheetHostingViewControllerDidCancel(self)
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

@available(iOS 13.0, *)
extension MainFrameAddHostSheetHostingViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        delegate?.mainFrameAddHostSheetHostingViewControllerDidCancel(self)
    }
}
#endif
