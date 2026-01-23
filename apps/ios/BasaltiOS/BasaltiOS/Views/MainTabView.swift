import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 1 // 0: Today, 1: Collections
    @State private var isZooming = false // Track zoom state for tab bar visibility
    @StateObject private var todayViewModel = TodayViewModel()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(isZooming: $isZooming, viewModel: todayViewModel)
                .tabItem {
                    Label("Today", systemImage: "calendar")
                }
                .tag(0)
            
            NavigationStack {
                CollectionsView()
                    .navigationDestination(for: Collection.self) { collection in
                        CollectionDetailView(initialCollection: collection)
                    }
            }
            .tabItem {
                Label("Collections", systemImage: "archivebox")
            }
            .tag(1)
        }
        .toolbarBackground(isZooming ? .hidden : .visible, for: .tabBar)
        .toolbar(isZooming ? .hidden : .visible, for: .tabBar)
    }
}

#Preview {
    MainTabView()
}
