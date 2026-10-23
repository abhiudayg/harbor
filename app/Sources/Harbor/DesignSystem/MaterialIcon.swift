import SwiftUI

struct MaterialIcon: View {
    let name: String
    let size: CGFloat

    init(_ name: String, size: CGFloat = 16) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Text(name)
            .font(.custom("Material Symbols Outlined", size: size))
            .fixedSize()
    }
}
