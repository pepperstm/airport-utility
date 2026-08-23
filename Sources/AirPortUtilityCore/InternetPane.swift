import AppKit
import SwiftUI

struct InternetPane: View {
  @EnvironmentObject private var model: AirportAppModel
  @State private var showOptions = false
  @State private var showModemOptions = false

  var body: some View {
    DashboardSection(title: "Internet", icon: "globe") {
      VStack(alignment: .leading, spacing: 12) {
        PaneFieldRow("Connect Using") {
          Picker("", selection: $model.internet.connectUsing) {
            ForEach(model.internetConnectUsingOptions) { value in
              Text(value.label).tag(value)
            }
          }
          .pickerStyle(.menu)
          .labelsHidden()
          .accessibilityIdentifier("internet.connect.using")
          .onChange(of: model.internet.connectUsing) { model.handleInternetConnectUsingChanged($0) }
        }
        if model.internet.connectUsing == .pppoe {
          PaneFieldRow("Account Name") {
            AirPortTextField(
              text: $model.internet.pppoeAccount,
              identifier: "internet.pppoe.account")
          }
          PaneFieldRow("Password") {
            AirPortSecureField(
              text: $model.internet.pppoePassword,
              identifier: "internet.pppoe.password")
              .frame(height: 24)
          }
          PaneFieldRow("Service Name") {
            AirPortTextField(
              text: $model.internet.pppoeService,
              identifier: "internet.pppoe.service")
          }
          PaneFieldRow("Connection") {
            Picker("", selection: $model.internet.pppoeConnection) {
              ForEach(PPPoEConnectionOption.allCases) { option in
                Text(option.label).tag(option.value)
              }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .accessibilityIdentifier("internet.pppoe.connection")
          }
        }
        if model.internet.connectUsing == .modem && model.showsModemControls {
          PaneFieldRow("Phone Number") {
            AirPortTextField(
              text: $model.internet.modemPhoneNumber,
              identifier: "internet.modem.phone.number")
          }
          PaneFieldRow("Alternate Number") {
            AirPortTextField(
              text: $model.internet.modemAlternateNumber,
              identifier: "internet.modem.alternate.number")
          }
          if model.showsExtendedModemControls {
            PaneFieldRow("Account Name") {
              AirPortTextField(
                text: $model.internet.modemAccount,
                identifier: "internet.modem.account")
            }
            PaneFieldRow("Password") {
              AirPortSecureField(
                text: $model.internet.modemPassword,
                identifier: "internet.modem.password")
                .frame(height: 24)
            }
            PaneFieldRow("Verify Password") {
              AirPortSecureField(
                text: $model.internet.modemVerifyPassword,
                identifier: "internet.modem.verify.password")
                .frame(height: 24)
            }
          }
          Toggle("Use AOL", isOn: $model.internet.modemUseAOL)
            .accessibilityIdentifier("internet.modem.use.aol")
          if model.showsExtendedModemControls {
            Button("Modem Options…") {
              showModemOptions = true
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("internet.modem.options.open")
          }
        }
        if model.internet.connectUsing != .modem {
          PaneFieldRow("IPv4 Address") {
            if model.internet.connectUsing == .static {
              AirPortTextField(
                text: $model.internet.ipv4Address,
                identifier: "internet.ipv4.address")
            } else {
              HStack {
                Text(model.internet.ipv4Address)
                  .frame(maxWidth: .infinity, alignment: .leading)
                if model.internet.connectUsing == .dhcp {
                  Button("Renew DHCP Lease") {
                    model.renewDHCPLease()
                  }
                  .buttonStyle(.bordered)
                  .accessibilityIdentifier("internet.renew.dhcp.lease")
                }
              }
            }
          }
          PaneFieldRow("Subnet Mask") {
            if model.internet.connectUsing == .static {
              AirPortTextField(
                text: $model.internet.subnetMask,
                identifier: "internet.subnet.mask")
            } else {
              Text(model.internet.subnetMask)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
          PaneFieldRow("Router Address") {
            if model.internet.connectUsing == .static {
              AirPortTextField(
                text: $model.internet.routerAddress,
                identifier: "internet.router.address")
            } else {
              Text(model.internet.routerAddress)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
          PaneFieldRow("DNS Servers") {
            DNSServerFields(
              text: $model.internet.dnsServers,
              placeholderText: model.internet.connectUsing == .dhcp
                ? model.internet.dnsServerPreview : "",
              layout: model.internet.connectUsing == .pppoe ? .horizontal : .vertical,
              identifierPrefix: "internet.dns"
            )
          }
          if model.showsIPv6InternetControls {
            PaneFieldRow("IPv6 DNS Servers") {
              DNSServerFields(
                text: $model.internet.ipv6DNSServers,
                placeholderText: model.internet.connectUsing == .dhcp
                  ? model.internet.ipv6DNSServerPreview : "",
                identifierPrefix: "internet.ipv6.dns"
              )
            }
          }
          PaneFieldRow("Domain Name") {
            AirPortTextField(
              text: $model.internet.domainName,
              identifier: "internet.domain.name")
          }
          if model.showsIPv6InternetControls {
            PaneFieldRow("IPv6 Address") {
              Text(model.internet.ipv6Address)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
          if model.showsInternetOptionsControls {
            Button("Internet Options…") {
              showOptions = true
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("internet.options.open")
          }
        }
      }
    }
    .sheet(isPresented: $showOptions) {
      InternetOptionsSheet()
        .environmentObject(model)
    }
    .sheet(isPresented: $showModemOptions) {
      ModemOptionsSheet()
        .environmentObject(model)
    }
  }
}

struct DNSServerFields: View {
  enum Layout {
    case vertical
    case horizontal
  }

  @Binding var text: String
  var placeholderText = ""
  var layout: Layout = .vertical
  var identifierPrefix: String?

  var body: some View {
    Group {
      if layout == .horizontal {
        HStack(spacing: 6) {
          serverField(index: 0)
            .frame(width: 137)
          serverField(index: 1)
            .frame(width: 136)
        }
      } else {
        VStack(spacing: 6) {
          serverField(index: 0)
          serverField(index: 1)
        }
      }
    }
  }

  private func serverField(index: Int) -> some View {
    AirPortTextField(
      text: binding(for: index),
      placeholder: placeholder(for: index),
      identifier: identifierPrefix.map { "\($0).\(index + 1)" })
  }

  private func placeholder(for index: Int) -> String {
    let servers = Self.servers(from: placeholderText)
    return index < servers.count ? servers[index] : ""
  }

  func binding(for index: Int) -> Binding<String> {
    Binding {
      let servers = Self.servers(from: text)
      return index < servers.count ? servers[index] : ""
    } set: { value in
      var servers = Self.servers(from: text)
      while servers.count <= index {
        servers.append("")
      }
      servers[index] = value
      text = Self.combined(servers)
    }
  }

  static func servers(from text: String) -> [String] {
    text
      .split { $0 == "," || $0 == "\n" }
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
  }

  static func combined(_ servers: [String]) -> String {
    servers
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: ", ")
  }
}
