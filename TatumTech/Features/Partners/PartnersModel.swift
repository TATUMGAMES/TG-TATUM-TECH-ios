import Foundation
import Observation
import OSLog
import TatumTechKit

@MainActor
@Observable
final class PartnersModel {
    private(set) var state: LoadState<[Partner]> = .loading
    /// `nil` shows every category.
    var selectedCategory: PartnerCategory?
    private let repository: any ContentRepository
    private let logger = Logger(subsystem: AppLog.subsystem, category: "Partners")

    init(repository: any ContentRepository) {
        self.repository = repository
    }

    /// Partners in the selected category, featured first, then by name.
    var visiblePartners: [Partner] {
        guard case let .loaded(partners) = state else { return [] }
        return PartnerDirectory.filter(partners, category: selectedCategory)
    }

    func load() async {
        if case .loaded = state { return }
        await reload()
    }

    func reload() async {
        state = .loading
        do {
            state = .loaded(try await repository.partners())
        } catch is CancellationError {
            return
        } catch {
            logger.error("Loading partners failed: \(String(describing: error), privacy: .public)")
            state = .failed
        }
    }
}
