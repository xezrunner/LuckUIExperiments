// LuckUIExperiments::Temp.swift - 17/04/2025

import SwiftUI

struct Temp_Button: View, Identifiable {
    let id: Int
    
    var animNS: Namespace.ID
    
    @Binding var flags: [Int:Bool]
    @Binding var expanded: Bool
    
    var body: some View {
        ZStack {
            Text("Hi!")
        }
        .frame(maxWidth: 100, maxHeight: 50)
        .padding(4)
        .border(.red)
        .background() {
            ZStack {
                if flags[id] ?? false {
                    Capsule()
                        .fill(.accent)
                        .padding(.horizontal, 4)
                        .matchedGeometryEffect(id: "button_capsule", in: animNS)
                }
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            withAnimation {
                flags.forEach { (key: Int, value: Bool) in
                    flags[key] = false
                }
                
                if flags[id] != nil {
                    flags[id] = true
                }
                
                expanded = false
            }
        }
        .onAppear() {
            if flags[id] == nil {
                flags[id] = false
            }
        }
    }
}

struct Temp: View {
    @Namespace var animNS
    
    @State var flags: [Int: Bool] = [:]
    
    @State var expanded = false
    
    var body: some View {
        if expanded {
            HStack {
                Temp_Button(id: 0, animNS: animNS, flags: $flags, expanded: $expanded)
                Temp_Button(id: 1, animNS: animNS, flags: $flags, expanded: $expanded)
                Temp_Button(id: 2, animNS: animNS, flags: $flags, expanded: $expanded)
                Temp_Button(id: 3, animNS: animNS, flags: $flags, expanded: $expanded)
            }
        } else {
            Button("Expand") { expanded = true }
        }
    }
}

#Preview {
    Temp()
}
