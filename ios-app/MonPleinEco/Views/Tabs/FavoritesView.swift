import SwiftUI

struct FavoritesView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.brand.opacity(0.08))
                        .frame(width: 100, height: 100)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(.brand.opacity(0.4))
                }

                VStack(spacing: 8) {
                    Text("Aucun favori")
                        .font(.title3.weight(.bold))

                    Text("Vos stations favorites apparaîtront ici.\nCette fonctionnalité arrive bientôt !")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Favoris")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
