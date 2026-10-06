import SwiftUI

/// Brand colors. Values live in the asset catalog (`Colors/`) so they can gain dark variants later.
enum Palette {
    /// Lavender brand color (Android `purple_200`). Pair with `textPrimary`, not white, for contrast.
    static let brandPrimary = Color("BrandPrimary")
    /// Deep purple for tinted text, links, and selection on light backgrounds (Android `Purple500`).
    static let brandPrimaryStrong = Color("BrandPrimaryStrong")
    static let brandSecondary = Color("BrandSecondary")

    static let screenBackground = Color("ScreenBackground")
    static let surface = Color("SurfaceBackground")
    static let featureCardBackground = Color("FeatureCardBackground")
    static let iconBackground = Color("IconBackground")

    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let divider = Color("Divider")
    static let disabled = Color("Disabled")

    static let error = Color("Error")
    static let success = Color("Success")
    static let featuredAccent = Color("FeaturedAccent")
    static let partnerContact = Color("PartnerContact")
    static let partnerDonation = Color("PartnerDonation")

    /// Solid fills content can request with `color://<name>`.
    static func swatch(named name: String) -> Color {
        switch name {
        case "spring_purple": Color("SwatchSpringPurple")
        case "spring_purple2": Color("SwatchSpringPurpleStrong")
        default: disabled
        }
    }
}

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Radius {
    static let small: CGFloat = 8
    static let button: CGFloat = 10
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
}

enum Metrics {
    /// Height of primary call-to-action buttons.
    static let buttonHeight: CGFloat = 56
    /// Widest the auth buttons grow on large phones.
    static let authButtonMaxWidth: CGFloat = 320
    static let minimumTapTarget: CGFloat = 44
}

extension View {
    /// White rounded card with the soft shadow used across content lists.
    func cardSurface(cornerRadius: CGFloat = Radius.large) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Palette.surface)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }
}
