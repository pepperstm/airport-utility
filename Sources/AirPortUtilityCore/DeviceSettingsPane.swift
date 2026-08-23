// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Graham Barber

import SwiftUI

struct DeviceSettingsPane: View {
  @EnvironmentObject private var model: AirportAppModel

  var body: some View {
    VStack(spacing: 0) {
      if showsPaneTabStrip {
        PaneTabStrip()
          .padding(20)
      }
      ScrollView {
        content
          .padding(.horizontal, 20)
          .padding(.bottom, 20)
          .frame(maxWidth: .infinity, alignment: .top)
      }
      DeviceSettingsFooter()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var showsPaneTabStrip: Bool {
    !model.shouldShowDeviceConnectionPrompt && !model.shouldShowDeviceLoading
  }

  @ViewBuilder
  private var content: some View {
    if model.shouldShowDeviceLoading {
      VStack(spacing: 12) {
        ProgressView()
        Text("Loading device settings…")
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.top, 60)
    } else if model.shouldShowDeviceConnectionPrompt {
      DashboardSection(title: "Connect to Base Station", icon: "lock") {
        ConnectionPopover(mode: DevicePopoverPresentationPolicy.connectionPromptMode)
      }
      .frame(maxWidth: 360)
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.top, 40)
    } else {
      pane
    }
  }

  @ViewBuilder
  private var pane: some View {
    switch model.selectedPane {
    case .baseStation:
      BaseStationPane()
    case .internet:
      InternetPane()
    case .wireless:
      WirelessPane()
    case .network:
      NetworkPane()
    case .airPlay:
      AirPlayPane()
    case .disks:
      DisksPane()
    case .advanced:
      AdvancedPane()
    case .firmware:
      FirmwarePane()
    case .diagnostics:
      DiagnosticsPane()
    }
  }
}

struct PaneTabStrip: View {
  @EnvironmentObject private var model: AirportAppModel

  var body: some View {
    HStack(spacing: 4) {
      ForEach(model.visiblePanes) { pane in
        Button {
          model.selectedPane = pane
        } label: {
          Text(pane.rawValue)
            .font(.system(size: 13, weight: model.selectedPane == pane ? .semibold : .regular))
            .foregroundStyle(model.selectedPane == pane ? Color.primary : Color.secondary)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
        .background {
          RoundedRectangle(cornerRadius: 7)
            .fill(model.selectedPane == pane ? Color.accentColor.opacity(0.25) : Color.clear)
        }
        .accessibilityIdentifier(
          "devicesettings.tab.\(pane.rawValue.lowercased().replacingOccurrences(of: " ", with: "."))"
        )
        .accessibilityAddTraits(model.selectedPane == pane ? [.isSelected] : [])
      }
      Spacer()
    }
    .padding(6)
    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    .onChange(of: model.visiblePanes) { _ in
      model.reconcileSelectedPaneWithCapabilities()
    }
  }
}

struct DeviceSettingsFooter: View {
  @EnvironmentObject private var model: AirportAppModel

  var body: some View {
    HStack(spacing: 12) {
      if let status = footerStatus {
        Text(status)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        Spacer()
      }
      Button("Cancel") {
        model.cancelEditing()
      }
      .buttonStyle(.bordered)
      .accessibilityIdentifier("devicesettings.cancel")
      Button("Update") {
        model.applyPendingChanges()
      }
      .buttonStyle(.borderedProminent)
      .disabled(!model.canApplyPendingChanges)
      .keyboardShortcut(.defaultAction)
      .accessibilityIdentifier("devicesettings.update")
    }
    .padding(20)
    .background(Color.primary.opacity(0.05))
  }

  private var footerStatus: String? {
    let status = model.status.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !status.isEmpty else { return nil }
    guard !status.hasPrefix("Connected"), !status.hasPrefix("Ready to connect"),
      status != "Not connected"
    else {
      return nil
    }
    return status
  }
}
