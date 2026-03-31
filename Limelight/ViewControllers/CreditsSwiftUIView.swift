import UIKit
#if canImport(SwiftUI)
import SwiftUI
import Nuke

private func CreditsLocalized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private struct CreditsEntry: Identifiable {
    let name: String
    let avatarURLString: String

    var id: String {
        name
    }

    var normalizedAvatarURLString: String {
        if let range = avatarURLString.range(of: "@") {
            return String(avatarURLString[..<range.lowerBound])
        }
        return avatarURLString
    }
}

private let creditsEntries: [CreditsEntry] = [
    CreditsEntry(name: "鹿***路", avatarURLString: "https://i1.hdslb.com/bfs/face/f05e1dba1d95daa97da6c72cc0f56b21d11a65ce.jpg@128w_1o.webp"),
    CreditsEntry(name: "路***类", avatarURLString: "https://i1.hdslb.com/bfs/face/7f341960c6fb723a47d757b536793b5e07b5bb74.jpg@128w_1o.webp"),
    CreditsEntry(name: "千***s", avatarURLString: "https://i1.hdslb.com/bfs/face/a8946cc2028951bcc95a0707af554e7665119721.jpg@128w_1o.webp"),
    CreditsEntry(name: "日***a", avatarURLString: "https://i2.hdslb.com/bfs/face/050432c154105ff8bd337cb0bda2800821896018.jpg@128w_1o.webp"),
    CreditsEntry(name: "o***o", avatarURLString: "https://i1.hdslb.com/bfs/face/bd3d76161113ef0f7d91bc08d395ab49f0e83fba.jpg@128w_1o.webp"),
    CreditsEntry(name: "朝***阳", avatarURLString: "https://i2.hdslb.com/bfs/face/4e8cb5cc62296540f5c0de3c04427f802339e6f3.jpg@128w_1o.webp"),
    CreditsEntry(name: "N***Q", avatarURLString: "https://i2.hdslb.com/bfs/face/fd404932519cc91c2c1dfca5bdd7c4553d2584dd.jpg@128w_1o.webp"),
    CreditsEntry(name: "动***_", avatarURLString: "https://i1.hdslb.com/bfs/face/bf84fb0c25f2ceb5f770fffe60fc770d9b6b5c07.jpg@128w_1o.webp"),
    CreditsEntry(name: "8***i", avatarURLString: "https://i1.hdslb.com/bfs/face/member/noface.jpg@128w_1o.webp"),
    CreditsEntry(name: "在***象", avatarURLString: "https://i1.hdslb.com/bfs/face/51bd87b452ea333c77404f938b4df5683f155159.jpg@128w_1o.webp"),
    CreditsEntry(name: "五***紫", avatarURLString: "https://i1.hdslb.com/bfs/face/1b57cea01ebeb44fb6d42d2c9dc19b854d1a201d.jpg@128w_1o.webp"),
    CreditsEntry(name: "B***n", avatarURLString: "https://i2.hdslb.com/bfs/face/00a4ec4953b88a286cb669117a576a0d5d7d045f.jpg@128w_1o.webp"),
    CreditsEntry(name: "小***h", avatarURLString: "https://i1.hdslb.com/bfs/face/d90c49d70a677ad917f1321d8f246f52cf0ed169.jpg@128w_1o.webp"),
    CreditsEntry(name: "林***头", avatarURLString: "https://i2.hdslb.com/bfs/face/6b4b0e94556c550da0288bb960d8f984e623e1bd.jpg@128w_1o.webp"),
    CreditsEntry(name: "羡***9", avatarURLString: "https://i1.hdslb.com/bfs/face/dc074b0c9359dd768f0e5d75e37e52b05fbff9ba.jpg@128w_1o.webp"),
    CreditsEntry(name: "四***堂", avatarURLString: "https://i2.hdslb.com/bfs/face/7cda2e85849a2b8d7530bc5ab7b3a4a563dc9e9c.jpg@128w_1o.webp"),
    CreditsEntry(name: "夜***w", avatarURLString: "https://i2.hdslb.com/bfs/face/3e410aa4b25ef776829a5c23aab3527b0ad78fdc.jpg@128w_1o.webp"),
    CreditsEntry(name: "耀***技", avatarURLString: "https://i2.hdslb.com/bfs/face/a4e0aef2add824a2a1934f06e13f1abfa353da62.jpg@128w_1o.webp"),
    CreditsEntry(name: "荔***眼", avatarURLString: "https://i2.hdslb.com/bfs/face/0b6babb147005ff69b88978a8dc600239cab8c7d.jpg@128w_1o.webp"),
    CreditsEntry(name: "M***h", avatarURLString: "https://i2.hdslb.com/bfs/face/e4d6b12e0d2daaeb5f130dcd25653fe6cd5f4df1.jpg@128w_1o.webp"),
    CreditsEntry(name: "熬***拜", avatarURLString: "https://i0.hdslb.com/bfs/face/b60728d1fa7e7ab8ddeccde607869eace07b7213.jpg@128w_1o.webp"),
    CreditsEntry(name: "残***_", avatarURLString: "https://i1.hdslb.com/bfs/face/497980bd873c97114991ca86f1fbd3b58af3ffae.webp@128w_1o.webp"),
    CreditsEntry(name: "白***夜", avatarURLString: "https://i2.hdslb.com/bfs/garb/d515dae16548221240649035be81452f50ebdab2.png@128w_1o.webp"),
    CreditsEntry(name: "Y***g", avatarURLString: "https://i1.hdslb.com/bfs/face/8873a43112d62e52a769d8ac97f1e0d65634b93e.jpg@128w_1o.webp"),
    CreditsEntry(name: "镜***h", avatarURLString: "https://i1.hdslb.com/bfs/face/65f5e7c8f605b149ed5814151c0fc71e251f3ff2.jpg@128w_1o.webp"),
    CreditsEntry(name: "小***巴", avatarURLString: "https://i1.hdslb.com/bfs/face/3c29568c4ab0d73cdb5f0b2818cec8d1017e23e8.jpg@128w_1o.webp"),
    CreditsEntry(name: "芋***端", avatarURLString: "https://i1.hdslb.com/bfs/face/195301322cd0928fb30cc387f71b0241c32396a7.jpg@128w_1o.webp"),
    CreditsEntry(name: "A***n", avatarURLString: "https://i2.hdslb.com/bfs/face/18f86f14bbc1dc81bb135ceec941c21d072ddd86.jpg@128w_1o.webp"),
    CreditsEntry(name: "h***o", avatarURLString: "https://i2.hdslb.com/bfs/face/85eb6fb9ab9419505318072dd144613267a374dc.jpg@128w_1o.webp"),
    CreditsEntry(name: "S***e", avatarURLString: "https://i1.hdslb.com/bfs/face/6116a47544bb744b9f206ffc5ed090a98b50d351.jpg@128w_1o.webp"),
    CreditsEntry(name: "冰***寒", avatarURLString: "https://i1.hdslb.com/bfs/face/1204102a86a5eac380fe80df7509c3b46c0228fc.jpg@128w_1o.webp"),
    CreditsEntry(name: "让***白", avatarURLString: "https://i2.hdslb.com/bfs/baselabs/b3283b94df495648262ce268bcaf4c7853efc7ea.png@128w_1o.webp"),
    CreditsEntry(name: "好***丶", avatarURLString: "https://i1.hdslb.com/bfs/baselabs/b7314b28919a1af9bd162eaf1dc35a52ad9f7ab9.png@128w_1o.webp"),
    CreditsEntry(name: "A***_", avatarURLString: "https://i1.hdslb.com/bfs/face/338d06cf47fed7e0eb5fb2b8d030dc3fb6284aaa.jpg@128w_1o.webp"),
    CreditsEntry(name: "z***e", avatarURLString: "https://i1.hdslb.com/bfs/face/member/noface.jpg@128w_1o.webp"),
    CreditsEntry(name: "I***e", avatarURLString: "https://i1.hdslb.com/bfs/face/1c6d43f16d24fea7b153dc8817e61a09a5a33da2.jpg@128w_1o.webp"),
    CreditsEntry(name: "S***9", avatarURLString: "https://i2.hdslb.com/bfs/face/4c93fcca0e126b7f10fdd2da31041ee128ebc9c3.jpg@128w_1o.webp"),
    CreditsEntry(name: "伪***己", avatarURLString: "https://i1.hdslb.com/bfs/face/4a7e9f99214910f93a6d0dd5409a0e1dbeb9f9a3.jpg@128w_1o.webp"),
    CreditsEntry(name: "爱***子", avatarURLString: "https://i2.hdslb.com/bfs/face/3e80a894a385dcad81d7632a8b3a1ea82298846b.jpg@128w_1o.webp"),
    CreditsEntry(name: "兰***音", avatarURLString: "https://i1.hdslb.com/bfs/face/1360c01280d74553f3ea1b880dfb3205620d967c.jpg@128w_1o.webp"),
    CreditsEntry(name: "微***安", avatarURLString: "https://i1.hdslb.com/bfs/face/15d89c4b5434d44fb04ffe9295b1f252e6ceb056.jpg@128w_1o.webp"),
    CreditsEntry(name: "小***奇", avatarURLString: "https://i2.hdslb.com/bfs/face/d3cc916a9ec1aa3104fb3e0788938ca09b9bc252.jpg@128w_1o.webp"),
    CreditsEntry(name: "嚯***y", avatarURLString: "https://i1.hdslb.com/bfs/face/282bfbdf22a90516b0c682b813afa85749bf6765.webp@128w_1o.webp"),
    CreditsEntry(name: "N***g", avatarURLString: "https://i1.hdslb.com/bfs/face/8d88010b828359cad543f88d5058877446382e37.jpg@128w_1o.webp"),
    CreditsEntry(name: "大***N", avatarURLString: "https://i2.hdslb.com/bfs/face/38a1a7cd4b069b9aeb385d567324c5b04cb359af.jpg@128w_1o.webp"),
    CreditsEntry(name: "H***i", avatarURLString: "https://i2.hdslb.com/bfs/face/9e2e2e0508901b165d72dc5fc8add157f64f1414.jpg@128w_1o.webp"),
    CreditsEntry(name: "北***l", avatarURLString: "https://i2.hdslb.com/bfs/face/1a0c9a18f516f63fb00c78abf63eee9a3a55a4ac.jpg@128w_1o.webp"),
    CreditsEntry(name: "辛***喵", avatarURLString: "https://i1.hdslb.com/bfs/face/79d51a5e3c940bb948f7fc523c9fdc4f7232997f.jpg@128w_1o.webp"),
    CreditsEntry(name: "m***9", avatarURLString: "https://i2.hdslb.com/bfs/face/cdd9d243e6d57e006db53c50803b18a58eb0810b.jpg@128w_1o.webp"),
    CreditsEntry(name: "吾***丶", avatarURLString: "https://i1.hdslb.com/bfs/face/4dc426aba20ac39cc3d5ba48b008ea33ec00383e.jpg@128w_1o.webp"),
    CreditsEntry(name: "F***w", avatarURLString: "https://i2.hdslb.com/bfs/face/57c2c9a1cf31e73f952ae17fe0bdb46eee6729a1.jpg@128w_1o.webp"),
    CreditsEntry(name: "废***_", avatarURLString: "https://i1.hdslb.com/bfs/face/b2cf4b2a08a5472d4ef7902700c9b2dfd156adf3.jpg@128w_1o.webp"),
    CreditsEntry(name: "b***4", avatarURLString: "https://i1.hdslb.com/bfs/face/00eca0557111094470357821a22131077f280f8f.jpg@128w_1o.webp"),
    CreditsEntry(name: "y***y", avatarURLString: "https://i2.hdslb.com/bfs/face/bab80a31e30a4fa977f51518428d365e6a0cea7a.jpg@128w_1o.webp"),
    CreditsEntry(name: "D***X", avatarURLString: "https://i1.hdslb.com/bfs/face/f0557e3779c4bcad649389b1ab6aba83a2315ed5.jpg@128w_1o.webp"),
    CreditsEntry(name: "f***a", avatarURLString: "https://i1.hdslb.com/bfs/face/70e112e97295eec88fec23cb85b2b575510387ef.jpg@128w_1o.webp"),
    CreditsEntry(name: "v***叶", avatarURLString: "https://i1.hdslb.com/bfs/face/a2b216c1be029753570f62a40bc7ac440561a2fa.jpg@128w_1o.webp"),
    CreditsEntry(name: "海***厅", avatarURLString: "https://i1.hdslb.com/bfs/face/ccc4a92512d9d9aa0e5137e42f8e483b7d3883ac.jpg@128w_1o.webp"),
    CreditsEntry(name: "天***1", avatarURLString: "https://i1.hdslb.com/bfs/face/member/noface.jpg@128w_1o.webp"),
    CreditsEntry(name: "S***K", avatarURLString: "https://i1.hdslb.com/bfs/face/5a5f7b1ce18b9af97c8695fd5f53c542c77ec445.jpg@128w_1o.webp"),
    CreditsEntry(name: "知***格", avatarURLString: "https://i1.hdslb.com/bfs/face/737927857ccaa312ef0310e9981271139f6d2085.jpg@128w_1o.webp"),
    CreditsEntry(name: "皮***d", avatarURLString: "https://i1.hdslb.com/bfs/baselabs/f338ee7ab9e21bddd7b21d9c7537f0e5ea47b2e1.png@128w_1o.webp"),
    CreditsEntry(name: "6***D", avatarURLString: "https://i1.hdslb.com/bfs/face/96e705d7e9e1d32664a03b7531fa8d9a382690ef.jpg@128w_1o.webp"),
    CreditsEntry(name: "f***e", avatarURLString: "https://i2.hdslb.com/bfs/face/99bba5562d5329813acbb17427db3c946f006583.jpg@128w_1o.webp"),
    CreditsEntry(name: "叫***漾", avatarURLString: "https://i2.hdslb.com/bfs/face/f8f7b1a9900ac98110220466f069eabc36f50ffe.jpg@128w_1o.webp"),
    CreditsEntry(name: "崩***灵", avatarURLString: "https://i1.hdslb.com/bfs/face/77760cf838f283dc0306917c51b5078c821ba3de.jpg@128w_1o.webp"),
    CreditsEntry(name: "千***星", avatarURLString: "https://i1.hdslb.com/bfs/face/e7078ee11e1e616a90bc2333af7e828b0aecd6e7.jpg@128w_1o.webp"),
    CreditsEntry(name: "霹***子", avatarURLString: "https://i1.hdslb.com/bfs/face/5196235351e4303e76ff844226e6f31aff1ab1f9.jpg@128w_1o.webp"),
    CreditsEntry(name: "斯***因", avatarURLString: "https://i1.hdslb.com/bfs/face/1dbcdccc317389f98a1d80cde8e148e53849211b.jpg@128w_1o.webp"),
    CreditsEntry(name: "白***圆", avatarURLString: "https://i2.hdslb.com/bfs/face/d53a43cb9378901c29d9dcb318780dc78aa03186.jpg@128w_1o.webp"),
    CreditsEntry(name: "Q***g", avatarURLString: "https://i2.hdslb.com/bfs/face/2ebca39be0ffefb1d04ab58372ff674440460d94.jpg@128w_1o.webp"),
    CreditsEntry(name: "第***妖", avatarURLString: "https://i2.hdslb.com/bfs/face/2c64144e70b1694b496de03a7fd829b69276e644.jpg@128w_1o.webp"),
    CreditsEntry(name: "布***雨", avatarURLString: "https://i1.hdslb.com/bfs/face/c316a6ea0b1eb949c5fbe2803c5476ec6c203f06.jpg@128w_1o.webp"),
    CreditsEntry(name: "方***極", avatarURLString: "https://i2.hdslb.com/bfs/face/51d893a04cf21d056b0ab1ed844591125e02154b.jpg@128w_1o.webp"),
    CreditsEntry(name: "小***_", avatarURLString: "https://i1.hdslb.com/bfs/face/3cc973780d572474bbc01b60f1d9f305fff8c42f.jpg@128w_1o.webp"),
    CreditsEntry(name: "九***才", avatarURLString: "https://i2.hdslb.com/bfs/face/33c2a71db7c5dd9161277e0e54b9b02ba0cfd99a.jpg@128w_1o.webp"),
    CreditsEntry(name: "蒸***目", avatarURLString: "https://i1.hdslb.com/bfs/face/b8df493e7e74e35e47904f5160b1ade43b919fbb.jpg@128w_1o.webp"),
    CreditsEntry(name: "离***r", avatarURLString: "https://i1.hdslb.com/bfs/face/7b3b41a63d1be92002a21474fe9fc87abb4b5898.jpg@128w_1o.webp"),
    CreditsEntry(name: "L***w", avatarURLString: "https://i1.hdslb.com/bfs/face/ba838603af5804365a6d1fe8d87df8d00d7c38f8.webp@128w_1o.webp"),
    CreditsEntry(name: "艾***1", avatarURLString: "https://i1.hdslb.com/bfs/face/member/noface.jpg@128w_1o.webp"),
    CreditsEntry(name: "嗝***革", avatarURLString: "https://i1.hdslb.com/bfs/face/89649589688a93d582cd4cc0c2fcce209041a594.jpg@128w_1o.webp"),
    CreditsEntry(name: "子***0", avatarURLString: "https://i2.hdslb.com/bfs/face/c9dd248632ef8ccfa4ea5ba0a44edec9d2fe0e27.jpg@128w_1o.webp"),
    CreditsEntry(name: "辰***r", avatarURLString: "https://i1.hdslb.com/bfs/face/e57aba9c8d2c16a8f0a697220b8c8b915b81957a.jpg@128w_1o.webp"),
    CreditsEntry(name: "若***n", avatarURLString: "https://i1.hdslb.com/bfs/face/4682acb9e29700d8bc48f5df3ee0706d33be243f.jpg@128w_1o.webp"),
    CreditsEntry(name: "游***Z", avatarURLString: "https://i1.hdslb.com/bfs/face/6ebee73b01e60a19fcde6a666ff35607cba15997.webp@128w_1o.webp"),
    CreditsEntry(name: "神***六", avatarURLString: "https://i1.hdslb.com/bfs/face/b750fac76c26fb3a541d2089cf817ebc94acf5e7.jpg@128w_1o.webp"),
    CreditsEntry(name: "L***r", avatarURLString: "https://i1.hdslb.com/bfs/face/2f6800e7765a2edd3e51d74b8ff4e9fd773a091b.jpg@128w_1o.webp")
]

@available(iOS 13.0, *)
private struct CreditsPurpleBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    colorScheme == .dark ? Color(red: 0.08, green: 0.08, blue: 0.12) : Color(red: 0.97, green: 0.95, blue: 1.0),
                    colorScheme == .dark ? Color(red: 0.10, green: 0.09, blue: 0.16) : Color(red: 0.95, green: 0.93, blue: 1.0),
                    colorScheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.10) : Color(red: 0.94, green: 0.92, blue: 0.98)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(colorScheme == .dark ? Color(red: 0.46, green: 0.31, blue: 0.82).opacity(0.18) : Color(red: 0.72, green: 0.61, blue: 1.0).opacity(0.24))
                .frame(width: 250, height: 250)
                .blur(radius: 20)
                .offset(x: 120, y: -190)

            Circle()
                .fill(colorScheme == .dark ? Color(red: 0.18, green: 0.56, blue: 0.82).opacity(0.14) : Color(red: 0.58, green: 0.77, blue: 1.0).opacity(0.18))
                .frame(width: 200, height: 200)
                .blur(radius: 22)
                .offset(x: -140, y: 260)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

@available(iOS 13.0, *)
private struct CreditsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension Image {
    static var creditsAvatarPlaceholder: Image {
        Image(systemName: "person")
    }
}

@available(iOS 13.0, *)
private final class CreditsAvatarImageView: UIView {
    private let imageView = UIImageView()
    private var imageTask: ImageTask?
    private var currentURLString: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .clear
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        imageTask?.cancel()
    }

    func setImage(urlString: String) {
        guard currentURLString != urlString else { return }

        currentURLString = urlString
        imageTask?.cancel()
        imageTask = nil
        imageView.image = nil

        guard let url = URL(string: urlString) else { return }

        let requestedURLString = urlString
        imageTask = ImagePipeline.shared.loadImage(with: url) { [weak self] result in
            guard let self, self.currentURLString == requestedURLString else { return }

            switch result {
            case .success(let response):
                self.imageView.image = response.image
            case .failure:
                self.imageView.image = nil
            }
        }
    }
}

@available(iOS 13.0, *)
private struct CreditsAvatarViewRepresentable: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> CreditsAvatarImageView {
        CreditsAvatarImageView()
    }

    func updateUIView(_ uiView: CreditsAvatarImageView, context: Context) {
        uiView.setImage(urlString: urlString)
    }
}

@available(iOS 13.0, *)
private struct CreditsHeaderCard: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(CreditsLocalized("about.credits.heading"))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.96) : Color(red: 0.27, green: 0.20, blue: 0.40))

            Text(CreditsLocalized("about.credits.message"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.68) : Color(red: 0.43, green: 0.35, blue: 0.60))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.80))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.68), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.05), radius: 14, x: 0, y: 8)
    }
}

@available(iOS 13.0, *)
private struct CreditWallItemCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: CreditsEntry

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color(red: 0.91, green: 0.86, blue: 0.99))

                Image.creditsAvatarPlaceholder
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(16)
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.72) : Color(red: 0.42, green: 0.34, blue: 0.58))

                CreditsAvatarViewRepresentable(urlString: entry.normalizedAvatarURLString)
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.74), lineWidth: 2)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.08), radius: 10, x: 0, y: 5)

            Text(entry.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.92) : Color(red: 0.30, green: 0.22, blue: 0.43))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.88),
                            colorScheme == .dark ? Color(red: 0.16, green: 0.14, blue: 0.24).opacity(0.92) : Color(red: 0.95, green: 0.90, blue: 1.0).opacity(0.74)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.68), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.04), radius: 10, x: 0, y: 6)
    }
}

@available(iOS 13.0, *)
private struct CreditsColumnContent: View {
    let entries: [CreditsEntry]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(entries) { entry in
                CreditWallItemCard(entry: entry)
            }
        }
    }
}

@available(iOS 13.0, *)
private struct CreditsWallColumn: View {
    let entries: [CreditsEntry]
    let speed: Double
    let startOffset: CGFloat
    @State private var contentHeight: CGFloat = 1
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 12) {
                CreditsColumnContent(entries: entries)
                CreditsColumnContent(entries: entries)
            }
            .offset(y: offset)
            .background(
                CreditsColumnContent(entries: entries)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(key: CreditsHeightKey.self, value: geometry.size.height)
                        }
                    )
                    .hidden()
            )
            .onPreferenceChange(CreditsHeightKey.self) { newHeight in
                guard newHeight > 0 else { return }
                contentHeight = newHeight
                restartAnimation(viewportHeight: proxy.size.height)
            }
            .onAppear {
                restartAnimation(viewportHeight: proxy.size.height)
            }
        }
    }

    private func restartAnimation(viewportHeight: CGFloat) {
        guard contentHeight > viewportHeight else {
            offset = startOffset
            return
        }

        offset = startOffset
        let travelDistance = contentHeight + 12
        let duration = max(18.0, Double(travelDistance) / speed)

        DispatchQueue.main.async {
            withAnimation(Animation.linear(duration: duration).repeatForever(autoreverses: false)) {
                offset = startOffset - travelDistance
            }
        }
    }
}

@available(iOS 13.0, *)
private struct CreditsWallCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let entries: [CreditsEntry]
    let preferredHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(CreditsLocalized("about.credits.list_title"))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.94) : Color(red: 0.29, green: 0.22, blue: 0.42))

            GeometryReader { proxy in
                let columnCount = proxy.size.width >= 720 ? 4 : (proxy.size.width >= 500 ? 3 : 2)
                let columns = splitEntries(columnCount: columnCount)
                let layoutID = "credits-wall-\(columnCount)-\(Int(proxy.size.width.rounded()))-\(Int(proxy.size.height.rounded()))"

                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { index, columnEntries in
                        CreditsWallColumn(
                            entries: columnEntries,
                            speed: 18.0 + Double(index) * 2.4,
                            startOffset: CGFloat(index.isMultiple(of: 2) ? 0 : -36)
                        )
                        .frame(maxWidth: .infinity)
                        .id("\(layoutID)-column-\(index)")
                    }
                }
                .id(layoutID)
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.10),
                            .init(color: .black, location: 0.90),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(height: preferredHeight)
            .clipped()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.76))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.62), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.05), radius: 14, x: 0, y: 8)
    }

    private func splitEntries(columnCount: Int) -> [[CreditsEntry]] {
        var columns = Array(repeating: [CreditsEntry](), count: max(1, columnCount))
        for (index, entry) in entries.enumerated() {
            columns[index % columns.count].append(entry)
        }
        return columns
    }
}

@available(iOS 13.0, *)
private struct CreditsRootView: View {
    var body: some View {
        GeometryReader { proxy in
            let wallHeight = max(500, proxy.size.height - 230)

            ZStack {
                CreditsPurpleBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        CreditsHeaderCard()
                        CreditsWallCard(entries: creditsEntries, preferredHeight: wallHeight)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

@objcMembers
@available(iOS 13.0, *)
final class CreditsHostingViewController: UIViewController {
    private var hostingController: UIHostingController<CreditsRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        title = CreditsLocalized("about.credits.title")
        installHostingControllerIfNeeded()
        applyNavigationBarAppearance()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyNavigationBarAppearance()
    }

    private func installHostingControllerIfNeeded() {
        let rootView = CreditsRootView()
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

        let darkMode = traitCollection.userInterfaceStyle == .dark
        let accentColor = darkMode ? UIColor(red: 0.90, green: 0.85, blue: 0.99, alpha: 1.0) : UIColor(red: 0.31, green: 0.23, blue: 0.46, alpha: 1.0)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: accentColor,
            .font: UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        ]

        navigationBar.tintColor = accentColor
        navigationBar.titleTextAttributes = titleAttributes

        let appearance = UINavigationBarAppearance()
        appearance.titleTextAttributes = titleAttributes

        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear

        navigationBar.standardAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        if #available(iOS 15.0, *) {
            navigationBar.compactScrollEdgeAppearance = appearance
        }
        navigationBar.isTranslucent = true
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if let previousTraitCollection,
           traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyNavigationBarAppearance()
        }
    }
}
#endif
