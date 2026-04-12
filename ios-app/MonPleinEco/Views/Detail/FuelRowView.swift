import SwiftUI

struct FuelRowView: View {
    let fuel: StationFuel
    let isBest: Bool

    private var isAvailable: Bool {
        fuel.available && fuel.price != nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isBest ? "drop.fill" : "drop")
                .font(.body.weight(.medium))
                .foregroundStyle(isBest ? .brand : isAvailable ? .secondary : Color(.quaternaryLabel))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(fuel.shortName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isBest ? Color.brand : isAvailable ? Color.primary : Color(.tertiaryLabel))
                Text(fuel.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isAvailable, let price = fuel.price {
                Text(FormattingUtils.formatPrice(price))
                    .font(.system(isBest ? .title3 : .body, design: .rounded, weight: .heavy))
                    .foregroundStyle(isBest ? .brand : .primary)
                    .monospacedDigit()
                Text("€/L")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("Indisponible")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.cardPadding)
        .padding(.vertical, 13)
        .background(
            isBest
            ? Color.brand.opacity(0.04)
            : isAvailable ? Color(.systemBackground) : Color(.secondarySystemBackground).opacity(0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                .stroke(isBest ? Color.brand.opacity(0.2) : Color(.separator).opacity(0.3), lineWidth: 1)
        )
        .opacity(isAvailable ? 1 : 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if isAvailable, let price = fuel.price {
            "\(fuel.name), \(FormattingUtils.formatPrice(price)) euros par litre\(isBest ? ", meilleur prix" : "")"
        } else {
            "\(fuel.name), non disponible"
        }
    }
}
