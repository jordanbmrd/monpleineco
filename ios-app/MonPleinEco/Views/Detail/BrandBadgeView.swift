import SwiftUI

enum BrandLogo {
    /// Maps a brand string (from the API) to an asset name in Assets.xcassets,
    /// or nil if we don't have a logo for it.
    static func assetName(for brand: String?) -> String? {
        guard let raw = brand?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }

        let key = raw
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "fr"))
            .lowercased()

        if key.contains("total") { return "logo-total" }
        if key.contains("leclerc") { return "logo-leclerc" }
        if key.contains("intermarche") { return "logo-intermarche" }
        if key.contains("auchan") { return "logo-auchan" }
        if key.contains("carrefour") { return "logo-carrefour" }
        if key.contains("shell") { return "logo-shell" }
        if key.contains("esso") { return "logo-esso" }
        if key.contains("bp") { return "logo-bp" }
        if key.contains("super u") || key.contains("systeme u") || key.contains("hyper u") || key == "u" {
            return "logo-u"
        }
        return nil
    }
}

struct BrandBadgeView: View {
    let brand: String?
    var size: CGFloat = 28

    var body: some View {
        if let asset = BrandLogo.assetName(for: brand) {
            Image(asset)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .accessibilityLabel(brand ?? "")
        }
    }
}
