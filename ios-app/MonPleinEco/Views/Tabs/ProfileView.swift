import SwiftUI

struct ProfileView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    appHeader

                    settingsSection(title: "Général") {
                        settingsRow(icon: "fuelpump.fill", label: "Carburant par défaut", trailing: "SP95-E10")
                        Divider().padding(.leading, 48)
                        settingsRow(icon: "location.fill", label: "Localisation", trailing: "Automatique")
                        Divider().padding(.leading, 48)
                        settingsRow(icon: "globe", label: "Langue", trailing: "Français")
                        Divider().padding(.leading, 48)
                        notificationRow
                    }

                    settingsSection(title: "Support") {
                        settingsRow(icon: "star.fill", label: "Noter l'application", showChevron: true)
                        Divider().padding(.leading, 48)
                        settingsRow(icon: "square.and.arrow.up", label: "Partager", showChevron: true)
                        Divider().padding(.leading, 48)
                        Button {
                            showAbout = true
                        } label: {
                            settingsRow(icon: "info.circle.fill", label: "À propos", showChevron: true)
                        }
                        .buttonStyle(.plain)
                    }

                    versionInfo
                }
                .padding(.horizontal, Theme.Spacing.screenHorizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showAbout) {
                aboutSheet
            }
        }
    }

    // MARK: - App Header

    private var appHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.brandGradient)
                    .frame(width: 60, height: 60)
                Image(systemName: "fuelpump.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Mon Plein Éco")
                    .font(.title3.weight(.bold))
                Text("Trouvez le meilleur prix")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    // MARK: - Settings Section

    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
    }

    private func settingsRow(
        icon: String,
        label: String,
        trailing: String? = nil,
        showChevron: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(.brand)
                .frame(width: 28, height: 28)

            Text(label)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.vertical, 12)
    }

    private var notificationRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.body.weight(.medium))
                .foregroundStyle(.brand)
                .frame(width: 28, height: 28)

            Text("Notifications")
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            Toggle("", isOn: $notificationsEnabled)
                .tint(.brand)
                .labelsHidden()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Version

    private var versionInfo: some View {
        Text("Version 1.0.0")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    // MARK: - About Sheet

    private var aboutSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(.brandGradient)
                        .frame(width: 80, height: 80)
                    Image(systemName: "fuelpump.fill")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 6) {
                    Text("Mon Plein Éco")
                        .font(.title2.weight(.bold))
                    Text("Comparez les prix des carburants en France et trouvez la station la moins chère près de chez vous ou sur votre trajet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Text("Données fournies par le Ministère de l'Économie")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("À propos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { showAbout = false }
                }
            }
        }
    }
}
