import SwiftUI
import MapKit

@Observable
final class AddressCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var suggestions: [MKLocalSearchCompletion] = []
    var isSearching = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.6, longitude: 2.2),
            latitudinalMeters: 1_200_000,
            longitudinalMeters: 1_200_000
        )
    }

    func search(_ query: String) {
        guard query.count >= 3 else {
            suggestions = []
            return
        }
        isSearching = true
        completer.queryFragment = query
    }

    func clear() {
        suggestions = []
    }

    // MARK: - MKLocalSearchCompleterDelegate

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = Array(completer.results.prefix(5))
        isSearching = false
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        isSearching = false
    }
}

struct AddressSearchField: View {
    let placeholder: String
    @Binding var text: String
    var trailingAction: (() -> Void)? = nil
    var trailingIcon: String? = nil
    var trailingLoading: Bool = false

    @State private var completer = AddressCompleter()
    @State private var isFocused = false
    @State private var isResolved = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                TextField(placeholder, text: $text)
                    .font(.subheadline)
                    .focused($fieldFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .onChange(of: text) { _, newValue in
                        isResolved = false
                        completer.search(newValue)
                    }
                    .onChange(of: fieldFocused) { _, focused in
                        isFocused = focused
                        if !focused {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                completer.clear()
                            }
                        }
                    }

                if isResolved {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.brand)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityLabel("Adresse validée")
                }

                if let trailingAction, let trailingIcon {
                    Button(action: trailingAction) {
                        if trailingLoading {
                            ProgressView()
                                .scaleEffect(0.75)
                        } else {
                            Image(systemName: trailingIcon)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.brand)
                        }
                    }
                    .disabled(trailingLoading)
                    .frame(width: 32, height: 32)
                    .background(Color.brand.opacity(0.1))
                    .clipShape(Circle())
                    .accessibilityLabel("Utiliser ma position")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                    .stroke(fieldFocused ? Color.brand.opacity(0.6) : Color(.separator).opacity(0.3), lineWidth: fieldFocused ? 2 : 1)
            )

            if isFocused && !completer.suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(completer.suggestions, id: \.self) { suggestion in
                        Button {
                            let label = [suggestion.title, suggestion.subtitle]
                                .filter { !$0.isEmpty }
                                .joined(separator: ", ")
                            text = label
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                isResolved = true
                            }
                            completer.clear()
                            fieldFocused = false
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(.brand)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(suggestion.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if suggestion != completer.suggestions.last {
                            Divider().padding(.leading, 40)
                        }
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.suggestion, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
