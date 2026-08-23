import AppKit
import SwiftUI

private enum AirPortTopologyStyle {
  static let connector = Color.secondary.opacity(0.55)
  static let connectorHighlight = Color.secondary.opacity(0.18)
  static let selectedStroke = Color.accentColor
  static let selectedGlow = Color.black.opacity(0.24)
  static let labelShadow = Color.black.opacity(0.46)
  static let rootColumnWidth: CGFloat = 200
  static let selectionOutlineRoot = CGSize(width: 120, height: 120)
  static let selectionOutlineRegular = CGSize(width: 108, height: 108)
  static let selectionOutlineCompact = CGSize(width: 88, height: 88)
}

private enum AirPortTopologyStatus {
  case normal
  case updating
  case inactive

  var color: Color {
    switch self {
    case .normal: return .green
    case .updating: return .orange
    case .inactive: return .secondary
    }
  }
}

private enum TopologyLayoutMetrics {
  static let rootHorizontalSpacing: CGFloat = 72
  static let singleRootHorizontalSpacing: CGFloat = 24
  static let horizontalMargin: CGFloat = 28

  static func rootSpacing(forRootCount rootCount: Int) -> CGFloat {
    rootCount > 1 ? rootHorizontalSpacing : singleRootHorizontalSpacing
  }

  static func rootsWidth(forRootCount rootCount: Int) -> CGFloat {
    let rootCount = max(rootCount, 1)
    return CGFloat(rootCount) * AirPortTopologyStyle.rootColumnWidth
      + CGFloat(max(rootCount - 1, 0)) * rootSpacing(forRootCount: rootCount)
  }
}

struct TopologyView: View {
  @EnvironmentObject private var model: AirportAppModel
  @State private var selectedNetworkInterfaceTitle = OtherWiFiDevicesMenu.defaultNetworkInterface

  var body: some View {
    ZStack(alignment: .topLeading) {
      TopologyBackground()

      GeometryReader { proxy in
        ScrollView([.horizontal, .vertical]) {
          topologyTreeContent
            .padding(.top, 28)
            .padding(.horizontal, TopologyLayoutMetrics.horizontalMargin)
            .frame(minWidth: proxy.size.width, minHeight: proxy.size.height, alignment: .top)
        }
      }

      OtherWiFiDevicesMenu(
        showConnectItem: model.showConnectionDetails && !model.mockMode,
        devices: model.otherWiFiDevicesMenuDevices,
        selectedDeviceID: model.selectedTopologyDeviceID,
        selectedNetworkInterfaceTitle: selectedNetworkInterfaceTitle
      ) {
        DispatchQueue.main.async {
          presentConnectionPopover()
        }
      } onSelectDeviceID: { deviceID in
        DispatchQueue.main.async {
          model.presentOtherWiFiDeviceFromMenu(id: deviceID)
        }
      } onSelectNetworkInterface: { title in
        selectedNetworkInterfaceTitle = title
      }
      .frame(width: 140, height: 22)
      .popover(isPresented: $model.isConnectionPopoverPresented, arrowEdge: .bottom) {
        ConnectionPopover()
          .environmentObject(model)
      }
      .padding(.leading, 19)
      .padding(.top, 19)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private var topologyTreeContent: some View {
    VStack(spacing: 0) {
      TopologyNode(
        symbolName: "globe",
        title: "Internet",
        subtitle: nil,
        accessibilityTitle: model.internetTopologyAccessibilityTitle,
        accessibilityIdentifier: "topology.internet",
        isSelected: model.isInternetSelected,
        selectionOutlineSize: AirPortTopologyStyle.selectionOutlineRoot,
        statusColor: internetStatusColor,
        action: {
          presentInternetPopover()
        }
      )
      .overlay {
        Rectangle()
          .fill(Color.clear)
          .frame(width: 168, height: 190)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
          .popover(
            isPresented: internetPopoverBinding,
            arrowEdge: .trailing
          ) {
            InternetPopover()
              .environmentObject(model)
          }
      }

      if model.visibleTopologyDevices.isEmpty {
        Text("No AirPort base stations discovered")
          .font(.system(size: 14))
          .foregroundStyle(Color.primary.opacity(0.78))
          .shadow(color: AirPortTopologyStyle.labelShadow, radius: 2, x: 0, y: 1)
          .frame(width: 240, height: 120)
      } else {
        VStack(spacing: 0) {
          TopologyRootConnector(
            rootCount: model.topologyTrees.count,
            rootSpacing: rootTreeSpacing
          )
          .frame(height: 42)
          .accessibilityHidden(true)
          HStack(alignment: .top, spacing: rootTreeSpacing) {
            ForEach(model.topologyTrees) { tree in
              TopologyTreeView(tree: tree, isCompact: hasTopologyHierarchy) { device in
                presentBaseStationPopover(for: device)
              }
              .environmentObject(model)
            }
          }
          .frame(minWidth: topologyRootsWidth)
        }
      }
    }
  }

  private func baseStationAccessibilityTitle(for device: AirportDiscoveredDevice) -> String {
    "\(device.displayName) \(device.displayModelName) \(model.deviceStatusText(for: device))"
  }

  private var internetStatusColor: Color {
    (model.isHostInternetConnected ? AirPortTopologyStatus.normal : AirPortTopologyStatus.inactive)
      .color
  }

  private var hasTopologyHierarchy: Bool {
    model.topologyTrees.contains(where: containsHierarchy)
  }

  private var rootTreeSpacing: CGFloat {
    TopologyLayoutMetrics.rootSpacing(forRootCount: model.topologyTrees.count)
  }

  private var topologyRootsWidth: CGFloat {
    TopologyLayoutMetrics.rootsWidth(forRootCount: model.topologyTrees.count)
  }

  private func containsHierarchy(_ tree: AirportTopologyTree) -> Bool {
    !tree.children.isEmpty || tree.children.contains(where: containsHierarchy)
  }

  private func presentInternetPopover() {
    model.isConnectionPopoverPresented = false
    model.selectInternetNode()
    model.refreshHostInternetSettings()
    model.isInternetPopoverPresented = true
  }

  private func presentBaseStationPopover(for device: AirportDiscoveredDevice) {
    model.isConnectionPopoverPresented = false
    model.selectTopologyDevice(device)
    if device.requiresSetup {
      model.beginSetup(for: device)
      return
    }
    model.loadInitialSettingsIfPossible()
    guard DevicePopoverPresentationPolicy.shouldPresentDeviceDetails() else { return }
    model.isDevicePopoverPresented = true
  }

  private func devicePopoverBinding(for device: AirportDiscoveredDevice) -> Binding<Bool> {
    Binding {
      model.isDevicePopoverPresented && model.selectedTopologyDeviceID == device.id
    } set: { isPresented in
      if !isPresented {
        model.isDevicePopoverPresented = false
        model.deselectTopologyDevice(device)
      }
    }
  }

  private var internetPopoverBinding: Binding<Bool> {
    Binding {
      model.isInternetPopoverPresented && model.isInternetSelected
    } set: { isPresented in
      if !isPresented {
        model.isInternetPopoverPresented = false
        model.deselectInternetNode()
      }
    }
  }

  private func presentConnectionPopover() {
    guard !model.isDevicePopoverPresented else {
      return
    }
    model.isConnectionPopoverPresented = true
  }
}

private struct TopologyTreeView: View {
  @EnvironmentObject private var model: AirportAppModel
  let tree: AirportTopologyTree
  let isCompact: Bool
  var present: (AirportDiscoveredDevice) -> Void

  var body: some View {
    VStack(spacing: 0) {
      deviceNode(tree.device)
      if !tree.children.isEmpty {
        TopologyChildrenConnector(
          wirelessConnections: tree.children.map {
            model.isWirelessTopologyConnection(from: $0.device, to: tree.device)
          },
          childSpacing: tree.children.count > 1 ? 42 : 24
        )
        .frame(maxWidth: .infinity)
        .frame(height: isCompact ? 24 : 44)
        .accessibilityHidden(true)
        HStack(alignment: .top, spacing: tree.children.count > 1 ? 42 : 24) {
          ForEach(tree.children) { child in
            TopologyTreeView(tree: child, isCompact: isCompact, present: present)
              .environmentObject(model)
          }
        }
      }
    }
  }

  private func deviceNode(_ device: AirportDiscoveredDevice) -> some View {
    TopologyNode(
      symbolName: device.topologySymbolName,
      title: device.displayName,
      subtitle: device.displayModelName,
      accessibilityTitle:
        "\(device.displayName) \(device.displayModelName) \(model.deviceStatusText(for: device))",
      accessibilityIdentifier: "topology.device.\(device.id)",
      imageFrameHeight: isCompact ? 72 : 120,
      iconSize: isCompact ? 64 : 84,
      imageOffsetY: isCompact ? 10 : 35,
      labelTopPadding: isCompact ? 0 : 19,
      nodeFrameHeight: isCompact ? 115 : 200,
      isSelected: model.selectedTopologyDeviceID == device.id,
      selectionOutlineSize: isCompact
        ? AirPortTopologyStyle.selectionOutlineCompact : AirPortTopologyStyle.selectionOutlineRegular,
      statusColor: statusColor(for: device),
      badgeCount: model.firmwareUpdateBadgeCount(for: device),
      badgeText: device.requiresSetup ? "NEW" : nil,
      action: {
        present(device)
      }
    )
    .overlay {
      Rectangle()
        .fill(Color.clear)
        .frame(width: 168, height: 200)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .popover(
          isPresented: devicePopoverBinding(for: device),
          arrowEdge: .trailing
        ) {
          DevicePopover()
            .environmentObject(model)
        }
    }
  }

  private func devicePopoverBinding(for device: AirportDiscoveredDevice) -> Binding<Bool> {
    Binding {
      model.isDevicePopoverPresented && model.selectedTopologyDeviceID == device.id
    } set: { isPresented in
      if !isPresented {
        model.isDevicePopoverPresented = false
        model.deselectTopologyDevice(device)
      }
    }
  }

  private func statusColor(for device: AirportDiscoveredDevice) -> Color {
    let status = model.deviceStatusText(for: device)
    if model.isTopologyDeviceUpdating(device) || status == "Restarting" {
      return AirPortTopologyStatus.updating.color
    }
    return status == "Working normally"
      ? AirPortTopologyStatus.normal.color : AirPortTopologyStatus.updating.color
  }

}

private struct TopologyChildrenConnector: View {
  var wirelessConnections: [Bool]
  var childSpacing: CGFloat

  var body: some View {
    Canvas { context, size in
      guard !wirelessConnections.isEmpty else { return }
      let middleX = size.width / 2
      let middleY = size.height / 2
      let centerSpacing = AirPortTopologyStyle.rootColumnWidth + childSpacing
      let firstCenterX =
        middleX
        - CGFloat(wirelessConnections.count - 1) * centerSpacing / 2

      for (index, isWireless) in wirelessConnections.enumerated() {
        let childX = firstCenterX + CGFloat(index) * centerSpacing
        var path = Path()
        path.move(to: CGPoint(x: middleX, y: 0))
        path.addLine(to: CGPoint(x: middleX, y: middleY))
        path.addLine(to: CGPoint(x: childX, y: middleY))
        path.addLine(to: CGPoint(x: childX, y: size.height))
        context.stroke(
          path,
          with: .color(AirPortTopologyStyle.connector),
          style: StrokeStyle(
            lineWidth: 2,
            lineCap: .round,
            lineJoin: .round,
            dash: isWireless ? [1, 8] : []))
      }
    }
  }
}

private struct TopologyRootConnector: View {
  var rootCount: Int
  var rootSpacing: CGFloat

  private let rootWidth = AirPortTopologyStyle.rootColumnWidth
  private let lineWidth: CGFloat = 2

  var body: some View {
    TopologyRootConnectorShape(rootCount: rootCount, rootSpacing: rootSpacing, rootWidth: rootWidth)
      .stroke(
        AirPortTopologyStyle.connector,
        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
      )
      .overlay {
        TopologyRootConnectorShape(
          rootCount: rootCount, rootSpacing: rootSpacing, rootWidth: rootWidth
        )
        .stroke(
          AirPortTopologyStyle.connectorHighlight,
          style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
        )
        .offset(x: -1.2, y: -1.2)
      }
      .frame(width: connectorWidth)
  }

  private var connectorWidth: CGFloat {
    guard rootCount > 0 else { return rootWidth }
    return CGFloat(rootCount) * rootWidth + CGFloat(max(rootCount - 1, 0)) * rootSpacing
  }
}

private struct TopologyRootConnectorShape: Shape {
  var rootCount: Int
  var rootSpacing: CGFloat
  var rootWidth: CGFloat

  func path(in rect: CGRect) -> Path {
    var path = Path()
    guard rootCount > 0 else { return path }

    let rootStep = rootWidth + rootSpacing
    let firstCenterX = rect.minX + rootWidth / 2
    let lastCenterX = firstCenterX + CGFloat(rootCount - 1) * rootStep
    let centerX = (firstCenterX + lastCenterX) / 2
    let topY = rect.minY + 2
    let busY = rect.minY + 26
    let bottomY = rect.maxY
    let radius: CGFloat = 10

    if rootCount == 1 {
      path.move(to: CGPoint(x: centerX, y: topY))
      path.addLine(to: CGPoint(x: centerX, y: bottomY))
      return path
    }

    path.move(to: CGPoint(x: centerX, y: topY))
    path.addLine(to: CGPoint(x: centerX, y: busY - radius))
    path.addQuadCurve(
      to: CGPoint(x: centerX - radius, y: busY),
      control: CGPoint(x: centerX, y: busY))
    path.addLine(to: CGPoint(x: firstCenterX + radius, y: busY))
    path.addQuadCurve(
      to: CGPoint(x: firstCenterX, y: busY + radius),
      control: CGPoint(x: firstCenterX, y: busY))
    path.addLine(to: CGPoint(x: firstCenterX, y: bottomY))

    if rootCount > 1 {
      path.move(to: CGPoint(x: centerX, y: busY - radius))
      path.addQuadCurve(
        to: CGPoint(x: centerX + radius, y: busY),
        control: CGPoint(x: centerX, y: busY))
      path.addLine(to: CGPoint(x: lastCenterX - radius, y: busY))
      path.addQuadCurve(
        to: CGPoint(x: lastCenterX, y: busY + radius),
        control: CGPoint(x: lastCenterX, y: busY))
      path.addLine(to: CGPoint(x: lastCenterX, y: bottomY))
    }

    if rootCount > 2 {
      for index in 1..<(rootCount - 1) {
        let childCenterX = firstCenterX + CGFloat(index) * rootStep
        path.move(to: CGPoint(x: childCenterX, y: busY))
        path.addLine(to: CGPoint(x: childCenterX, y: bottomY))
      }
    }

    return path
  }
}

extension AirportDiscoveredDevice {
  var topologyImageName: String {
    switch productID.trimmingCharacters(in: .whitespacesAndNewlines) {
    case "102":
      return "AirPortExpress-3D-cropped~mac.tiff"
    case "107", "115":
      return "AirPortEx-3D-cropped~mac.tiff"
    case "106", "109", "113", "116":
      return "TimeCapsule-3D-cropped~mac.tiff"
    case "119", "120":
      return "AirPort-8-3D-cropped~mac.tiff"
    case "3":
      return "AirPortExtremeG-3D-cropped~mac.tiff"
    case "104", "105", "108", "114", "117":
      return "AirPortExtremeN-3D-cropped~mac.tiff"
    default:
      return topologyImageNameFromDisplayedText
    }
  }

  private var topologyImageNameFromDisplayedText: String {
    let text = "\(displayModelName) \(displayName)"
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    if text.contains("time capsule") {
      return "TimeCapsule-3D-cropped~mac.tiff"
    }
    if text.contains("express") {
      return "AirPortExpress-3D-cropped~mac.tiff"
    }
    if text.contains("extreme") {
      return "AirPortExtremeN-3D-cropped~mac.tiff"
    }
    return "GenericBase-3D-cropped~mac.tiff"
  }

  var topologySymbolName: String {
    switch productID.trimmingCharacters(in: .whitespacesAndNewlines) {
    case "102":
      return "wifi"
    case "107", "115":
      return "wifi.router"
    case "106", "109", "113", "116":
      return "wifi.router"
    case "119", "120":
      return "wifi.router"
    case "3":
      return "wifi.router"
    case "104", "105", "108", "114", "117":
      return "wifi.router"
    default:
      return topologySymbolNameFromDisplayedText
    }
  }

  private var topologySymbolNameFromDisplayedText: String {
    let text = "\(displayModelName) \(displayName)"
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    if text.contains("express") {
      return "wifi"
    }
    return "wifi.router"
  }
}

enum DevicePopoverPresentationPolicy {
  static func shouldPresentDeviceDetails() -> Bool {
    true
  }

  static var connectionPromptMode: ConnectionPopover.Mode {
    .passwordOnly
  }
}

struct OtherWiFiDevicesMenu: View {
  static let title = "Other Wi-Fi Devices"
  static let connectTitle = "Connect to Base Station..."
  static let placeholderTitle = "No new Wi-Fi devices discovered"
  static let networkInterfacesTitle = "Network Interfaces"
  static let defaultNetworkInterface = "Ethernet 1"
  static let networkInterfaceTitles = ["Ethernet 1", "Wi-Fi"]

  var showConnectItem: Bool
  var devices: [AirportDiscoveredDevice]
  var selectedDeviceID: String?
  var selectedNetworkInterfaceTitle: String
  var onConnect: () -> Void
  var onSelectDeviceID: (String) -> Void
  var onSelectNetworkInterface: (String) -> Void

  var body: some View {
    Menu {
      Text(Self.title)
      if showConnectItem {
        Button(Self.connectTitle) { onConnect() }
        Divider()
      }
      if devices.isEmpty {
        Text(Self.placeholderTitle)
      } else {
        ForEach(devices) { device in
          Button {
            onSelectDeviceID(device.id)
          } label: {
            if device.id == selectedDeviceID {
              Label(device.displayName, systemImage: "checkmark")
            } else {
              Text(device.displayName)
            }
          }
        }
      }
      Divider()
      Text(Self.networkInterfacesTitle)
      ForEach(Self.networkInterfaceTitles, id: \.self) { title in
        Button {
          onSelectNetworkInterface(title)
        } label: {
          if title == selectedNetworkInterfaceTitle {
            Label(title, systemImage: "checkmark")
          } else {
            Text(title)
          }
        }
      }
    } label: {
      Text(Self.title)
        .font(.system(size: 13))
    }
    .menuStyle(.borderlessButton)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
    .accessibilityIdentifier("topology.other.wifi.devices")
  }
}

struct TopologyBackground: View {
  var body: some View {
    Color.clear
  }
}

struct TopologyNode: View {
  var symbolName: String
  var title: String
  var subtitle: String?
  var accessibilityTitle: String
  var accessibilityIdentifier: String?
  var imageFrameHeight: CGFloat = 160
  var iconSize: CGFloat = 100
  var imageOffsetY: CGFloat = 0
  var labelTopPadding: CGFloat = 0
  var nodeFrameHeight: CGFloat = 200
  var isSelected = false
  var selectionOutlineSize = AirPortTopologyStyle.selectionOutlineRegular
  var statusColor = AirPortTopologyStatus.normal.color
  var badgeCount = 0
  var badgeText: String?
  var action: (() -> Void)?

  var body: some View {
    ZStack {
      VStack(spacing: 4) {
        Image(systemName: symbolName)
          .resizable()
          .scaledToFit()
          .foregroundStyle(.secondary)
          .frame(width: iconSize, height: iconSize)
          .frame(width: 200, height: imageFrameHeight)
          .overlay {
            if isSelected {
              RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.06))
                .overlay {
                  RoundedRectangle(cornerRadius: 10)
                    .stroke(AirPortTopologyStyle.selectedStroke, lineWidth: 2)
                }
                .shadow(color: AirPortTopologyStyle.selectedGlow, radius: 8, x: 0, y: 3)
                .frame(width: selectionOutlineSize.width, height: selectionOutlineSize.height)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
          }
          .offset(y: imageOffsetY)
        if labelTopPadding > 0 {
          Spacer()
            .frame(height: labelTopPadding)
        }
        HStack(spacing: 7) {
          Circle()
            .fill(
              RadialGradient(
                colors: [Color.white.opacity(0.72), statusColor, statusColor.opacity(0.74)],
                center: .topLeading,
                startRadius: 1,
                endRadius: 7)
            )
            .frame(width: 12, height: 12)
            .overlay {
              Circle()
                .stroke(Color.black.opacity(0.34), lineWidth: 1)
            }
            .shadow(color: statusColor.opacity(0.42), radius: 3, x: 0, y: 0)
          Text(title)
            .font(.headline)
            .foregroundStyle(Color.primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .layoutPriority(1)
          if badgeCount > 0 {
            Text("\(badgeCount)")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.white)
              .monospacedDigit()
              .frame(width: 22, height: 22)
              .background {
                Circle()
                  .fill(Color.red)
              }
              .accessibilityHidden(true)
          }
          if let badgeText, !badgeText.isEmpty {
            Text(badgeText)
              .font(.caption2.weight(.bold))
              .foregroundStyle(.white)
              .frame(width: 34, height: 18)
              .background {
                Capsule()
                  .fill(AirPortTopologyStatus.updating.color)
              }
              .accessibilityHidden(true)
          }
        }
        .frame(width: 184)
        .shadow(color: AirPortTopologyStyle.labelShadow, radius: 2, x: 0, y: 1)
        if let subtitle {
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(Color.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: 184)
            .shadow(color: AirPortTopologyStyle.labelShadow, radius: 2, x: 0, y: 1)
        }
      }
      .frame(width: 200, height: nodeFrameHeight, alignment: .top)
      .accessibilityHidden(true)

      TopologyNodeAccessibilityProxy(
        label: accessibilityTitle, identifier: accessibilityIdentifier, action: action
      )
      .frame(width: 200, height: nodeFrameHeight)
    }
  }
}

private struct TopologyNodeAccessibilityProxy: NSViewRepresentable {
  var label: String
  var identifier: String?
  var action: (() -> Void)?

  func makeNSView(context: Context) -> TopologyNodeAccessibilityView {
    let view = TopologyNodeAccessibilityView()
    view.label = label
    view.identifier = identifier.map { NSUserInterfaceItemIdentifier($0) }
    view.onPress = action
    return view
  }

  func updateNSView(_ nsView: TopologyNodeAccessibilityView, context: Context) {
    nsView.label = label
    nsView.identifier = identifier.map { NSUserInterfaceItemIdentifier($0) }
    nsView.onPress = action
  }
}

private final class TopologyNodeAccessibilityView: NSView {
  var label = ""
  var onPress: (() -> Void)?

  override func hitTest(_ point: NSPoint) -> NSView? {
    self
  }

  override func isAccessibilityElement() -> Bool {
    true
  }

  override func accessibilityRole() -> NSAccessibility.Role? {
    .image
  }

  override func accessibilityTitle() -> String? {
    label
  }

  override func isAccessibilityEnabled() -> Bool {
    true
  }

  override func accessibilityActionNames() -> [NSAccessibility.Action] {
    [.press]
  }

  override func accessibilityPerformPress() -> Bool {
    guard let onPress else {
      return false
    }
    DispatchQueue.main.async {
      onPress()
    }
    return true
  }

  override func mouseDown(with event: NSEvent) {
    onPress?()
  }
}
