import Testing
import TatumTechKit
@testable import TatumTech

@MainActor
@Suite("App model and bundled content")
struct AppModelTests {
    @Test func restoresAStoredAccountAtLaunch() async {
        let app = AppModel(dependencies: .uiTesting(signedIn: true))
        await app.start()
        guard case let .signedIn(summary) = app.phase else {
            Issue.record("Expected to be signed in")
            return
        }
        #expect(summary.method == .apple)
        #expect(app.displayName == "Ada")
    }

    @Test func startsSignedOutWithoutAnAccount() async {
        let app = AppModel(dependencies: .uiTesting(signedIn: false))
        await app.start()
        #expect(app.phase == .signedOut)
    }

    @Test func deleteAccountSignsOut() async {
        let app = AppModel(dependencies: .uiTesting(signedIn: true))
        await app.start()
        await app.deleteAccount()
        #expect(app.phase == .signedOut)
        #expect(await app.accountService.state() == .signedOut)
    }

    @Test func bundledContentLoadsThroughTheRepository() async throws {
        let content = AppDependencies.uiTesting(signedIn: false).content
        let events = try await content.upcomingEvents()
        let partners = try await content.partners()
        #expect(!events.isEmpty)
        #expect(!partners.isEmpty)
    }
}
