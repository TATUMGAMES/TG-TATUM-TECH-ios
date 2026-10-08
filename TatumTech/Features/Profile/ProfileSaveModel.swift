import Foundation
import Observation

/// Save flow of the Profile screen: a single in-flight request, the confirmation toast, and the
/// failure alert.
@MainActor
@Observable
final class ProfileSaveModel {
    /// The request is running; the screen shows progress and ignores input.
    private(set) var isSaving = false
    /// Why the last attempt failed. Offers "Try Again" when the failure is transient.
    var alert: AlertMessage?
    /// Shown once the profile is saved.
    var toast: ToastMessage?

    /// Ignored while a save is running, so the request is never sent twice.
    func save(using save: @MainActor () async -> AppModel.SaveProfileResult) async {
        guard !isSaving else { return }
        alert = nil
        isSaving = true
        switch await save() {
        case .saved:
            toast = ToastMessage(text: "Profile updated successfully!")
        case let .failed(message):
            alert = message
        }
        isSaving = false
    }
}
