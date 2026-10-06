import Foundation
import OSLog
import TatumTechKit

/// Content shipped inside the app: challenge questions, achievements, careers, learning resources,
/// and games. Each file is decoded once, off the main actor, on first use.
actor BundledCatalog {
    enum CatalogError: LocalizedError {
        case unreadable(String)

        var errorDescription: String? {
            switch self {
            case let .unreadable(name): "\(name) could not be read."
            }
        }
    }

    private let loadFile: @Sendable (String) throws -> Data
    private let logger = Logger(subsystem: AppLog.subsystem, category: "Content")

    private var questionBankCache: QuestionBank?
    private var achievementsCache: [Achievement]?
    private var careersCache: [CareerListing]?
    private var resourcesCache: [LearningResource]?
    private var gamesCache: GameCatalog?
    private var gamesResourcesCache: [GamesResourceCategory]?

    init(loadFile: @escaping @Sendable (String) throws -> Data) {
        self.loadFile = loadFile
    }

    var questionBank: QuestionBank {
        if let questionBankCache { return questionBankCache }
        let bank = QuestionBank.load(using: loadFile)
        for issue in bank.loadIssues {
            logger.error("Challenge file skipped: \(issue, privacy: .public)")
        }
        questionBankCache = bank
        return bank
    }

    func achievements() throws -> [Achievement] {
        if let achievementsCache { return achievementsCache }
        let list = try Achievement.decodeList(from: data("achievements.json"))
        achievementsCache = list
        return list
    }

    func careers() throws -> [CareerListing] {
        if let careersCache { return careersCache }
        let list = try JSONDecoder().decode([CareerListing].self, from: data("career_listings.json"))
        careersCache = list
        return list
    }

    func resources() throws -> [LearningResource] {
        if let resourcesCache { return resourcesCache }
        let list = try JSONDecoder().decode([LearningResource].self, from: data("resources.json"))
        resourcesCache = list
        return list
    }

    func games() throws -> GameCatalog {
        if let gamesCache { return gamesCache }
        let catalog = try GameCatalog.decode(data("games.json"))
        gamesCache = catalog
        return catalog
    }

    func gamesResources() throws -> [GamesResourceCategory] {
        if let gamesResourcesCache { return gamesResourcesCache }
        let list = try JSONDecoder().decode([GamesResourceCategory].self, from: data("games_resources.json"))
        gamesResourcesCache = list
        return list
    }

    private func data(_ name: String) throws -> Data {
        do {
            return try loadFile(name)
        } catch {
            logger.error("Bundled file missing: \(name, privacy: .public)")
            throw CatalogError.unreadable(name)
        }
    }
}
