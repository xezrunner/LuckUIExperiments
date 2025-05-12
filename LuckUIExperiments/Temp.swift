// LuckUIExperiments::Temp.swift - 17/04/2025

import SwiftUI

struct Temp: View {
    var body: some View {
        TabView {
            Tab("Test 1", systemImage: "gear") {
                List(0..<50, id: \.self) { x in Text(x.description) }
            }
            
            Tab("Test 2", systemImage: "gear") {
                List(0..<50, id: \.self) { x in Text(x.description) }
            }
        }
    }
}

#Preview {
    Temp()
}
