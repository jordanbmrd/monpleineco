import SwiftUI

struct StationCarouselCard: View {
    let station: StationWithMetrics
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Header: rank badge
                HStack(alignment: .center) {
                    if station.rank <= 3 {
                        Text(rankLabel)
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(rankColor, in: Capsule())
                    } else {
                        Text("#\(station.rank)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                // Station name + brand
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.station.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(station.station.brand ?? "Indépendant")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Divider().opacity(0.5)

                // Price + distance
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(FormattingUtils.formatPrice(station.bestPrice))
                            .font(.system(.callout, design: .rounded, weight: .heavy))
                            .foregroundStyle(.brand)
                            .monospacedDigit()
                        Text("€/L")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label(FormattingUtils.formatDistance(station.distanceToRoute), systemImage: "location.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.carouselCard, style: .continuous)
                    .fill(Color(.systemBackground))
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.carouselCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.carouselCard, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(CardPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(station.station.name), \(FormattingUtils.formatPrice(station.bestPrice)) euros par litre")
        .accessibilityAddTraits(.isButton)
    }

    private var rankLabel: String {
        switch station.rank {
        case 1: "🥇 #1"
        case 2: "🥈 #2"
        case 3: "🥉 #3"
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
