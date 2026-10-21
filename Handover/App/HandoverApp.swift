import SwiftUI
import SwiftData

@main
struct HandoverApp: App {
    @State private var store = StoreManager()

    let container: ModelContainer = {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration("Handover", schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not open the Handover database: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task { await store.load() }
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @AppStorage(PrefKey.hasOnboarded) private var hasOnboarded = false

    var body: some View {
        Group {
            if hasOnboarded {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .tint(Theme.accent)
    }
}

struct MainTabView: View {
    @Environment(StoreManager.self) private var store
    @AppStorage("shownIntroPaywall") private var shownIntroPaywall = false
    @State private var showingPaywall = false

    var body: some View {
        TabView {
            PropertiesListView()
                .tabItem { Label("Properties", systemImage: "house.fill") }
            RemindersView()
                .tabItem { Label("Reminders", systemImage: "bell.badge.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .sheet(isPresented: $showingPaywall) { PaywallView(reason: .general) }
        .task {
            // Offer Pro once, right after onboarding. It's always dismissible.
            guard !shownIntroPaywall else { return }
            shownIntroPaywall = true
            try? await Task.sleep(for: .milliseconds(600))
            if !store.isPro { showingPaywall = true }
        }
    }
}
