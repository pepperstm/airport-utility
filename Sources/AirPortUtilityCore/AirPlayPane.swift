import SwiftUI

struct AirPlayPane: View {
  @EnvironmentObject private var model: AirportAppModel

  var body: some View {
    DashboardSection(title: "AirPlay", icon: "airplayaudio") {
      VStack(alignment: .leading, spacing: 12) {
        Toggle("Enable AirPlay", isOn: $model.airPlay.enabled)
          .accessibilityIdentifier("airplay.enabled")
        PaneFieldRow("AirPlay Speaker Name") {
          AirPortTextField(
            text: $model.airPlay.speakerName,
            placeholder: "Speaker name",
            identifier: "airplay.speaker.name")
        }
        .disabled(!model.airPlay.enabled)
        PaneFieldRow("AirPlay Speaker Password") {
          AirPortSecureField(
            text: $model.airPlay.speakerPassword,
            placeholder: "Speaker password",
            identifier: "airplay.speaker.password")
            .frame(height: 24)
        }
        .disabled(!model.airPlay.enabled)
        PaneFieldRow("Verify Password") {
          AirPortSecureField(
            text: $model.airPlay.verifySpeakerPassword,
            placeholder: "Verify speaker password",
            identifier: "airplay.speaker.verify.password")
            .frame(height: 24)
        }
        .disabled(!model.airPlay.enabled)
        Toggle(
          "Remember this password in my keychain",
          isOn: Binding(
            get: { model.airPlay.rememberPassword },
            set: { model.updateRememberAirPlayPassword($0) })
        )
        .accessibilityIdentifier("airplay.remember.password")
        .disabled(!model.airPlay.enabled)
        Toggle("Enable AirPlay over WAN", isOn: $model.airPlay.overWAN)
          .accessibilityIdentifier("airplay.over.wan")
          .disabled(!model.airPlay.enabled)
      }
    }
  }
}
