import Testing
@testable import TatumTech

@MainActor
@Suite("Profile sign-out")
struct ProfileSignOutModelTests {
    /// Counts sign-out calls and answers them, optionally waiting until released.
    @MainActor
    private final class SignOutStub {
        var calls = 0
        var result: AppModel.SignOutResult = .signedOut
        private var pending: CheckedContinuation<Void, Never>?
        var holdsCalls = false

        var isWaiting: Bool { pending != nil }

        func signOut() async -> AppModel.SignOutResult {
            calls += 1
            if holdsCalls {
                await withCheckedContinuation { pending = $0 }
            }
            return result
        }

        func release() {
            pending?.resume()
            pending = nil
        }
    }

    private let failure = AlertMessage(title: "Unable to Sign Out", message: "Can't reach Tatum Tech.", canRetry: true)

    @Test func tappingSignOutOnlyAsksForConfirmation() {
        let model = ProfileSignOutModel()

        model.requestSignOut()

        #expect(model.isConfirming)
        #expect(!model.isSigningOut)
    }

    @Test func confirmingSignsOutOnce() async {
        let model = ProfileSignOutModel()
        let stub = SignOutStub()
        model.requestSignOut()

        await model.confirm(using: stub.signOut)

        #expect(stub.calls == 1)
        #expect(!model.isConfirming)
        #expect(model.alert == nil)
    }

    @Test func repeatedConfirmsWhileSigningOutSendOneRequest() async {
        let model = ProfileSignOutModel()
        let stub = SignOutStub()
        stub.holdsCalls = true

        let first = Task { await model.confirm(using: stub.signOut) }
        while !stub.isWaiting { await Task.yield() }
        #expect(model.isSigningOut)

        await model.confirm(using: stub.signOut)
        model.requestSignOut()
        #expect(!model.isConfirming)

        stub.release()
        await first.value
        #expect(stub.calls == 1)
    }

    @Test func failureStaysOnProfileAndExplains() async {
        let model = ProfileSignOutModel()
        let stub = SignOutStub()
        stub.result = .failed(failure)
        model.requestSignOut()

        await model.confirm(using: stub.signOut)

        #expect(!model.isSigningOut)
        #expect(!model.isConfirming)
        #expect(model.alert == failure)
        #expect(model.alert?.canRetry == true)
    }

    @Test func retryAfterAFailureSendsANewRequest() async {
        let model = ProfileSignOutModel()
        let stub = SignOutStub()
        stub.result = .failed(failure)
        await model.confirm(using: stub.signOut)

        stub.result = .signedOut
        await model.confirm(using: stub.signOut)

        #expect(stub.calls == 2)
        #expect(model.alert == nil)
    }
}
