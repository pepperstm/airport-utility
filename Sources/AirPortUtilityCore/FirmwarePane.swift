import SwiftUI
import UniformTypeIdentifiers

struct FirmwarePane: View {
  @EnvironmentObject private var model: AirportAppModel
  @State private var isChoosingFirmwareImage = false
  private static let firmwareContentTypes = [
    UTType(filenameExtension: "basebinary") ?? .data,
    .data,
  ]

  var body: some View {
    DashboardSection(title: "Firmware", icon: "arrow.down.circle") {
      VStack(alignment: .leading, spacing: 12) {
        PaneFieldRow("Version") {
          Text(currentVersionText)
            .accessibilityIdentifier("firmware.current.version")
        }
        PaneFieldRow("Available Firmware") {
          Picker("", selection: $model.firmware.selectedImageID) {
            if model.firmware.images.isEmpty {
              Text("No firmware images loaded").tag("")
            } else {
              ForEach(model.firmware.images) { image in
                Text(image.displayName).tag(image.id)
              }
            }
          }
          .pickerStyle(.menu)
          .labelsHidden()
          .accessibilityIdentifier("firmware.available")
          .disabled(model.firmware.images.isEmpty || model.isBusy)
        }
        HStack {
          Button("Check for Updates") {
            model.refreshFirmwareImages()
          }
          .buttonStyle(.bordered)
          .disabled(model.isBusy)
          .accessibilityIdentifier("firmware.check.for.updates")
          Button("Choose…") {
            isChoosingFirmwareImage = true
          }
          .buttonStyle(.bordered)
          .disabled(model.isBusy)
          .accessibilityIdentifier("firmware.choose.image")
          Spacer()
          Button(installButtonTitle) {
            model.installSelectedFirmware()
          }
          .buttonStyle(.borderedProminent)
          .disabled(!canInstall)
          .accessibilityIdentifier("firmware.install")
        }
        if !model.firmware.lastError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text(model.firmware.lastError)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .accessibilityIdentifier("firmware.last.error")
        }
        if !model.firmware.installStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text(model.firmware.installStatus)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .accessibilityIdentifier("firmware.install.status")
        }
        if model.firmware.transferProgress.isVisible {
          PaneFieldRow("Progress") {
            VStack(alignment: .leading, spacing: 5) {
              HStack(spacing: 6) {
                Text(model.firmware.transferProgress.phase.label)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  .accessibilityIdentifier("firmware.transfer.phase")
                Spacer()
                if !model.firmware.transferProgress.percentText.isEmpty {
                  Text(model.firmware.transferProgress.percentText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .accessibilityIdentifier("firmware.transfer.percent")
                }
              }
              firmwareProgressView
              if !model.firmware.transferProgress.detail.isEmpty {
                Text(model.firmware.transferProgress.detail)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  .accessibilityIdentifier("firmware.transfer.detail")
              }
            }
          }
        }
      }
    }
    .fileImporter(
      isPresented: $isChoosingFirmwareImage,
      allowedContentTypes: Self.firmwareContentTypes,
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        guard let url = urls.first else { return }
        model.chooseFirmwareImage(at: url)
      case .failure(let error):
        model.chooseFirmwareImageFailed(error)
      }
    }
    .onAppear {
      if !model.firmware.hasLoadedImages && !model.isBusy {
        model.refreshFirmwareImages()
      }
    }
  }

  private var currentVersionText: String {
    let version = model.firmware.currentVersion.trimmingCharacters(in: .whitespacesAndNewlines)
    return version.isEmpty ? "Unknown" : version
  }

  private var canInstall: Bool {
    !model.isBusy && model.firmware.selectedImage != nil
  }

  private var installButtonTitle: String {
    guard let image = model.firmware.selectedImage else { return "Install" }
    return image.version == model.firmware.currentVersion ? "Reinstall" : "Install"
  }

  @ViewBuilder
  private var firmwareProgressView: some View {
    if let fraction = model.firmware.transferProgress.fraction {
      ProgressView(value: fraction, total: 1)
        .progressViewStyle(.linear)
    } else {
      ProgressView()
        .progressViewStyle(.linear)
    }
  }
}
