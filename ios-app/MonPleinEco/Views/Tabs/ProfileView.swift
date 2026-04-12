import SwiftUI

struct ProfileView: View {
    @AppStorage("defaultFuelRawValue") private var defaultFuelRawValue = FuelType.sp95E10.rawValue
    @AppStorage("tankSize") private var tankSize = 50
    @State private var showAbout = false
    @State private var showFuelPicker = false
    @State private var showTankPicker = false
    @State private var showTerms = false
    @State private var showPrivacy = false

    private var defaultFuel: FuelType {
        FuelType(rawValue: defaultFuelRawValue) ?? .sp95E10
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    appHeader

                    settingsSection(title: "Général") {
                        Button { showFuelPicker = true } label: {
                            settingsRow(
                                icon: "fuelpump.fill",
                                label: "Carburant par défaut",
                                trailing: defaultFuel.label,
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 48)
                        Button { showTankPicker = true } label: {
                            settingsRow(
                                icon: "drop.fill",
                                label: "Taille du réservoir",
                                trailing: "\(tankSize) L",
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 48)
                        settingsRow(icon: "location.fill", label: "Localisation", trailing: "Automatique")
                        Divider().padding(.leading, 48)
                        settingsRow(icon: "globe", label: "Langue", trailing: "Français")
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
            .sheet(isPresented: $showFuelPicker) {
                fuelPickerSheet
            }
            .sheet(isPresented: $showTankPicker) {
                TankPickerSheet(isPresented: $showTankPicker)
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

    // MARK: - Version

    private var versionInfo: some View {
        Text("Version 1.0.0")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    // MARK: - Fuel Picker Sheet

    private var fuelPickerSheet: some View {
        FuelPickerSheet(isPresented: $showFuelPicker)
    }

    // MARK: - About Sheet

    private var aboutSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 16) {
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
                            Text("Version \(appVersion)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("Comparez les prix des carburants en France et trouvez la station la moins chère près de chez vous ou sur votre trajet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 24)

                    VStack(spacing: 0) {
                        aboutLink(
                            icon: "building.columns.fill",
                            title: "Source des données",
                            subtitle: "Ministère de l'Économie — données ouvertes prix-carburants.gouv.fr"
                        )
                        Divider().padding(.leading, 52)
                        aboutLink(
                            icon: "clock.fill",
                            title: "Fréquence de mise à jour",
                            subtitle: "Les prix sont mis à jour quotidiennement par les stations-service."
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

                    aboutLegalSection

                    VStack(spacing: 6) {
                        Text("Fait avec ❤️ en France")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("© \(Calendar.current.component(.year, from: Date())) Mon Plein Éco")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, Theme.Spacing.screenHorizontal)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("À propos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { showAbout = false }
                }
            }
        }
    }

    private func aboutLink(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(.brand)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
    }

    private var aboutLegalSection: some View {
        VStack(spacing: 0) {
            Button { showTerms = true } label: {
                settingsRow(icon: "doc.text.fill", label: "Conditions d'utilisation", showChevron: true)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showTerms) { termsSheet }

            Divider().padding(.leading, 52)

            Button { showPrivacy = true } label: {
                settingsRow(icon: "lock.shield.fill", label: "Politique de confidentialité", showChevron: true)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPrivacy) { privacySheet }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    // MARK: - Terms of Use

    private var termsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    legalBlock(title: "1. Objet") {
                        "Mon Plein Éco est une application gratuite qui permet de comparer les prix des carburants en France à partir des données ouvertes publiées par le Ministère de l'Économie."
                    }
                    legalBlock(title: "2. Accès au service") {
                        "L'application est accessible gratuitement. L'éditeur se réserve le droit de modifier, suspendre ou interrompre tout ou partie du service à tout moment, sans préavis ni indemnité."
                    }
                    legalBlock(title: "3. Données affichées") {
                        "Les prix des carburants sont fournis par les stations-service et transmis via l'API du Ministère de l'Économie (prix-carburants.gouv.fr). Ils sont mis à jour quotidiennement. Mon Plein Éco ne garantit pas l'exactitude, l'exhaustivité ou l'actualité des prix affichés."
                    }
                    legalBlock(title: "4. Responsabilité") {
                        "L'application est fournie « en l'état ». L'éditeur ne saurait être tenu responsable de tout dommage direct ou indirect résultant de l'utilisation de l'application, notamment des décisions prises sur la base des prix affichés."
                    }
                    legalBlock(title: "5. Propriété intellectuelle") {
                        "L'ensemble des éléments graphiques, textuels et logiciels composant l'application sont protégés par le droit de la propriété intellectuelle. Toute reproduction, même partielle, est interdite sans autorisation préalable."
                    }
                    legalBlock(title: "6. Droit applicable") {
                        "Les présentes conditions sont régies par le droit français. Tout litige sera soumis aux tribunaux compétents de Paris."
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenHorizontal)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Conditions d'utilisation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { showTerms = false }
                }
            }
        }
    }

    // MARK: - Privacy Policy

    private var privacySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    legalBlock(title: "1. Données collectées") {
                        "Mon Plein Éco ne collecte aucune donnée personnelle. Aucun compte utilisateur n'est requis. L'application n'utilise aucun outil de suivi analytique ou publicitaire."
                    }
                    legalBlock(title: "2. Localisation") {
                        "L'application peut demander l'accès à votre position géographique pour afficher les stations à proximité. Cette donnée est traitée uniquement sur votre appareil et n'est jamais transmise à un serveur tiers."
                    }
                    legalBlock(title: "3. Stockage local") {
                        "Vos préférences (carburant par défaut, stations favorites, historique de recherche) sont stockées localement sur votre appareil via les mécanismes natifs d'iOS. Elles ne sont ni transmises ni sauvegardées en ligne."
                    }
                    legalBlock(title: "4. Communications réseau") {
                        "L'application communique uniquement avec l'API publique du Ministère de l'Économie pour récupérer les prix des carburants et avec les services Apple Maps pour le géocodage et le calcul d'itinéraires. Aucune donnée personnelle n'est transmise lors de ces requêtes."
                    }
                    legalBlock(title: "5. Cookies et traceurs") {
                        "L'application n'utilise aucun cookie, traceur ou identifiant publicitaire."
                    }
                    legalBlock(title: "6. Droits de l'utilisateur") {
                        "Conformément au RGPD, vous disposez d'un droit d'accès, de rectification et de suppression de vos données. Étant donné qu'aucune donnée personnelle n'est collectée, ces droits s'exercent directement sur votre appareil (suppression de l'application et de ses données)."
                    }
                    legalBlock(title: "7. Contact") {
                        "Pour toute question relative à cette politique de confidentialité, vous pouvez nous contacter par e-mail à l'adresse indiquée sur la fiche App Store."
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenHorizontal)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Politique de confidentialité")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { showPrivacy = false }
                }
            }
        }
    }

    private func legalBlock(title: String, content: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.bold))
            Text(content())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Fuel Picker (extracted to own view so @AppStorage works in sheets)

private struct FuelPickerSheet: View {
    @Binding var isPresented: Bool
    @AppStorage("defaultFuelRawValue") private var selectedRawValue = FuelType.sp95E10.rawValue

    var body: some View {
        NavigationStack {
            List(FuelType.displayOrder) { fuel in
                HStack(spacing: 12) {
                    Circle()
                        .fill(fuel.dropColor)
                        .frame(width: 10, height: 10)
                    Text(fuel.label)
                        .font(.body)
                    Spacer()
                    if selectedRawValue == fuel.rawValue {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.brand)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedRawValue = fuel.rawValue
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isPresented = false
                    }
                }
                .listRowBackground(selectedRawValue == fuel.rawValue ? Color.brand.opacity(0.06) : Color.clear)
            }
            .navigationTitle("Carburant par défaut")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { isPresented = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Tank Picker

private struct TankPickerSheet: View {
    @Binding var isPresented: Bool
    @AppStorage("tankSize") private var tankSize = 50
    @State private var draft: Double = 50

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 10)
                        .frame(width: 150, height: 150)

                    Circle()
                        .trim(from: 0, to: min(draft / 100, 1))
                        .stroke(.brandGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: draft)

                    VStack(spacing: 2) {
                        Text("\(Int(draft))")
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("litres")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 8) {
                    Slider(value: $draft, in: 20...120, step: 5)
                        .tint(.brand)
                        .sensoryFeedback(.selection, trigger: Int(draft))

                    HStack {
                        Text("20 L")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("120 L")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("Taille du réservoir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") {
                        tankSize = Int(draft)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                draft = Double(tankSize)
            }
        }
        .presentationDetents([.medium])
    }
}
