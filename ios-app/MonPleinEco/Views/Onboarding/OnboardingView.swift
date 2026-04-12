import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompleted = false
    @AppStorage("defaultFuelRawValue") private var defaultFuelRawValue = FuelType.sp95E10.rawValue
    @AppStorage("tankSize") private var tankSize = 50

    @State private var currentPage = 0
    @State private var selectedFuel: FuelType = .sp95E10
    @State private var tankSizeDraft: Double = 50
    @State private var appeared = false

    private let totalPages = 4

    var body: some View {
        ZStack {
            backgroundGradient
            
            VStack(spacing: 0) {
                Spacer(minLength: 40)

                // Content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    featuresPage.tag(1)
                    fuelPage.tag(2)
                    tankPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentPage)

                Spacer(minLength: 20)

                // Page indicator + button
                bottomBar
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                appeared = true
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            Color(.systemBackground)
            
            LinearGradient(
                colors: [
                    Color.brand.opacity(0.06),
                    Color.brandTeal.opacity(0.03),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative blurred circles
            Circle()
                .fill(Color.brand.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -100, y: -200)

            Circle()
                .fill(Color.brandTeal.opacity(0.06))
                .frame(width: 250, height: 250)
                .blur(radius: 60)
                .offset(x: 120, y: 100)
        }
        .ignoresSafeArea()
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.brandGradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.brand.opacity(0.3), radius: 30, y: 10)

                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 14) {
                Text("Mon Plein Éco")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Text("Trouvez le carburant le moins cher\nprès de chez vous ou sur votre trajet.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 2: Features

    private var featuresPage: some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(spacing: 8) {
                Text("Comment ça marche ?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("Trois fonctionnalités essentielles")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 20) {
                featureRow(
                    icon: "location.magnifyingglass",
                    color: .brand,
                    title: "Recherche locale",
                    subtitle: "Comparez les prix autour d'une adresse ou de votre position"
                )
                featureRow(
                    icon: "road.lanes",
                    color: .brandTeal,
                    title: "Mode trajet",
                    subtitle: "Trouvez les stations les moins chères sur votre itinéraire"
                )
                featureRow(
                    icon: "heart.fill",
                    color: .podiumGold,
                    title: "Favoris",
                    subtitle: "Enregistrez vos stations préférées et suivez leurs prix"
                )
            }
            .padding(.horizontal, 8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: color.opacity(0.3), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Page 3: Fuel Selection

    private var fuelPage: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 8) {
                Text("Votre carburant")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("Sélectionnez celui que vous utilisez")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                ForEach(FuelType.displayOrder) { fuel in
                    fuelOption(fuel)
                }
            }
            .padding(.horizontal, 8)

            Text("Modifiable à tout moment dans le profil")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func fuelOption(_ fuel: FuelType) -> some View {
        let isSelected = selectedFuel == fuel
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedFuel = fuel
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(fuel.dropColor.opacity(isSelected ? 1 : 0.15))
                        .frame(width: 38, height: 38)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.black))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Circle()
                            .fill(fuel.dropColor)
                            .frame(width: 12, height: 12)
                    }
                }

                Text(fuel.label)
                    .font(.body.weight(isSelected ? .bold : .medium))
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.brand)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Color.brand.opacity(0.08) : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.brand : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    // MARK: - Page 4: Tank Size

    private var tankPage: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("Votre réservoir")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("Pour estimer le coût d'un plein")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 10)
                        .frame(width: 160, height: 160)

                    Circle()
                        .trim(from: 0, to: min(tankSizeDraft / 100, 1))
                        .stroke(.brandGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: tankSizeDraft)

                    VStack(spacing: 2) {
                        Text("\(Int(tankSizeDraft))")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("litres")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Slider(value: $tankSizeDraft, in: 20...120, step: 5)
                    .tint(.brand)
                    .padding(.horizontal, 24)
                    .sensoryFeedback(.selection, trigger: Int(tankSizeDraft))

                HStack {
                    Text("20 L")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("120 L")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 28)
            }
            .padding(.horizontal, 8)

            Text("Modifiable à tout moment dans le profil")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 20) {
            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { page in
                    Capsule()
                        .fill(page == currentPage ? Color.brand : Color(.systemGray4))
                        .frame(width: page == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                }
            }

            // CTA button
            Button {
                if currentPage < totalPages - 1 {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        currentPage += 1
                    }
                } else {
                    completeOnboarding()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(currentPage == totalPages - 1 ? "C'est parti !" : "Continuer")
                        .font(.body.weight(.bold))
                    if currentPage == totalPages - 1 {
                        Image(systemName: "arrow.right")
                            .font(.body.weight(.bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(.brandGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.brand.opacity(0.3), radius: 12, y: 6)
            }

            if currentPage < totalPages - 1 {
                Button {
                    completeOnboarding()
                } label: {
                    Text("Passer")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private func completeOnboarding() {
        defaultFuelRawValue = selectedFuel.rawValue
        tankSize = Int(tankSizeDraft)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            hasCompleted = true
        }
    }
}
