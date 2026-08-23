import AppKit
import SwiftUI

func airPortResourceImage(named name: String, fallbackSystemName: String) -> Image {
  if let image = airPortReplacementNSImage(named: name) {
    return Image(nsImage: image)
  }
  return Image(systemName: fallbackSystemName)
}

func airPortReplacementNSImage(named name: String) -> NSImage? {
  guard let replacementName = AirPortReplacementArtwork.resourceName(for: name) else {
    return nil
  }
  guard let url = airPortReplacementResourceURL(named: replacementName) else {
    return nil
  }
  return NSImage(contentsOf: url)
}

private func airPortReplacementResourceURL(named name: String) -> URL? {
  if let url = Bundle.main.url(forResource: name, withExtension: nil) {
    return url
  }
  if let url = Bundle.module.url(forResource: name, withExtension: nil) {
    return url
  }
  let resourceURL = URL(fileURLWithPath: name)
  return Bundle.module.url(
    forResource: resourceURL.deletingPathExtension().lastPathComponent,
    withExtension: resourceURL.pathExtension)
}

enum AirPortReplacementArtwork {
  static func resourceName(for legacyName: String) -> String? {
    switch legacyName {
    case "Internet-3D~mac.tiff",
      "AirPortExpress-3D-cropped~mac.tiff",
      "AirPortEx-3D-cropped~mac.tiff",
      "TimeCapsule-3D-cropped~mac.tiff",
      "AirPort-8-3D-cropped~mac.tiff",
      "AirPortExtremeN-3D-cropped~mac.tiff",
      "AirPortExtremeG-3D-cropped~mac.tiff",
      "GenericBase-3D-cropped~mac.tiff",
      "AirDisk.icns",
      "Drives.icns":
      return legacyName
    default:
      return nil
    }
  }
}

public struct ContentView: View {
  @EnvironmentObject private var model: AirportAppModel
  @State private var isDeviceSettingsSectionExpanded = true

  public init() {}

  public var body: some View {
    NavigationSplitView {
      List(selection: $model.sidebarDestination) {
        sidebarRow(.dashboard)
        sidebarRow(.devices)
        DisclosureGroup(isExpanded: $isDeviceSettingsSectionExpanded) {
          if model.visibleTopologyDevices.isEmpty {
            Text("No devices found")
              .foregroundStyle(.secondary)
          } else {
            ForEach(model.visibleTopologyDevices) { device in
              deviceRow(device)
            }
          }
        } label: {
          Label(
            SidebarDestination.deviceSettings.rawValue,
            systemImage: SidebarDestination.deviceSettings.systemImage)
        }
        sidebarRow(.sites)
        sidebarRow(.preferences)
      }
      .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
      .listStyle(.sidebar)
    } detail: {
      detailContent
    }
    .navigationSplitViewStyle(.balanced)
    .sheet(isPresented: $model.isShowingPasswords) {
      PasswordsSheet()
        .environmentObject(model)
    }
    .sheet(isPresented: $model.isShowingConfigureOther) {
      ConfigureOtherSheet()
        .environmentObject(model)
    }
    .sheet(item: $model.settingsComparison) { comparison in
      SettingsDiffSheet(comparison: comparison)
    }
    .sheet(isPresented: $model.isShowingSetup) {
      AirPortSetupSheet()
        .environmentObject(model)
    }
    .sheet(isPresented: $model.isShowingRestartConfirmation) {
      RestartBaseStationSheet()
        .environmentObject(model)
    }
    .sheet(isPresented: $model.isShowingRestoreConfirmation) {
      RestoreDefaultSettingsSheet()
        .environmentObject(model)
    }
    .task {
      model.startBonjourDiscovery()
      model.refreshHostInternetSettings()
      model.loadInitialSettingsIfPossible()
    }
    .preferredColorScheme(.dark)
  }

  private func sidebarRow(_ destination: SidebarDestination) -> some View {
    Label(destination.rawValue, systemImage: destination.systemImage)
      .tag(destination)
      .accessibilityIdentifier("sidebar.\(destination.rawValue.lowercased())")
  }

  private func deviceRow(_ device: AirportDiscoveredDevice) -> some View {
    Button {
      model.selectTopologyDevice(device)
      model.beginEditing()
    } label: {
      Label(device.displayName, systemImage: device.topologySymbolName)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("sidebar.devicesettings.device.\(device.id)")
  }

  @ViewBuilder
  private var detailContent: some View {
    switch model.sidebarDestination {
    case .dashboard:
      DashboardPane()
    case .devices:
      TopologyView()
    case .deviceSettings:
      DeviceSettingsPane()
    case .sites:
      SitesSheet()
    case .preferences:
      PreferencesSheet()
    }
  }
}

public enum SidebarDestination: String, CaseIterable, Identifiable, Hashable {
  case dashboard = "Dashboard"
  case devices = "Devices"
  case deviceSettings = "Device Settings"
  case sites = "Sites"
  case preferences = "Preferences"

  public var id: Self { self }

  var systemImage: String {
    switch self {
    case .dashboard:
      "gauge.with.dots.needle.67percent"
    case .devices:
      "point.3.connected.trianglepath.dotted"
    case .deviceSettings:
      "slider.horizontal.3"
    case .sites:
      "building.2"
    case .preferences:
      "gearshape"
    }
  }
}
