import SwiftUI

/// Brand colors. Values live in the asset catalog (`Colors/`) so they can gain dark variants later.
enum Palette {
    /// Lavender brand color. Pair with `textPrimary`, not white, for contrast.
    static let brandPrimary = Color("BrandPrimary")
    /// Deep purple for tinted text, links, and selection on light backgrounds.
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

    /// Accent colors used by progress rings, badges, and store buttons.
    static let purpleDeep = Color(hex: 0x3700B3)
    static let gold = Color(hex: 0xFFC107)
    static let teal = Color(hex: 0x03DAC5)
    static let tealDeep = Color(hex: 0x018786)
    static let deepOrange = Color(hex: 0xFF5722)
    static let successGreen = Color(hex: 0x4CAF50)
    static let destructive = Color(hex: 0xD32F2F)
    static let lightGrey = Color(hex: 0xEEEEEE)
    static let mediumGrey = Color(hex: 0xBDBDBD)
    static let grey = Color(hex: 0x9E9E9E)
    static let lavender = Color(hex: 0xEDE7F6)
    static let discordBlurple = Color(hex: 0x5865F2)
    static let discordGreen = Color(hex: 0x43B581)
    static let steamDark = Color(hex: 0x1B2838)

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

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
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
