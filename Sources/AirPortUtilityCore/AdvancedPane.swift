import SwiftUI

private enum AdvancedPaneSection: String, CaseIterable, Identifiable {
  case logging = "Logging & Statistics"
  case pppDialIn = "PPP Dial-in"
  case accessControl = "Access Control"

  var id: String { rawValue }
}

struct AdvancedPane: View {
  @EnvironmentObject private var model: AirportAppModel
  @State private var selectedSection: AdvancedPaneSection = .logging

  private var visibleSections: [AdvancedPaneSection] {
    AdvancedPaneSection.allCases.filter { section in
      switch section {
      case .logging:
        model.showsLoggingControls
      case .pppDialIn:
        model.showsPPPDialInControls
      case .accessControl:
        model.showsAccessControlControls
      }
    }
  }

  var body: some View {
    DashboardSection(title: "Advanced", icon: "gearshape.2") {
      VStack(alignment: .leading, spacing: 12) {
        if visibleSections.count > 1 {
          Picker("", selection: $selectedSection) {
            ForEach(visibleSections) { section in
              Text(section.rawValue).tag(section)
            }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
          .accessibilityIdentifier("advanced.section")
        }

        switch selectedSection {
        case .logging:
          if model.showsLoggingControls {
            loggingSettings
          }
        case .pppDialIn:
          if model.showsPPPDialInControls {
            pppDialInSettings
          }
        case .accessControl:
          if model.showsAccessControlControls {
            accessControlSettings
          }
        }
      }
    }
    .onAppear(perform: reconcileSelectedSection)
    .onChange(of: visibleSections) { _ in reconcileSelectedSection() }
  }

  @ViewBuilder
  private var loggingSettings: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("This AirPort wireless device supports log messages that may help diagnose a problem.")
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      PaneFieldRow("Syslog Destination Address") {
        AirPortTextField(
          text: $model.advanced.syslogDestinationAddress,
          identifier: "advanced.logging.syslog.destination")
      }

      PaneFieldRow("Syslog Level") {
        Picker("", selection: $model.advanced.syslogLevel) {
          ForEach(SyslogLevelOption.allCases) { option in
            Text(option.label).tag(option.level)
          }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .accessibilityIdentifier("advanced.logging.syslog.level")
      }

      Text(
        "Simple Network Management Protocol (SNMP) allows you to query this device for statistics, including the number of wireless clients."
      )
      .font(.callout)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)

      Toggle("Allow SNMP", isOn: $model.advanced.allowSNMP)
        .accessibilityIdentifier("advanced.logging.allow.snmp")
        .onChange(of: model.advanced.allowSNMP) { enabled in
          if !enabled {
            model.advanced.allowSNMPOverWAN = false
          }
        }

      Toggle("Allow SNMP over WAN", isOn: $model.advanced.allowSNMPOverWAN)
        .accessibilityIdentifier("advanced.logging.allow.snmp.over.wan")
        .disabled(!model.advanced.allowSNMP)
        .padding(.leading, 20)
    }
  }

  @ViewBuilder
  private var pppDialInSettings: some View {
    VStack(alignment: .leading, spacing: 12) {
      Toggle("PPP Dial-in", isOn: $model.advanced.pppDialInEnabled)
        .accessibilityIdentifier("advanced.ppp.dial.in.enabled")

      Group {
        PaneFieldRow("Account Name") {
          AirPortTextField(
            text: $model.advanced.pppDialInAccount,
            identifier: "advanced.ppp.dial.in.account")
        }
        PaneFieldRow("Password") {
          AirPortSecureField(
            text: $model.advanced.pppDialInPassword,
            identifier: "advanced.ppp.dial.in.password")
            .frame(height: 24)
        }
        PaneFieldRow("Verify Password") {
          AirPortSecureField(
            text: $model.advanced.pppDialInVerifyPassword,
            identifier: "advanced.ppp.dial.in.verify.password")
            .frame(height: 24)
        }
        PaneFieldRow("Answer on ring") {
          TextField("", value: $model.advanced.pppDialInAnswerOnRing, format: .number)
            .textFieldStyle(.plain)
            .airPortField()
            .accessibilityIdentifier("advanced.ppp.dial.in.answer.on.ring")
        }
        PaneFieldRow("Idle Disconnect After") {
          Picker("", selection: $model.advanced.pppDialInIdleSeconds) {
            ForEach(ModemIdleOption.allCases) { option in
              Text(option.label).tag(option.seconds)
            }
          }
          .pickerStyle(.menu)
          .labelsHidden()
          .accessibilityIdentifier("advanced.ppp.dial.in.idle.disconnect")
        }
        PaneFieldRow("Maximum Connect Time") {
          Picker("", selection: $model.advanced.pppDialInMaximumConnectSeconds) {
            ForEach(PPPDialInMaximumConnectOption.allCases) { option in
              Text(option.label).tag(option.seconds)
            }
          }
          .pickerStyle(.menu)
          .labelsHidden()
          .accessibilityIdentifier("advanced.ppp.dial.in.maximum.connect")
        }
      }
      .disabled(!model.advanced.pppDialInEnabled)
    }
  }

  @ViewBuilder
  private var accessControlSettings: some View {
    VStack(alignment: .leading, spacing: 12) {
      PaneFieldRow("Access Control") {
        Picker("", selection: $model.legacyDeviceOptions.accessControl.mode) {
          Text("Not enabled").tag("not-enabled")
          Text("Local").tag("local")
          Text("RADIUS").tag("radius")
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .accessibilityIdentifier("advanced.access.control.mode")
      }

      switch model.legacyDeviceOptions.accessControl.mode {
      case "local":
        localAccessControlSettings
      case "radius":
        radiusAccessControlSettings
      default:
        Text("All wireless clients are allowed to join this network.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.top, 12)
      }
    }
  }

  @ViewBuilder
  private var localAccessControlSettings: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Allow only the wireless clients listed below.")
        .font(.callout)
        .foregroundStyle(.secondary)

      ScrollView {
        VStack(spacing: 10) {
          ForEach($model.legacyDeviceOptions.accessControl.entries) { $entry in
            VStack(spacing: 8) {
              HStack(spacing: 8) {
                Text("AirPort ID")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .frame(width: 90, alignment: .trailing)
                AirPortTextField(
                  text: $entry.macAddress,
                  placeholder: "00:11:22:33:44:55",
                  identifier: "advanced.access.control.entry.\(entry.id).mac")
                Button {
                  model.legacyDeviceOptions.accessControl.entries.removeAll {
                    $0.id == entry.id
                  }
                } label: {
                  Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove access-control entry")
              }
              HStack(spacing: 8) {
                Text("Description")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .frame(width: 90, alignment: .trailing)
                AirPortTextField(
                  text: $entry.description,
                  identifier: "advanced.access.control.entry.\(entry.id).description")
                Spacer().frame(width: 18)
              }
            }
            .padding(8)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
          }
        }
      }
      .frame(maxHeight: 260)

      Button("Add Client") {
        model.legacyDeviceOptions.accessControl.entries.append(AccessControlEntry())
      }
      .accessibilityIdentifier("advanced.access.control.add.client")
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }

  @ViewBuilder
  private var radiusAccessControlSettings: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        PaneFieldRow("RADIUS Type") {
          Picker("", selection: $model.legacyDeviceOptions.accessControl.radiusType) {
            Text("Default").tag("default")
            Text("Alternate").tag("alternate")
          }
          .pickerStyle(.menu)
          .labelsHidden()
          .accessibilityIdentifier("advanced.access.control.radius.type")
        }
        PaneFieldRow("Primary Server") {
          AirPortTextField(
            text: $model.legacyDeviceOptions.accessControl.primaryAddress,
            identifier: "advanced.access.control.radius.primary.address")
        }
        PaneFieldRow("Shared Secret") {
          AirPortSecureField(
            text: $model.legacyDeviceOptions.accessControl.primarySecret,
            identifier: "advanced.access.control.radius.primary.secret")
            .frame(height: 24)
        }
        PaneFieldRow("Verify Secret") {
          AirPortSecureField(
            text: $model.legacyDeviceOptions.accessControl.primaryVerifySecret,
            identifier: "advanced.access.control.radius.primary.verify.secret")
            .frame(height: 24)
        }
        PaneFieldRow("Primary Port") {
          TextField(
            "", value: $model.legacyDeviceOptions.accessControl.primaryPort, format: .number
          )
          .textFieldStyle(.plain)
          .airPortField()
          .accessibilityIdentifier("advanced.access.control.radius.primary.port")
        }
        PaneFieldRow("Secondary Server") {
          AirPortTextField(
            text: $model.legacyDeviceOptions.accessControl.secondaryAddress,
            identifier: "advanced.access.control.radius.secondary.address")
        }
        PaneFieldRow("Shared Secret") {
          AirPortSecureField(
            text: $model.legacyDeviceOptions.accessControl.secondarySecret,
            identifier: "advanced.access.control.radius.secondary.secret")
            .frame(height: 24)
        }
        PaneFieldRow("Verify Secret") {
          AirPortSecureField(
            text: $model.legacyDeviceOptions.accessControl.secondaryVerifySecret,
            identifier: "advanced.access.control.radius.secondary.verify.secret")
            .frame(height: 24)
        }
        PaneFieldRow("Secondary Port") {
          TextField(
            "", value: $model.legacyDeviceOptions.accessControl.secondaryPort, format: .number
          )
          .textFieldStyle(.plain)
          .airPortField()
          .accessibilityIdentifier("advanced.access.control.radius.secondary.port")
        }
      }
    }
    .frame(maxHeight: 340)
  }

  private func reconcileSelectedSection() {
    guard !visibleSections.contains(selectedSection), let first = visibleSections.first else {
      return
    }
    selectedSection = first
  }
}
