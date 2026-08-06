//
//  DiagnosticsPane.swift
//  AirPortUtility
//
//  Created by Graham Barber on 06/08/2026.
//


import SwiftUI

struct DiagnosticsPane: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "stethoscope")
                .font(.system(size: 48))

            Text("Diagnostics")
                .font(.largeTitle)

            Text("Coming soon")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}