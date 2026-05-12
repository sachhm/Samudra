import SwiftUI

@main
struct SamudraApp: App {
    @State private var splashDone = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .opacity(splashDone ? 1 : 0)

                if !splashDone {
                    SplashView {
                        splashDone = true
                    }
                    .transition(.opacity)
                }
            }
            .preferredColorScheme(.light)
            .statusBarHidden()
        }
    }
}
