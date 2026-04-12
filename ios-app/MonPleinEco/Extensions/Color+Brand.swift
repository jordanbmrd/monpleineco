import SwiftUI

// MARK: - Brand Colors

extension Color {
    static let brand = Color(red: 22/255, green: 163/255, blue: 74/255)
    static let brandMid = Color(red: 34/255, green: 197/255, blue: 94/255)
    static let brandTeal = Color(red: 13/255, green: 148/255, blue: 136/255)
    static let brandLight = Color(red: 220/255, green: 252/255, blue: 231/255)

    static let podiumGold = Color(red: 245/255, green: 158/255, blue: 11/255)
    static let podiumSilver = Color(red: 148/255, green: 163/255, blue: 184/255)
    static let podiumBronze = Color(red: 217/255, green: 119/255, blue: 6/255)

    /// Card background that provides visible elevation in dark mode.
    /// Light mode: white. Dark mode: slightly lighter than systemBackground.
    static let elevatedCard = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.16, alpha: 1)   // lighter than systemBackground (0.11)
            : .systemBackground                  // white
    })

    /// Subtle border that stays visible in dark mode.
    static let cardBorder = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.10)
            : UIColor(white: 0, alpha: 0.06)
    })
}

extension ShapeStyle where Self == Color {
    static var brand: Color { Color.brand }
}

extension ShapeStyle where Self == LinearGradient {
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [.brand, .brandTeal],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Theme

enum Theme {
    enum Radius {
        static let card: CGFloat = 16
        static let heroCard: CGFloat = 20
        static let field: CGFloat = 14
        static let button: CGFloat = 16
        static let suggestion: CGFloat = 14
        static let annotation: CGFloat = 12
        static let searchBar: CGFloat = 24
        static let carouselCard: CGFloat = 16
    }

    enum AddressSearch {
        /// Nombre max de propositions d’adresse (Accueil + page Trajet).
        static let maxSuggestions = 4
    }

    enum Spacing {
        static let cardPadding: CGFloat = 14
        static let heroCardPadding: CGFloat = 18
        static let sectionSpacing: CGFloat = 20
        static let sheetHorizontal: CGFloat = 20
        static let screenHorizontal: CGFloat = 16
        static let chipH: CGFloat = 14
        static let chipV: CGFloat = 8
        static let carouselCardWidth: CGFloat = 180
        static let carouselCardHeight: CGFloat = 200
    }

    enum Shadow {
        static func card(_ isTop: Bool = false) -> (color: Color, radius: CGFloat, y: CGFloat) {
            isTop
            ? (Color.brand.opacity(0.12), 12, 4)
            : (Color.black.opacity(0.06), 8, 3)
        }

        static let hero = (color: Color.brand.opacity(0.25), radius: CGFloat(16), y: CGFloat(6))
        static let annotation = (color: Color.black.opacity(0.12), radius: CGFloat(6), y: CGFloat(3))
        static let searchBar = (color: Color.black.opacity(0.08), radius: CGFloat(12), y: CGFloat(4))
        static let floatingCard = (color: Color.black.opacity(0.1), radius: CGFloat(10), y: CGFloat(4))
    }
}

// MARK: - Shared View Modifiers

struct SectionLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GradientButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isEnabled
                ? AnyShapeStyle(.brandGradient)
                : AnyShapeStyle(Color(.systemGray4))
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            .shadow(
                color: isEnabled ? Color.brand.opacity(configuration.isPressed ? 0.1 : 0.25) : .clear,
                radius: configuration.isPressed ? 4 : 12,
                y: configuration.isPressed ? 2 : 6
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.25), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: phase * geo.size.width)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

struct FormSectionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.cardPadding)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

extension View {
    func sectionLabel() -> some View {
        modifier(SectionLabelStyle())
    }

    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    func formSection() -> some View {
        modifier(FormSectionStyle())
    }
}

// MARK: - Shapes

struct AnnotationPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - 5, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX + 5, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
