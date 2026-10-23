import SwiftUI

struct NatureBackground: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: 0xF6F8F6), Color(hex: 0xEDF2EF), Color(hex: 0xE2E8E4)],
                center: .topLeading,
                startRadius: 0,
                endRadius: 1400
            )
            Circle()
                .fill(Color(hex: 0xDBE8E1, opacity: 0.7))
                .frame(width: 580, height: 580)
                .blur(radius: 110)
                .offset(x: -380, y: -320)
            Circle()
                .fill(Color(hex: 0xE3ECE7, opacity: 0.75))
                .frame(width: 600, height: 600)
                .blur(radius: 120)
                .offset(x: 120, y: 360)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func glassPanel() -> some View {
        background(.ultraThinMaterial)
            .background(Color.white.opacity(0.62))
    }

    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.white.opacity(0.9)))
            .shadow(color: Color(hex: 0x1E473D, opacity: 0.04), radius: 16, y: 8)
    }
}
