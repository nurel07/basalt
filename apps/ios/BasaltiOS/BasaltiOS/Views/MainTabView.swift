import SwiftUI

struct MainTabView: View {
    private enum Tab: Int {
        case today
        case collections
        case settings
    }
    
    @State private var selectedTab: Tab = .today
    @State private var lastContentTab: Tab = .today
    @State private var isZooming = false
    @State private var showSettings = false
    @StateObject private var todayViewModel = TodayViewModel()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(isZooming: $isZooming, viewModel: todayViewModel)
                .tabItem {
                    Label("Today", systemImage: "paintpalette")
                }
                .tag(Tab.today)
            
            NavigationStack {
                CollectionsView()
                    .navigationDestination(for: Collection.self) { collection in
                        CollectionDetailView(initialCollection: collection)
                    }
            }
            .tabItem {
                Label("Collections", systemImage: "square.stack.fill")
            }
            .tag(Tab.collections)
            
            Color.clear
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .settings {
                showSettings = true
                selectedTab = lastContentTab
            } else {
                lastContentTab = newValue
            }
        }
        .toolbarBackground(isZooming ? .hidden : .visible, for: .tabBar)
        .toolbar(isZooming ? .hidden : .visible, for: .tabBar)
    }
}

private struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("General")) {
                    NavigationLink {
                        NotificationsSettingsView()
                    } label: {
                        Label("Notifications", systemImage: "bell.badge")
                    }
                }
                
                Section(header: Text("Links")) {
                    Button {
                        if let url = URL(string: "https://basalt.yevgenglukhov.com/privacy") {
                            openURL(url)
                        }
                    } label: {
                        Label("Privacy Policy", systemImage: "lock.shield")
                    }
                    
                    Button {
                        if let url = URL(string: "https://basalt.yevgenglukhov.com") {
                            openURL(url)
                        }
                    } label: {
                        Label("Basalt Website", systemImage: "safari")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    MainTabView()
}
