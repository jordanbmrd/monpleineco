import SwiftUI

struct FuelRowView: View {
    let fuel: StationFuel

    private var isAvailable: Bool {
        fuel.available && fuel.price != nil
    }

    private var dropColor: Color {
        fuel.fuelType?.dropColor ?? .secondary
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.body.weight(.medium))
                .foregroundStyle(isAvailable ? dropColor : Color(.quaternaryLabel))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(fuel.shortName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isAvailable ? Color.primary : Color(.tertiaryLabel))
                Text(fuel.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isAvailable, let price = fuel.price {
                Text(FormattingUtils.formatPrice(price))
                    .font(.system(.body, design: .rounded, weight: .heavy))
                    .foregroundStyle(.primary)
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
        .background(isAvailable ? Color(.systemBackground) : Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
        )
        .opacity(isAvailable ? 1 : 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if isAvailable, let price = fuel.price {
            "\(fuel.name), \(FormattingUtils.formatPrice(price)) euros par litre"
        } else {
            "\(fuel.name), non disponible"
        }
    }
}
