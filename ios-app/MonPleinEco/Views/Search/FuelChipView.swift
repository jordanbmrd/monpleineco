import SwiftUI

struct FuelChipView: View {
    let fuel: FuelType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(fuel.label)
                .font(.footnote.weight(isSelected ? .bold : .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    isSelected
                    ? AnyShapeStyle(.brandGradient)
                    : AnyShapeStyle(Color(.tertiarySystemFill))
                )
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .shadow(
                    color: isSelected ? Color.brand.opacity(0.2) : .clear,
                    radius: isSelected ? 6 : 0,
                    y: isSelected ? 3 : 0
                )
        }
        .buttonStyle(CardPressStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel("\(fuel.label)\(isSelected ? ", sélectionné" : "")")
        .accessibilityHint("Appuyez pour sélectionner ce carburant")
    }
}
