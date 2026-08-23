import AppKit
import SwiftUI

enum DevicePopoverLayout {
  static let rowHeight: CGFloat = 17.5
  static let minimumDetailsHeight: CGFloat = 107
  static let maximumDetailsHeight: CGFloat = 280

  static func detailsContentHeight(
    detailRowCount: Int,
    wirelessClientCount: Int
  ) -> CGFloat {
    max(
      minimumDetailsHeight,
      CGFloat(detailRowCount + wirelessClientCount) * rowHeight + 2)
  }

  static func detailsViewportHeight(
    detailRowCount: Int,
    wirelessClientCount: Int
  ) -> CGFloat {
    min(
      detailsContentHeight(
        detailRowCount: detailRowCount,
        wirelessClientCount: wirelessClientCount),
      maximumDetailsHeight)
  }
}

struct DevicePopover: View {
  @EnvironmentObject private var model: AirportAppModel

  var body: some View {
    if model.shouldShowDeviceLoading {
      DeviceLoadingPopover()
    } else if model.shouldShowDeviceConnectionPrompt {
      ConnectionPopover(mode: DevicePopoverPresentationPolicy.connectionPromptMode)
    } else {
      deviceDetails
    }
  }

  private var deviceDetails: some View {
    VStack(alignment: .leading, spacing: 0) {
      PopoverTitleLabel(
        text: model.baseStation.name.isEmpty ? "time capsule" : model.baseStation.name,
        symbolName: model.selectedTopologyDevice()?.topologySymbolName
      )
      .frame(width: 283, height: 19)
      .padding(.bottom, 6)
      PopoverDetailsRows(
        rows: deviceDetailRows,
        wirelessClients: model.wirelessClients,
        viewportHeight: deviceDetailsHeight)
        .frame(width: 274, height: deviceDetailsHeight)
      HStack {
        Spacer()
        PopoverEditButton {
          if model.selectedDeviceFirmwareUpdateBadgeCount > 0 {
            model.beginEditingFirmware()
          } else {
            model.beginEditing()
          }
        }
        .frame(width: 47, height: 18)
      }
      .padding(.top, 7)
    }
    .padding(13)
    .frame(width: 300, height: devicePopoverHeight, alignment: .leading)
  }

  private var deviceDetailRows: [(String, String)] {
    var rows = [
      ("status", model.selectedDeviceStatusText()),
      ("network", model.wireless.networkName),
      ("IP address", model.internet.ipv4Address),
      ("LAN IP address", model.network.lanIPAddress),
      ("serial number", model.baseStation.serialNumber),
      ("version", model.baseStation.version),
    ]
    let firmwareUpdate = model.selectedDeviceFirmwareUpdateDetail
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if !firmwareUpdate.isEmpty {
      rows.insert(("firmware update", firmwareUpdate), at: 1)
    }
    let statusDetails = model.selectedDeviceStatusDetails()
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    for detail in statusDetails.reversed() {
      rows.insert(("detail", detail), at: firmwareUpdate.isEmpty ? 1 : 2)
    }
    return rows
  }

  private var deviceDetailsHeight: CGFloat {
    DevicePopoverLayout.detailsViewportHeight(
      detailRowCount: deviceDetailRows.count,
      wirelessClientCount: model.wirelessClients.count)
  }

  private var devicePopoverHeight: CGFloat {
    deviceDetailsHeight + 69
  }
}

struct DeviceLoadingPopover: View {
  @EnvironmentObject private var model: AirportAppModel

  var body: some View {
    SettingsLoadingPopover(
      title:
        model.hasLoadedSettings && !model.hasLoadedWirelessClients
        ? "Loading Wireless Clients"
        : "Connecting to Base Station")
  }
}

private struct InternetLoadingPopover: View {
  var body: some View {
    SettingsLoadingPopover(title: "Loading Internet Settings")
  }
}

private struct SettingsLoadingPopover: View {
  @EnvironmentObject private var model: AirportAppModel
  let title: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.system(size: 13, weight: .semibold))
      HStack(spacing: 10) {
        ProgressView()
          .controlSize(.small)
        Text(model.status)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
    .padding(14)
    .frame(width: 277, alignment: .leading)
  }
}

struct InternetPopover: View {
  @EnvironmentObject private var model: AirportAppModel

  var body: some View {
    if model.shouldShowInternetLoading {
      InternetLoadingPopover()
    } else {
      internetDetails
    }
  }

  private var internetDetails: some View {
    VStack(alignment: .leading, spacing: 0) {
      PopoverTitleLabel(text: "Internet", symbolName: "globe")
        .frame(width: 283, height: 19)
        .padding(.bottom, 6)
      PopoverDetailsRows(
        rows: [
          ("connection", model.internetPopoverConnectionStatus),
          ("router address", model.hostInternet.routerAddress),
          ("DNS servers", model.hostInternet.dnsServers),
        ])
        .frame(width: 274, height: 54)
    }
    .padding(13)
    .frame(width: 300, height: 92, alignment: .leading)
  }
}

private struct PopoverTitleLabel: View {
  var text: String
  var symbolName: String?

  var body: some View {
    HStack(spacing: 6) {
      if let symbolName {
        Image(systemName: symbolName)
          .foregroundStyle(.secondary)
      }
      Text(text)
        .font(.system(size: 16, weight: .semibold))
        .lineLimit(1)
        .truncationMode(.tail)
    }
    .frame(maxWidth: .infinity)
  }
}

private struct PopoverDetailRowsContent: View {
  var rows: [(String, String)]
  var hasWirelessClientsHeader: Bool

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        detailRow(label: row.0, value: row.1.isEmpty ? "--" : row.1)
      }
      if hasWirelessClientsHeader {
        detailRow(label: "wireless clients", value: "")
      }
    }
  }

  private func detailRow(label: String, value: String) -> some View {
    HStack(spacing: 14) {
      Text(label)
        .frame(width: 108, alignment: .trailing)
        .foregroundStyle(.secondary)
        .help(label)
      Text(value)
        .frame(width: 152, alignment: .leading)
        .foregroundStyle(.primary)
        .help(value)
      Spacer(minLength: 0)
    }
    .font(.system(size: 13, weight: .semibold))
    .lineLimit(1)
    .truncationMode(.tail)
    .frame(height: DevicePopoverLayout.rowHeight)
  }
}

private struct PopoverDetailsRows: NSViewRepresentable {
  var rows: [(String, String)]
  var wirelessClients: [WirelessClient] = []
  var viewportHeight: CGFloat = DevicePopoverLayout.minimumDetailsHeight

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = PopoverDetailsScrollView(
      frame: NSRect(x: 0, y: 0, width: 274, height: viewportHeight))
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = false
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.scrollerStyle = .overlay
    scrollView.documentView = PopoverDetailsDocumentView()
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    let documentView: PopoverDetailsDocumentView
    if let existingDocumentView = scrollView.documentView as? PopoverDetailsDocumentView {
      documentView = existingDocumentView
    } else {
      documentView = PopoverDetailsDocumentView()
      scrollView.documentView = documentView
    }
    documentView.configure(rows: rows, wirelessClients: wirelessClients)
    let contentHeight = DevicePopoverLayout.detailsContentHeight(
      detailRowCount: rows.count,
      wirelessClientCount: wirelessClients.count)
    scrollView.hasVerticalScroller = contentHeight > viewportHeight
  }
}

private final class PopoverDetailsDocumentView: NSView {
  private var renderedWirelessClientIDs: [String] = []
  private var wirelessClientFields: [String: WirelessClientHoverField] = [:]
  private let wirelessClientDetailsPanel = WirelessClientDetailsPanelController()
  private var presentedWirelessClientID: String?
  private let hostingView = NSHostingView(
    rootView: PopoverDetailRowsContent(rows: [], hasWirelessClientsHeader: false))

  override var isFlipped: Bool {
    true
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    self.frame = NSRect(x: 0, y: 0, width: 274, height: 107)
    hostingView.frame = NSRect(x: 0, y: 0, width: 274, height: 0)
    addSubview(hostingView)
    wirelessClientDetailsPanel.presentationDidEnd = {
      [weak self] clientID in
      self?.wirelessClientPresentationDidEnd(clientID: clientID)
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  func configure(rows: [(String, String)], wirelessClients: [WirelessClient]) {
    frame.size.height = DevicePopoverLayout.detailsContentHeight(
      detailRowCount: rows.count,
      wirelessClientCount: wirelessClients.count)

    let hasWirelessClientsHeader = !wirelessClients.isEmpty
    let hostedRowCount = rows.count + (hasWirelessClientsHeader ? 1 : 0)
    hostingView.rootView = PopoverDetailRowsContent(
      rows: rows, hasWirelessClientsHeader: hasWirelessClientsHeader)
    hostingView.frame = NSRect(
      x: 0, y: 0, width: 274, height: CGFloat(hostedRowCount) * DevicePopoverLayout.rowHeight)

    let clientIDs = wirelessClients.map(\.id)
    guard clientIDs != renderedWirelessClientIDs else {
      updateWirelessClients(wirelessClients)
      return
    }
    renderedWirelessClientIDs = clientIDs
    wirelessClientFields.values.forEach { $0.removeFromSuperview() }
    wirelessClientFields.removeAll()

    guard !wirelessClients.isEmpty else { return }
    let y = CGFloat(rows.count) * DevicePopoverLayout.rowHeight
    for (index, client) in wirelessClients.enumerated() {
      let clientField = WirelessClientHoverField(
        client: client,
        frame: NSRect(
          x: 122,
          y: y + CGFloat(index) * DevicePopoverLayout.rowHeight,
          width: 152,
          height: 19))
      clientField.setAccessibilityIdentifier("popover.wirelessClients.client")
      clientField.presentationChanged = {
        [weak self] field, shouldPresent, immediately in
        self?.wirelessClientPresentationChanged(
          field: field,
          shouldPresent: shouldPresent,
          immediately: immediately)
      }
      wirelessClientFields[client.id] = clientField
      addSubview(clientField)
    }
    updateWirelessClients(wirelessClients)
  }

  fileprivate func hideWirelessClientHoverPanel() {
    presentedWirelessClientID = nil
    wirelessClientDetailsPanel.hide()
  }

  override func viewWillMove(toWindow newWindow: NSWindow?) {
    if newWindow == nil {
      hideWirelessClientHoverPanel()
    }
    super.viewWillMove(toWindow: newWindow)
  }

  private func updateWirelessClients(_ wirelessClients: [WirelessClient]) {
    let clientsByID = Dictionary(
      uniqueKeysWithValues: wirelessClients.map { ($0.id, $0) })
    for (id, field) in wirelessClientFields {
      if let client = clientsByID[id] {
        field.client = client
      }
    }
    guard let presentedWirelessClientID else { return }
    guard let client = clientsByID[presentedWirelessClientID] else {
      hideWirelessClientHoverPanel()
      return
    }
    wirelessClientDetailsPanel.update(client: client)
  }

  private func wirelessClientPresentationChanged(
    field: WirelessClientHoverField,
    shouldPresent: Bool,
    immediately: Bool
  ) {
    if shouldPresent {
      presentedWirelessClientID = field.client.id
      if immediately {
        wirelessClientDetailsPanel.presentImmediately(
          client: field.client,
          from: field)
      } else {
        wirelessClientDetailsPanel.schedule(
          client: field.client,
          from: field)
      }
    } else if presentedWirelessClientID == field.client.id {
      if immediately {
        hideWirelessClientHoverPanel()
      } else {
        wirelessClientDetailsPanel.dismissAfterGracePeriod()
      }
    }
  }

  private func wirelessClientPresentationDidEnd(clientID: String) {
    wirelessClientFields[clientID]?.detailsPresentationDidEnd()
    if presentedWirelessClientID == clientID {
      presentedWirelessClientID = nil
    }
  }

}

private final class PopoverDetailsScrollView: NSScrollView {
  override func reflectScrolledClipView(_ cView: NSClipView) {
    super.reflectScrolledClipView(cView)
    (documentView as? PopoverDetailsDocumentView)?
      .hideWirelessClientHoverPanel()
  }

  override func viewWillMove(toWindow newWindow: NSWindow?) {
    if newWindow == nil {
      (documentView as? PopoverDetailsDocumentView)?
        .hideWirelessClientHoverPanel()
    }
    super.viewWillMove(toWindow: newWindow)
  }
}

private struct PopoverEditButton: View {
  var action: () -> Void

  var body: some View {
    Button("Edit", action: action)
      .buttonStyle(.bordered)
      .controlSize(.small)
      .accessibilityIdentifier("topology.device.popover.edit")
  }
}

struct ConnectionPopover: View {
  enum Mode {
    case full
    case passwordOnly
  }

  @EnvironmentObject private var model: AirportAppModel
  var mode: Mode = .full

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Connect to Base Station")
        .font(.system(size: 13, weight: .semibold))
      if mode == .full {
        AirPortTextField(
          text: $model.connection.host,
          placeholder: "Host",
          identifier: "connection.popover.host")
          .frame(width: 220, height: 24)
      }
      AirPortSecureField(
        text: $model.connection.password,
        placeholder: "Password",
        identifier: "connection.popover.password",
        onSubmit: submitConnection)
        .frame(width: 220, height: 24)
      if mode == .passwordOnly {
        Toggle(
          "Remember this password in my keychain",
          isOn: Binding(
            get: { model.rememberConnectionPassword },
            set: { model.updateRememberConnectionPassword($0) }))
          .toggleStyle(.checkbox)
          .font(.system(size: 12))
          .accessibilityIdentifier("connection.popover.remember.password")
      }
      if mode == .full && !model.mockMode {
        AirPortTextField(
          text: $model.connection.repoPath,
          placeholder: "Repo",
          identifier: "connection.popover.repository")
          .frame(width: 220, height: 24)
      }
      HStack {
        Spacer()
        Button(model.isBusy ? "Working" : "Connect") {
          submitConnection()
        }
        .accessibilityLabel("Connect")
        .accessibilityIdentifier("connection.popover.connect")
        .keyboardShortcut(.defaultAction)
        .disabled(!model.canAttemptConnection)
      }
      if !model.status.hasPrefix("Connected") {
        Text(model.status)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(14)
    .onAppear {
      model.prefillConnectionPasswordFromEnvironmentIfNeeded()
    }
  }

  private func submitConnection() {
    guard model.canAttemptConnection else { return }
    model.refresh()
  }
}
