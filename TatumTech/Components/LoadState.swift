import SwiftUI

/// Progress of loading a screen's content.
enum LoadState<Value> {
    case loading
    case loaded(Value)
    case failed
}

extension LoadState: Equatable where Value: Equatable {}

/// Centered progress indicator with an optional caption.
struct LoadingView: View {
    var caption: LocalizedStringKey?

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ProgressView()
            if let caption {
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Inline error with a retry button; shown instead of a list when content could not load.
struct LoadFailedView: View {
    var message: LocalizedStringKey = "We couldn't load this right now. Check your connection and try again."
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again", action: retry)
                .buttonStyle(.filledAction())
                .frame(maxWidth: 200)
        }
    }
}

/// Message for a successful load with nothing to show.
struct EmptyStateView: View {
    let message: LocalizedStringKey
    var systemImage: String = "tray"

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(message)
            } icon: {
                Image(systemName: systemImage)
            }
        }
    }
}
