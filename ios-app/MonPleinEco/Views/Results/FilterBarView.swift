import SwiftUI

struct FilterBarView: View {
    @Binding var sortBy: SortOption
    @Binding var selectedBrand: String
    let availableBrands: [String]

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortBy = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortBy == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                filterPill(icon: "arrow.up.arrow.down", text: sortBy.rawValue)
            }
            .sensoryFeedback(.selection, trigger: sortBy)

            if !availableBrands.isEmpty {
                Menu {
                    Button {
                        selectedBrand = ""
                    } label: {
                        HStack {
                            Text("Toutes les marques")
                            if selectedBrand.isEmpty {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Divider()
                    ForEach(availableBrands, id: \.self) { brand in
                        Button {
                            selectedBrand = brand
                        } label: {
                            HStack {
                                Text(brand)
                                if selectedBrand == brand {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    filterPill(
                        icon: "line.3.horizontal.decrease",
                        text: selectedBrand.isEmpty ? "Marque" : selectedBrand
                    )
                }
                .sensoryFeedback(.selection, trigger: selectedBrand)
            }
        }
    }

    private func filterPill(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(text)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill))
        .foregroundStyle(.primary)
        .clipShape(Capsule())
    }
}
