import UIKit
#if canImport(SwiftUI)
import SwiftUI

@available(iOS 13.0, *)
private struct ProfileTableViewCellContentView: View {
    let name: String

    var body: some View {
        HStack(spacing: 0) {
            Text(name)
                .font(.system(size: 17))
                .foregroundColor(Color(red: 0.9529411765, green: 0.9764705882, blue: 1.0))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(red: 0.1215686275, green: 0.1294117647, blue: 0.1411764706))
        .allowsHitTesting(false)
    }
}

@objcMembers
@available(iOS 13.0, *)
final class ProfileTableViewCellHostingBridge: NSObject {
    private var hostingController: UIHostingController<ProfileTableViewCellContentView>?

    func renderInView(_ containerView: UIView, name: String) {
        if let hostingController {
            hostingController.rootView = ProfileTableViewCellContentView(name: name)
            return
        }

        let hostingController = UIHostingController(rootView: ProfileTableViewCellContentView(name: name))
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear

        containerView.insertSubview(hostingController.view, at: 0)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        self.hostingController = hostingController
    }
}
#endif
