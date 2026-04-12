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
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isAvailable ? dropColor.opacity(0.15) : Color(.quaternarySystemFill))
                    .frame(width: 40, height: 40)
                Image(systemName: "drop.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isAvailable ? dropColor : Color(.quaternaryLabel))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(fuel.shortName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isAvailable ? .primary : Color(.tertiaryLabel))
                Text(fuel.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isAvailable, let price = fuel.price {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(FormattingUtils.formatPrice(price))
                        .font(.system(.body, design: .rounded, weight: .heavy))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                    Text("€/L")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("Indisponible")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.quaternarySystemFill), in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .opacity(isAvailable ? 1 : 0.55)
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
