import SwiftUI

@main
struct TatumTechApp: App {
    @State private var appModel = AppModel(dependencies: AppDependencies.makeForLaunch())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .onOpenURL { url in
                    _ = appModel.dependencies.googleSignIn.handle(url)
                }
        }
    }
}
