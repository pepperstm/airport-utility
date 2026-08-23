import SwiftUI

struct BaseStationPane: View {
  @EnvironmentObject private var model: AirportAppModel

  var body: some View {
    DashboardSection(title: "Base Station", icon: "wifi.router") {
      VStack(alignment: .leading, spacing: 12) {
        PaneFieldRow("Base Station Name") {
          AirPortTextField(
            text: $model.baseStation.name,
            placeholder: "Name",
            selectOnAppear: true,
            identifier: "base.station.name")
        }
        PaneFieldRow("Base Station Password") {
          AirPortSecureField(
            text: $model.baseStation.newAdminPassword,
            placeholder: "New password",
            identifier: "base.station.admin.password")
            .frame(height: 24)
        }
        PaneFieldRow("Verify Password") {
          AirPortSecureField(
            text: $model.baseStation.verifyAdminPassword,
            placeholder: "Verify password",
            identifier: "base.station.admin.verify.password")
            .frame(height: 24)
        }
        Toggle(
          "Remember this password in my keychain",
          isOn: Binding(
            get: { model.rememberConnectionPassword },
            set: { model.updateRememberConnectionPassword($0) })
        )
        .accessibilityIdentifier("base.station.remember.password")
        Toggle(
          "Allow setup over Ethernet WAN port",
          isOn: $model.baseStation.allowSetupOverWAN
        )
        .accessibilityIdentifier("base.station.allow.setup.over.wan")
        if model.capabilities.supportsBaseStationMetadata {
          PaneFieldRow("Contact") {
            AirPortTextField(
              text: $model.legacyDeviceOptions.baseStation.contact,
              identifier: "base.station.contact")
          }
          PaneFieldRow("Location") {
            AirPortTextField(
              text: $model.legacyDeviceOptions.baseStation.location,
              identifier: "base.station.location")
          }
        }
        Toggle(
          "Set time automatically",
          isOn: $model.legacyDeviceOptions.baseStation.setTimeAutomatically
        )
        .accessibilityIdentifier("base.station.set.time.automatically")
        PaneFieldRow("Time Server") {
          AirPortTextField(
            text: $model.legacyDeviceOptions.baseStation.timeServer,
            placeholder: "time.apple.com",
            identifier: "base.station.time.server")
        }
        .disabled(!model.legacyDeviceOptions.baseStation.setTimeAutomatically)
      }
    }
  }
}
