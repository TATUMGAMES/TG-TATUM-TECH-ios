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
    }

    @Test func greetsWithTheLocalProfileName() async {
        let app = AppModel(dependencies: .uiTesting(signedIn: true))
        await app.start()
        await app.refreshLocalUser()
        #expect(app.localUser != nil)
        #expect(!app.greetingName.isEmpty)
        #expect(app.greetingName == app.localUser?.displayNameOrAnonymous)
    }

    @Test func startsSignedOutWithoutAnAccount() async {
        let app = AppModel(dependencies: .uiTesting(signedIn: false))
        await app.start()
        #expect(app.phase == .signedOut)
    }

    @Test func deletingAnAppleAccountRevokesTokensAndDeletesTheFirebaseUser() async {
        let firebase = InMemoryFirebaseAuthentication(signedInUserID: AppDependencies.uiTestFirebaseUserID)
        let app = AppModel(dependencies: .uiTesting(signedIn: true, firebaseAuth: firebase))
        await app.start()

        #expect(await app.deleteAccount() == .deleted)

        #expect(app.phase == .signedOut)
        #expect(await app.accountService.state() == .signedOut)
        #expect(firebase.revokedAuthorizationCodes == ["ui-test-code"])
        #expect(firebase.deletedUserIDs == [AppDependencies.uiTestFirebaseUserID])
    }

    @Test func cancellingAppleReauthorizationKeepsTheAccount() async {
        let firebase = InMemoryFirebaseAuthentication(signedInUserID: AppDependencies.uiTestFirebaseUserID)
        let app = AppModel(dependencies: .uiTesting(
            signedIn: true,
            firebaseAuth: firebase,
            appleReauthorizer: StubAppleReauthorizer(result: .failure(.cancelled))
        ))
        await app.start()

        #expect(await app.deleteAccount() == .cancelled)

        guard case .signedIn = app.phase else { Issue.record("Expected to stay signed in"); return }
        #expect(firebase.deletedUserIDs.isEmpty)
    }

    @Test func failedRevocationKeepsTheAccountAndExplains() async {
        let firebase = InMemoryFirebaseAuthentication(signedInUserID: AppDependencies.uiTestFirebaseUserID)
        let app = AppModel(dependencies: .uiTesting(signedIn: true, firebaseAuth: firebase))
        await app.start()
        firebase.failNext(with: .network)

        guard case let .failed(message) = await app.deleteAccount() else { Issue.record("Expected a failure"); return }

        #expect(message.message == AlertMessage.networkMessage)
        guard case .signedIn = app.phase else { Issue.record("Expected to stay signed in"); return }
        guard case .signedIn = await app.accountService.state() else { Issue.record("Expected to stay signed in"); return }
    }

    @Test func appleUserCanSignOutAndBackIn() async throws {
        let firebase = InMemoryFirebaseAuthentication()
        let app = AppModel(dependencies: .uiTesting(signedIn: false, firebaseAuth: firebase))
        await app.start()
        let identity = AppleIdentity(userID: "a-1", identityToken: "token", rawNonce: "nonce", givenName: "Ada", familyName: "Lovelace")

        app.apply(try await app.accountService.completeAppleSignIn(identity).state)
        guard case .signedIn = app.phase else { Issue.record("Expected signed in"); return }

        await app.appleCredentialRevoked()
        #expect(app.phase == .signedOut)
        #expect(firebase.currentUserID == nil)

        app.apply(try await app.accountService.completeAppleSignIn(identity).state)
        guard case .signedIn = app.phase else { Issue.record("Expected signed in again"); return }
    }

    @Test func appleNameSeedsANewProfileOnly() async throws {
        let app = AppModel(dependencies: .uiTesting(signedIn: false, firebaseAuth: InMemoryFirebaseAuthentication()))
        await app.start()
        let identity = AppleIdentity(userID: "a-1", identityToken: "token", rawNonce: "nonce", givenName: "Ada", familyName: "Lovelace")
        app.apply(try await app.accountService.completeAppleSignIn(identity).state)

        await app.refreshLocalUser()
        #expect(app.localUser?.firstName == "Ada")
        #expect(app.localUser?.lastName == "Lovelace")

        await app.local.updateProfile(firstName: "Augusta", lastName: "", email: "")
        await app.refreshLocalUser()
        #expect(app.localUser?.firstName == "Augusta")
        #expect(app.localUser?.lastName == nil)
    }

    @Test func bundledContentLoadsThroughTheRepository() async throws {
        let content = AppDependencies.uiTesting(signedIn: false).content
        let events = try await content.upcomingEvents()
        let partners = try await content.partners()
        #expect(!events.isEmpty)
        #expect(!partners.isEmpty)
    }
}
