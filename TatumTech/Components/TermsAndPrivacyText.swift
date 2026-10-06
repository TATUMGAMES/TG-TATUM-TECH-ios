import SwiftUI

enum LegalLinks {
    static let terms = URL(string: "https://developer.tatumgames.com/terms")!
    static let privacy = URL(string: "https://developer.tatumgames.com/privacy")!
}

/// "By continuing…" consent line with tappable Terms and Privacy Policy links.
struct TermsAndPrivacyText: View {
    var body: some View {
        Text("By continuing, you confirm that you have read, agree and accept Tatum Tech's [Terms](https://developer.tatumgames.com/terms) and [Privacy Policy](https://developer.tatumgames.com/privacy)")
            .font(.footnote)
            .foregroundStyle(Palette.textPrimary)
            .tint(Palette.brandPrimaryStrong)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}
