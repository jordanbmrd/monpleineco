import SwiftUI
import MapKit

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct ContentView: View {
    @State private var vm = SearchViewModel()
    @State private var selectedTab: Tab = .home

    enum Tab: String {
        case home, route, favorites, profile
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeMapView(vm: vm)
                    .tag(Tab.home)

                RouteSearchView(vm: vm)
                    .tag(Tab.route)

                FavoritesView()
                    .tag(Tab.favorites)

                ProfileView()
                    .tag(Tab.profile)
            }
            .toolbar(.hidden, for: .tabBar)

            customTabBar
        }
        .task { await vm.setupInitialLocation() }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabItem(tab: .home, icon: "house.fill", label: "Accueil")
            tabItem(tab: .route, icon: "arrow.triangle.swap", label: "Trajet")
            tabItem(tab: .favorites, icon: "heart.fill", label: "Favoris")
            tabItem(tab: .profile, icon: "person.fill", label: "Profil")
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.06), radius: 12, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabItem(tab: Tab, icon: String, label: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if selectedTab == tab {
                        Circle()
                            .fill(Color.brand)
                            .frame(width: 44, height: 44)
                            .transition(.scale.combined(with: .opacity))
                    }

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(selectedTab == tab ? .white : .secondary)
                }
                .frame(width: 44, height: 44)

                Text(label)
                    .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium))
                    .foregroundStyle(selectedTab == tab ? .brand : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .accessibilityLabel(label)
    }
}

// MARK: - Price Annotation

struct PriceAnnotationView: View {
    let station: StationWithMetrics
    var isSelected: Bool = false

    private var isTop3: Bool { station.rank <= 3 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                if station.rank == 1 {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(isTop3 ? .white : .brand)
                }
                Text(FormattingUtils.formatPrice(station.bestPrice))
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .foregroundStyle(isTop3 ? .white : .primary)
                    .monospacedDigit()
            }
            .padding(.horizontal, isTop3 ? 10 : 8)
            .padding(.vertical, isTop3 ? 7 : 5)
            .background(
                Capsule()
                    .fill(isTop3 ? AnyShapeStyle(.brandGradient) : AnyShapeStyle(Color(.systemBackground)))
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.brand : (isTop3 ? .clear : Color(.separator).opacity(0.5)),
                        lineWidth: isSelected ? 2.5 : (isTop3 ? 0 : 1)
                    )
            )
            .shadow(
                color: isTop3 ? Color.brand.opacity(0.3) : Theme.Shadow.annotation.color,
                radius: isSelected ? 10 : Theme.Shadow.annotation.radius,
                y: Theme.Shadow.annotation.y
            )
            .scaleEffect(isSelected ? 1.15 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

            AnnotationPointer()
                .fill(isTop3 ? Color.brand : Color(.systemBackground))
                .frame(width: 12, height: 6)
                .offset(y: -1)
        }
    }
}

// MARK: - Formatting

enum FormattingUtils {
    private static let priceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "fr-FR")
        f.minimumFractionDigits = 3
        f.maximumFractionDigits = 3
        return f
    }()

    static func formatPrice(_ value: Double) -> String {
        priceFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.3f", value)
    }

    static func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters.rounded())) m"
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours <= 0 {
            return "\(minutes) min"
        }
        return "\(hours) h \(String(format: "%02d", minutes)) min"
    }
}
