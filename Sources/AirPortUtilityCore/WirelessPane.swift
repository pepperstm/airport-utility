import AppKit
import SwiftUI

struct WirelessPane: View {
  @EnvironmentObject private var model: AirportAppModel
  @State private var showOptions = false

  var body: some View {
    DashboardSection(title: "Wireless", icon: "wifi") {
      VStack(alignment: .leading, spacing: 12) {
        PaneFieldRow("Network Mode") {
          Picker("", selection: wirelessMode) {
            Text("Create a wireless network").tag("create")
            if model.showsWirelessClientModeControls || model.wireless.mode == "join" {
              Text("Join a wireless network").tag("join")
            }
            if model.showsClassicWDSWirelessControls || model.wireless.mode == "wds" {
              Text("Participate in a WDS network").tag("wds")
            }
            Text("Extend a wireless network").tag("extend")
            Text("Off").tag("off")
          }
          .pickerStyle(.menu)
          .labelsHidden()
          .accessibilityIdentifier("wireless.network.mode")
        }
        if model.wireless.mode != "off" {
          PaneFieldRow("Wireless Network Name") {
            if model.wireless.mode == "extend" || model.wireless.mode == "wds" {
              WirelessNetworkNameComboBox(
                text: $model.wireless.networkName,
                items: model.extendableWirelessNetworkNames
              )
            } else {
              AirPortTextField(
                text: $model.wireless.networkName,
                placeholder: "Network name",
                identifier: "wireless.network.name")
            }
          }
          PaneFieldRow("Wireless Security") {
            Picker("", selection: $model.wireless.security) {
              ForEach(model.wirelessSecurityOptions) { option in
                Text(option.label).tag(option.rawValue)
              }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .accessibilityIdentifier("wireless.security")
          }
          if model.wireless.mode == "create" {
            Toggle("Allow this network to be extended", isOn: $model.wireless.allowNetworkExtension)
              .accessibilityIdentifier("wireless.allow.network.extension")
          }
          if model.wireless.mode == "wds" {
            PaneFieldRow("WDS Mode") {
              Picker("", selection: $model.wireless.wdsMode) {
                Text("WDS main").tag("main")
                Text("WDS relay").tag("relay")
                Text("WDS remote").tag("remote")
              }
              .pickerStyle(.menu)
              .labelsHidden()
              .accessibilityIdentifier("wireless.wds.mode")
            }
            PaneFieldRow("WDS Peers") {
              AirPortTextField(
                text: $model.wireless.wdsPeerAirPortIDs,
                placeholder: "AirPort ID",
                identifier: "wireless.wds.peers")
            }
          }
          if model.wireless.security != "none" {
            PaneFieldRow("Wireless Password") {
              AirPortSecureField(
                text: $model.wireless.password,
                placeholder: "New wireless password",
                identifier: "wireless.password")
                .frame(height: 24)
            }
            PaneFieldRow("Verify Password") {
              AirPortSecureField(
                text: $model.wireless.verifyPassword,
                placeholder: "Verify wireless password",
                identifier: "wireless.verify.password")
                .frame(height: 24)
            }
          }
          Button("Wireless Options…") {
            showOptions = true
          }
          .buttonStyle(.bordered)
          .accessibilityIdentifier("wireless.options.open")
        }
      }
    }
    .sheet(isPresented: $showOptions) {
      WirelessOptionsSheet()
        .environmentObject(model)
    }
  }

  private var wirelessMode: Binding<String> {
    Binding {
      model.wireless.mode
    } set: { newMode in
      let previousMode = model.wireless.mode
      model.wireless.mode = newMode
      restoreWirelessDefaultsIfNeeded(from: previousMode, to: newMode)
      restoreLegacyClientSecurityIfNeeded()
    }
  }

  private func restoreWirelessDefaultsIfNeeded(from previousMode: String, to newMode: String) {
    WirelessModeDefaults.restoreIfNeeded(
      wireless: &model.wireless,
      previousMode: previousMode,
      newMode: newMode
    )
  }

  private func restoreLegacyClientSecurityIfNeeded() {
    guard model.usesLegacyWirelessClientSecurity else { return }
    let allowed = Set(model.wirelessSecurityOptions.map(\.rawValue))
    if !allowed.contains(model.wireless.security) {
      model.wireless.security = WirelessSecurityOption.wpaWPA2Personal.rawValue
    }
  }
}

private struct WirelessNetworkNameComboBox: NSViewRepresentable {
  @Binding var text: String
  var items: [String]

  func makeNSView(context: Context) -> NSComboBox {
    let comboBox = NSComboBox(frame: .zero)
    comboBox.isEditable = true
    comboBox.completes = true
    comboBox.usesDataSource = false
    comboBox.hasVerticalScroller = true
    comboBox.numberOfVisibleItems = 8
    comboBox.font = .systemFont(ofSize: 13)
    comboBox.controlSize = .regular
    comboBox.focusRingType = .none
    comboBox.delegate = context.coordinator
    comboBox.setAccessibilityTitle("Wireless Network Name")
    comboBox.setAccessibilityIdentifier("wireless.network.name")
    updateItems(on: comboBox, items: items)
    comboBox.stringValue = text
    return comboBox
  }

  func updateNSView(_ comboBox: NSComboBox, context: Context) {
    context.coordinator.parent = self
    updateItems(on: comboBox, items: items)
    if comboBox.stringValue != text {
      comboBox.stringValue = text
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  private func updateItems(on comboBox: NSComboBox, items: [String]) {
    let uniqueItems = AirportAppModel.uniqueWirelessNetworkNames(items)
    let currentItems = (0..<comboBox.numberOfItems).compactMap {
      comboBox.itemObjectValue(at: $0) as? String
    }
    guard currentItems != uniqueItems else { return }
    comboBox.removeAllItems()
    comboBox.addItems(withObjectValues: uniqueItems)
    comboBox.numberOfVisibleItems = min(max(uniqueItems.count, 1), 8)
  }

  final class Coordinator: NSObject, NSComboBoxDelegate {
    var parent: WirelessNetworkNameComboBox

    init(parent: WirelessNetworkNameComboBox) {
      self.parent = parent
    }

    func controlTextDidChange(_ notification: Notification) {
      guard let comboBox = notification.object as? NSComboBox else { return }
      parent.text = comboBox.stringValue
    }

    func controlTextDidEndEditing(_ notification: Notification) {
      guard let comboBox = notification.object as? NSComboBox else { return }
      parent.text = comboBox.stringValue
    }

    func comboBoxSelectionDidChange(_ notification: Notification) {
      guard let comboBox = notification.object as? NSComboBox else { return }
      parent.text = (comboBox.objectValueOfSelectedItem as? String) ?? comboBox.stringValue
    }
  }
}

enum WirelessModeDefaults {
  static func restoreIfNeeded(wireless: inout WirelessState, previousMode: String, newMode: String)
  {
    guard newMode != "off" else { return }
    let hasOffNetworkName =
      wireless.networkName.localizedCaseInsensitiveCompare("Off") == .orderedSame
    guard previousMode == "off" || wireless.networkName.isEmpty || hasOffNetworkName else {
      return
    }

    if hasOffNetworkName || wireless.networkName.isEmpty {
      wireless.networkName = newMode == "create" ? "Apple Network b92ec3" : ""
    }
    wireless.security = "none"
    wireless.password = ""
    wireless.verifyPassword = ""
  }
}
