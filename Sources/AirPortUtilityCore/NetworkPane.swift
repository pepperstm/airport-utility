import AppKit
import SwiftUI

struct NetworkPane: View {
  @EnvironmentObject private var model: AirportAppModel
  @State private var showOptions = false

  var body: some View {
    DashboardSection(title: "Network", icon: "network") {
      VStack(alignment: .leading, spacing: 12) {
        PaneFieldRow("Router Mode") {
          Picker("", selection: $model.network.routerMode) {
            ForEach(RouterMode.allCases) { mode in
              Text(mode.label).tag(mode)
            }
          }
          .pickerStyle(.menu)
          .labelsHidden()
          .accessibilityIdentifier("network.router.mode")
        }
        if model.network.routerMode != .bridge {
          PaneFieldRow("LAN IP Address") {
            AirPortTextField(
              text: $model.network.lanIPAddress,
              placeholder: "LAN IP address",
              identifier: "network.lan.ip.address")
          }
          PaneFieldRow("DHCP Range") {
            DHCPRangeSummary(network: $model.network)
          }
        }
        NetworkTableSection(
          title: "DHCP Reservations",
          columns: ("Description", "IP Address"),
          tableIdentifier: "dhcpTable",
          disabled: model.network.routerMode == .bridge
        )
        NetworkTableSection(
          title: "Port Settings",
          columns: ("Description", "Type"),
          tableIdentifier: "natTable",
          disabled: model.network.routerMode != .dhcpAndNat
        )
        Button("Network Options…") {
          showOptions = true
        }
        .buttonStyle(.bordered)
        .disabled(model.network.routerMode == .bridge)
        .accessibilityIdentifier("network.options.open")
      }
    }
    .sheet(isPresented: $showOptions) {
      NetworkOptionsSheet()
        .environmentObject(model)
    }
  }
}

struct DHCPRangeSummary: View {
  @Binding var network: NetworkState

  var body: some View {
    Group {
      if network.routerMode == .dhcpOnly {
        HStack(spacing: 4) {
          NetworkOptionsTextField(
            text: $network.dhcpRangeStart,
            identifier: "network.dhcp.range.start")
            .frame(width: 129, height: 24)
          Text("to")
            .frame(width: 18)
          NetworkOptionsTextField(
            text: $network.dhcpRangeEnd,
            identifier: "network.dhcp.range.end")
            .frame(width: 129, height: 24)
        }
      } else {
        Text("\(network.dhcpRangeStart) to \(network.dhcpRangeEnd)")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .onChange(of: network.routerMode) { newMode in
      if newMode == .dhcpOnly,
        network.dhcpRangeStart == "10.0.1.2",
        network.dhcpRangeEnd == "10.0.1.200"
      {
        network.dhcpRangeStart = "192.168.4.2"
        network.dhcpRangeEnd = "192.168.4.200"
      }
    }
  }
}

struct NetworkTableSection: View {
  var title: String
  var columns: (String, String)
  var tableIdentifier: String
  var disabled: Bool

  var body: some View {
    PaneFieldRow(title) {
      VStack(alignment: .leading, spacing: 6) {
        emptyTable
        HStack(spacing: 6) {
          Button {} label: { Image(systemName: "plus") }
            .accessibilityIdentifier("\(tableIdentifier).add")
          Button {} label: { Image(systemName: "minus") }
            .accessibilityIdentifier("\(tableIdentifier).remove")
          Spacer()
          Button("Edit") {}
            .accessibilityIdentifier("\(tableIdentifier).edit")
        }
        .buttonStyle(.bordered)
        .disabled(true)
      }
      .opacity(disabled ? 0.5 : 1)
    }
  }

  private var emptyTable: some View {
    VStack(spacing: 0) {
      HStack {
        Text(columns.0).frame(maxWidth: .infinity, alignment: .leading)
        Text(columns.1).frame(maxWidth: .infinity, alignment: .leading)
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(Color.primary.opacity(0.06))
      Divider()
      Text("No entries")
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 60)
    }
    .background(Color.primary.opacity(0.03))
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .accessibilityIdentifier(tableIdentifier)
  }
}
