import AppKit
import SwiftUI

struct AirPortSheetBackground: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.25, green: 0.23, blue: 0.27),
          Color(red: 0.19, green: 0.17, blue: 0.21),
          Color(red: 0.14, green: 0.13, blue: 0.16),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      LinearGradient(
        colors: [
          Color.white.opacity(0.07),
          Color.clear,
          Color.black.opacity(0.16),
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
  var isExternallyFocused: Bool
  @FocusState private var isFocused: Bool

  func body(content: Content) -> some View {
    content
      .focused($isFocused)
      .padding(.horizontal, 7)
      .frame(height: 24)
      .background(
        LinearGradient(
          colors: [
            Color(red: 0.32, green: 0.30, blue: 0.33),
            Color(red: 0.25, green: 0.24, blue: 0.27),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .clipShape(RoundedRectangle(cornerRadius: 4))
      .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.34), lineWidth: 1))
      .overlay(
        RoundedRectangle(cornerRadius: 3)
          .stroke(Color.white.opacity(isEnabled ? 0.12 : 0.05), lineWidth: 1)
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
