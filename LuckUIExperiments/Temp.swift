// LuckUIExperiments::Temp.swift - 17/04/2025

import SwiftUI

struct Temp: View {
    var body: some View {
        VStack {
            Capsule()
                .frame(maxWidth: 180, maxHeight: 60)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    Temp()
}
