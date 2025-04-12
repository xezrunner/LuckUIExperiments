// LuckUIExperiments::LibraryTabView.swift - 12/04/2025

import SwiftUI

struct LibraryTabView: View {
    let array = [
        "Time",
        "Heaven Takes You Home",
        "Jacob's Note",
        "Moth to a Flame",
        "Mafia",
        "Frankenstein",
        "Don't Go Mad",
        "Paradise Again",
        "Lifetime",
        "Calling On",
        "Home",
        "It Gets Better",
        "Redlight",
        "Can U Feel It",
        "19:30",
        "Another Minute",
        "For You"
    ]
    
    @Environment(\.luckSearchText) var searchText
    
    var body: some View {
        List {
            ForEach(
                array.filter { $0.lowercased().starts(with: searchText.lowercased()) },
                id: \.self)
            { it in
                Text(it)
            }
        }
    }
}
