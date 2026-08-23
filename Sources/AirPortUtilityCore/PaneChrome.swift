import AppKit
import SwiftUI

struct AirPortSheetBackground: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ZStack {
      LinearGradient(
        colors: colorScheme == .dark
          ? [
            Color(red: 0.25, green: 0.23, blue: 0.27),
            Color(red: 0.19, green: 0.17, blue: 0.21),
            Color(red: 0.14, green: 0.13, blue: 0.16),
          ]
          : [
            Color(red: 0.98, green: 0.98, blue: 0.99),
            Color(red: 0.94, green: 0.94, blue: 0.96),
            Color(red: 0.90, green: 0.90, blue: 0.92),
          ],
        startPoint: .top,
        endPoint: .bottom
      )
      LinearGradient(
        colors: colorScheme == .dark
          ? [
            Color.white.opacity(0.07),
            Color.clear,
            Color.black.opacity(0.16),
          ]
          : [
            Color.white.opacity(0.5),
            Color.clear,
            Color.black.opacity(0.05),
          ],
        startPoint: .top,
        endPoint: .bottom
      )
    }
  }
}

extension View {
  func airPortField(isFocused: Bool = false) -> some View {
    modifier(AirPortFieldModifier(isExternallyFocused: isFocused))
  }
}

private struct AirPortFieldModifier: ViewModifier {
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.colorScheme) private var colorScheme
  var isExternallyFocused: Bool
  @FocusState private var isFocused: Bool

  func body(content: Content) -> some View {
    content
      .focused($isFocused)
      .padding(.horizontal, 7)
      .frame(height: 24)
      .background(
        LinearGradient(
          colors: colorScheme == .dark
            ? [
              Color(red: 0.32, green: 0.30, blue: 0.33),
              Color(red: 0.25, green: 0.24, blue: 0.27),
            ]
            : [
              Color(red: 0.99, green: 0.99, blue: 1.0),
              Color(red: 0.92, green: 0.92, blue: 0.94),
            ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .clipShape(RoundedRectangle(cornerRadius: 4))
      .overlay(
        RoundedRectangle(cornerRadius: 4)
          .stroke(Color.black.opacity(colorScheme == .dark ? 0.34 : 0.16), lineWidth: 1)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 3)
          .stroke(
            colorScheme == .dark
              ? Color.white.opacity(isEnabled ? 0.12 : 0.05)
              : Color.black.opacity(isEnabled ? 0.05 : 0.02),
            lineWidth: 1
          )
          .padding(1)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 3)
          .stroke(
            Color.accentColor.opacity(0.9),
            lineWidth: isExternallyFocused || isFocused ? 2 : 0)
          .padding(-1)
      )
      .opacity(isEnabled ? 1 : 0.58)
  }
}
