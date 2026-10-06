import SwiftUI

/// Main call to action. When disabled it switches to an outlined look, as on Android.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    init() {}

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
        return configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
            .padding(.horizontal, Spacing.md)
            .foregroundStyle(isEnabled ? Palette.textPrimary : Palette.textSecondary)
            .background(shape.fill(isEnabled ? Palette.brandPrimary : Color.clear))
            .overlay(shape.strokeBorder(Palette.brandPrimary, lineWidth: isEnabled ? 0 : 1.5))
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Compact filled action (Register, Join, Contact, Donate). Text is dark for contrast on the
/// light brand fills.
struct FilledActionButtonStyle: ButtonStyle {
    let fill: Color
    @Environment(\.isEnabled) private var isEnabled

    init(fill: Color = Palette.brandPrimary) {
        self.fill = fill
    }

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
        return configuration.label
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
            .padding(.horizontal, Spacing.sm)
            .foregroundStyle(isEnabled ? Palette.textPrimary : Palette.textSecondary)
            .background(shape.fill(isEnabled ? fill : Palette.disabled))
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Secondary outlined action (product links, additional links).
struct OutlinedActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
        return configuration.label
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
            .padding(.horizontal, Spacing.sm)
            .foregroundStyle(Palette.brandPrimaryStrong)
            .overlay(shape.strokeBorder(Palette.divider, lineWidth: 1))
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == OutlinedActionButtonStyle {
    static var outlinedAction: OutlinedActionButtonStyle { OutlinedActionButtonStyle() }
}

extension ButtonStyle where Self == FilledActionButtonStyle {
    static func filledAction(_ fill: Color = Palette.brandPrimary) -> FilledActionButtonStyle {
        FilledActionButtonStyle(fill: fill)
    }
}
