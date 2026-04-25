import SwiftUI

struct StationCarouselCard: View {
    let station: StationWithMetrics
    let onTap: () -> Void

    @AppStorage("tankSize") private var tankSize = 50

    private var isTop3: Bool { (1...3).contains(station.rank) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left accent bar for top 3
                if isTop3 {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(rankGradient)
                        .frame(width: 4)
                        .padding(.vertical, 10)
                }

                VStack(spacing: 0) {
                    // Top row: rank + name + brand
                    HStack(alignment: .top, spacing: 10) {
                        // Rank indicator
                        ZStack {
                            Circle()
                                .fill(isTop3 ? rankColor.opacity(0.12) : Color(.tertiarySystemFill))
                                .frame(width: 30, height: 30)
                            Text("\(station.rank)")
                                .font(.system(.caption, design: .rounded, weight: .black))
                                .foregroundStyle(isTop3 ? rankColor : .secondary)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(station.station.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            HStack(spacing: 6) {
                                Text(station.station.brand ?? "Indépendant")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                if station.distanceToRoute > 0 {
                                    Circle()
                                        .fill(Color(.quaternaryLabel))
                                        .frame(width: 3, height: 3)
                                    HStack(spacing: 2) {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 8, weight: .bold))
                                        Text(FormattingUtils.formatDistance(station.distanceToRoute))
                                            .font(.caption2.weight(.medium))
                                    }
                                    .foregroundStyle(.secondary)
                                }

                                if let detour = station.detourDuration {
                                    Circle()
                                        .fill(Color(.quaternaryLabel))
                                        .frame(width: 3, height: 3)
                                    HStack(spacing: 2) {
                                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                            .font(.system(size: 8, weight: .bold))
                                        Text(FormattingUtils.formatDetour(detour))
                                            .font(.caption2.weight(.semibold))
                                            .monospacedDigit()
                                    }
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer(minLength: 0)

                        BrandBadgeView(brand: station.station.brand, size: 28)
                    }

                    Spacer(minLength: 4)

                    // Bottom row: price + full tank
                    HStack(alignment: .bottom) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(FormattingUtils.formatPrice(station.bestPrice))
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(isTop3 ? rankColor : .brand)
                                .monospacedDigit()
                            VStack(alignment: .leading, spacing: 0) {
                                Text("€/L")
                                    .font(.system(.caption2, design: .rounded, weight: .bold))
                                    .foregroundStyle(.secondary)
                                Text(station.bestFuelLabel)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        Spacer()

                        let total = station.bestPrice * Double(tankSize)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(String(format: "%.2f", total)) €")
                                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                .foregroundStyle(.primary)
                                .monospacedDigit()
                            Text("plein \(tankSize) L")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.quaternary)
                            .padding(.leading, 4)
                    }
                }
                .padding(.horizontal, isTop3 ? 12 : 14)
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.elevatedCard)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        isTop3 ? rankColor.opacity(0.25) : Color.cardBorder,
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            .shadow(color: .black.opacity(0.03), radius: 1, y: 1)
        }
        .buttonStyle(CardPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(station.station.name), \(FormattingUtils.formatPrice(station.bestPrice)) euros par litre")
        .accessibilityAddTraits(.isButton)
    }

    private var rankColor: Color {
        switch station.rank {
        case 1: .brand
        case 2: .podiumGold
        case 3: .podiumBronze
        default: .secondary
        }
    }

    private var rankGradient: LinearGradient {
        LinearGradient(
            colors: [rankColor, rankColor.opacity(0.4)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
