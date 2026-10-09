import Testing
@testable import TatumTech

@MainActor
@Suite("Profile save")
struct ProfileSaveModelTests {
    /// Counts save calls and answers them, optionally waiting until released.
    @MainActor
    private final class SaveStub {
        var calls = 0
        var result: AppModel.SaveProfileResult = .saved
        private var pending: CheckedContinuation<Void, Never>?
        var holdsCalls = false

        var isWaiting: Bool { pending != nil }

        func save() async -> AppModel.SaveProfileResult {
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

    private let failure = AlertMessage(title: "Unable to Save Profile", message: "Can't reach Tatum Tech.", canRetry: true)

    @Test func successfulSaveConfirmsWithAToast() async {
        let model = ProfileSaveModel()
        let stub = SaveStub()

        await model.save(using: stub.save)

        #expect(stub.calls == 1)
        #expect(!model.isSaving)
        #expect(model.toast?.text == "Profile updated successfully!")
        #expect(model.alert == nil)
    }

    @Test func repeatedSavesWhileSavingSendOneRequest() async {
        let model = ProfileSaveModel()
        let stub = SaveStub()
        stub.holdsCalls = true

        let first = Task { await model.save(using: stub.save) }
        while !stub.isWaiting { await Task.yield() }
        #expect(model.isSaving)

        await model.save(using: stub.save)

        stub.release()
        await first.value
        #expect(stub.calls == 1)
        #expect(!model.isSaving)
    }

    @Test func failureExplainsWithoutConfirming() async {
        let model = ProfileSaveModel()
        let stub = SaveStub()
        stub.result = .failed(failure)

        await model.save(using: stub.save)

        #expect(!model.isSaving)
        #expect(model.toast == nil)
        #expect(model.alert == failure)
        #expect(model.alert?.canRetry == true)
    }

    @Test func retryAfterAFailureSendsANewRequest() async {
        let model = ProfileSaveModel()
        let stub = SaveStub()
        stub.result = .failed(failure)
        await model.save(using: stub.save)

        stub.result = .saved
        await model.save(using: stub.save)

        #expect(stub.calls == 2)
        #expect(model.alert == nil)
    }
}
