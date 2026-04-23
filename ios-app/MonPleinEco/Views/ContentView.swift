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
        case home, favorites, profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeMapView(vm: vm)
                .tag(Tab.home)
                .tabItem {
                    Label("Accueil", systemImage: "house.fill")
                }

            FavoritesView()
                .tag(Tab.favorites)
                .tabItem {
                    Label("Favoris", systemImage: "heart.fill")
                }

            ProfileView()
                .tag(Tab.profile)
                .tabItem {
                    Label("Profil", systemImage: "person.fill")
                }
        }
        .tint(.brand)
        .toolbar(vm.isHomeSearchExpanded ? .hidden : .automatic, for: .tabBar)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: vm.isHomeSearchExpanded)
        .task { await vm.setupInitialLocation() }
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
                    .fill(isTop3 ? AnyShapeStyle(.brandGradient) : AnyShapeStyle(Color.elevatedCard))
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.brand : (isTop3 ? .clear : Color.cardBorder),
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
                .fill(isTop3 ? Color.brand : Color.elevatedCard)
                .frame(width: 12, height: 6)
                .offset(y: -1)
        }
    }
}

// MARK: - Cluster Annotation

struct ClusterAnnotationView: View {
    let count: Int

    var body: some View {
        Text("\(count)+")
            .font(.system(.caption, design: .rounded, weight: .heavy))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Circle()
                    .fill(Color.elevatedCard)
            )
            .overlay(
                Circle()
                    .stroke(Color.cardBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
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

    static func formatDetour(_ seconds: TimeInterval) -> String {
        let minutes = Int(ceil(seconds / 60))
        if minutes < 1 {
            return "+<1 min"
        }
        if minutes < 60 {
            return "+\(minutes) min"
        }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "+\(h) h" : "+\(h) h \(m) min"
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
