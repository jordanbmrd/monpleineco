import SwiftUI

struct StationCarouselCard: View {
    let station: StationWithMetrics
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                brandHeader
                cardBody
            }
            .frame(width: Theme.Spacing.carouselCardWidth)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.carouselCard, style: .continuous))
            .shadow(
                color: Theme.Shadow.floatingCard.color,
                radius: Theme.Shadow.floatingCard.radius,
                y: Theme.Shadow.floatingCard.y
            )
        }
        .buttonStyle(CardPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(station.station.name), \(FormattingUtils.formatPrice(station.bestPrice)) euros par litre")
        .accessibilityAddTraits(.isButton)
    }

    private var brandHeader: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color.brand.opacity(0.15), Color.brandLight.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 80)

            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "fuelpump.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.brand)

                if station.rank <= 3 {
                    Text(rankLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(rankColor, in: Capsule())
                }
            }
            .padding(12)
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(station.station.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(station.station.brand ?? "Indépendant")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(FormattingUtils.formatPrice(station.bestPrice))
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(.brand)
                    .monospacedDigit()
                Text("€/L")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Label(FormattingUtils.formatDistance(station.distanceToRoute), systemImage: "location.fill")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    private var rankLabel: String {
        switch station.rank {
        case 1: "#1"
        case 2: "#2"
        case 3: "#3"
        default: "#\(station.rank)"
        }
    }

    private var rankColor: Color {
        switch station.rank {
        case 1: .brand
        case 2: .podiumGold
        case 3: .podiumBronze
        default: .secondary
        }
    }
}
