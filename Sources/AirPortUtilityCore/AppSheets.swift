import SwiftUI

struct PasswordsSheet: View {
  @EnvironmentObject private var model: AirportAppModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Passwords")
        .font(.system(size: 13, weight: .semibold))
        .padding(.bottom, 13)

      VStack(alignment: .leading, spacing: 8) {
        passwordRow("Base Station Password:", value: baseStationPassword)
        if shouldShowDiskPassword {
          passwordRow("Disk Password:", value: diskPassword)
        }
      }
      .padding(.bottom, 20)

      HStack {
        Spacer()
        Button("OK") {
          dismiss()
        }
        .accessibilityIdentifier("passwords.ok")
        .keyboardShortcut(.defaultAction)
        .frame(width: 70)
      }
    }
    .padding(EdgeInsets(top: 18, leading: 20, bottom: 16, trailing: 20))
    .frame(width: 360, alignment: .leading)
  }

  private func passwordRow(_ label: String, value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(label)
        .font(.system(size: 13))
        .frame(width: 145, alignment: .trailing)
      Text(value.isEmpty ? "Not available" : value)
        .font(.system(size: 13))
        .textSelection(.enabled)
        .accessibilityIdentifier(
          label.localizedCaseInsensitiveContains("Disk") ? "passwords.disk.value"
            : "passwords.base.station.value")
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var baseStationPassword: String {
    let configuredPassword = model.baseStation.newAdminPassword
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if !configuredPassword.isEmpty {
      return configuredPassword
    }
    return model.connection.password.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var shouldShowDiskPassword: Bool {
    model.disks.secureSharedDisks == "disk-password"
  }

  private var diskPassword: String {
    model.disks.diskPassword.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

struct PreferencesSheet: View {
  @EnvironmentObject private var model: AirportAppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Preferences")
            .font(.largeTitle)
            .fontWeight(.semibold)
        }

        DashboardSection(title: "General", icon: "gearshape") {
          Toggle(
            "Show connection details in the Other Wi-Fi Devices menu",
            isOn: $model.showConnectionDetails
          )
          .toggleStyle(.checkbox)
          .accessibilityIdentifier("preferences.show.connection.details")
        }

        DashboardSection(title: "Health Notifications", icon: "bell") {
          notificationToggle(
            "Disk SMART status needs attention", keyPath: \.smartStatus,
            identifier: "preferences.notifications.smart")
          notificationToggle(
            "Time Capsule storage is low", keyPath: \.lowDiskSpace,
            identifier: "preferences.notifications.capacity")
          notificationToggle(
            "SMB file sharing becomes unavailable", keyPath: \.smbOutage,
            identifier: "preferences.notifications.smb")
          notificationToggle(
            "Time Machine backups become overdue or stale", keyPath: \.staleBackups,
            identifier: "preferences.notifications.backups")
          Text("macOS will ask for notification permission when you enable an alert.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func notificationToggle(
    _ title: String,
    keyPath: WritableKeyPath<HealthNotificationPreferences, Bool>,
    identifier: String
  ) -> some View {
    Toggle(
      title,
      isOn: Binding(
        get: { model.healthNotificationPreferences[keyPath: keyPath] },
        set: { model.updateHealthNotificationPreference(keyPath, enabled: $0) }))
      .toggleStyle(.checkbox)
      .font(.system(size: 13))
      .accessibilityIdentifier(identifier)
  }
}

