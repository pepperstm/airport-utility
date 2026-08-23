// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Graham Barber

import SwiftUI

struct SitesSheet: View {
  @EnvironmentObject private var model: AirportAppModel

  @State private var isAddingSite = false
  @State private var addSiteDraft = ""
  @State private var renamingSite: Site?
  @State private var renameDraft = ""

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Sites")
            .font(.largeTitle)
            .fontWeight(.semibold)

          Text("Saved connections you can switch back to later")
            .foregroundStyle(.secondary)
        }

        DashboardSection(title: "Sites", icon: "building.2") {
          if sortedSites.isEmpty {
            Text("No saved sites yet")
              .foregroundStyle(.secondary)
          } else {
            ForEach(Array(sortedSites.enumerated()), id: \.element.id) { index, site in
              if index > 0 { Divider() }
              siteRow(site)
            }
          }

          Divider()

          Button("Add Current Connection…") {
            addSiteDraft = defaultSiteName
            isAddingSite = true
          }
          .disabled(!model.liveCredentialsAvailable)
          .accessibilityIdentifier("sites.add")
        }

        DashboardSection(title: "Connect to Other Base Station", icon: "personalhotspot") {
          connectToOtherContent
        }
      }
      .padding(24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .alert("Add Site", isPresented: $isAddingSite) {
      TextField("Name", text: $addSiteDraft)
      Button("Cancel", role: .cancel) {}
      Button("Save") { model.saveCurrentConnectionAsSite(name: addSiteDraft) }
    } message: {
      Text("Remembers the current connection so you can switch back to it later.")
    }
    .alert("Rename Site", isPresented: renamingSiteBinding) {
      TextField("Name", text: $renameDraft)
      Button("Cancel", role: .cancel) {}
      Button("Save") {
        if let renamingSite {
          model.renameSite(renamingSite, to: renameDraft)
        }
      }
    }
  }

  @ViewBuilder
  private var connectToOtherContent: some View {
    if model.isShowingConfigureOther {
      VStack(alignment: .leading, spacing: 12) {
        PaneFieldRow("Host") {
          AirPortTextField(
            text: $model.connection.host,
            placeholder: "Host",
            identifier: "configure.other.host")
        }
        PaneFieldRow("Password") {
          AirPortSecureField(
            text: $model.connection.password,
            placeholder: "Password",
            identifier: "configure.other.password",
            onSubmit: submitConfigureOtherConnection)
            .frame(height: 24)
        }
        if !model.mockMode {
          PaneFieldRow("Repository") {
            AirPortTextField(
              text: $model.connection.repoPath,
              placeholder: "Repository",
              identifier: "configure.other.repository")
          }
        }
        Toggle(
          "Remember this password in my keychain",
          isOn: Binding(
            get: { model.rememberConnectionPassword },
            set: { model.updateRememberConnectionPassword($0) })
        )
        .accessibilityIdentifier("configure.other.remember.password")

        if !model.status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text(model.status)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        HStack {
          Spacer()
          Button("Cancel") {
            model.isShowingConfigureOther = false
          }
          .accessibilityIdentifier("configure.other.cancel")
          Button(model.isBusy ? "Working" : "Connect") {
            submitConfigureOtherConnection()
          }
          .accessibilityIdentifier("configure.other.connect")
          .keyboardShortcut(.defaultAction)
          .disabled(!model.canAttemptConnection)
        }
      }
    } else {
      Button("Connect to Other Base Station…") {
        model.isShowingConfigureOther = true
      }
      .accessibilityIdentifier("sites.connect.other.open")
    }
  }

  private func submitConfigureOtherConnection() {
    guard model.canAttemptConnection else { return }
    model.refresh()
  }

  private var sortedSites: [Site] {
    model.sites.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  private var defaultSiteName: String {
    let baseStationName = model.baseStation.name.trimmingCharacters(in: .whitespacesAndNewlines)
    if !baseStationName.isEmpty { return baseStationName }
    return model.selectedTopologyDevice()?.displayName ?? ""
  }

  private var renamingSiteBinding: Binding<Bool> {
    Binding(get: { renamingSite != nil }, set: { if !$0 { renamingSite = nil } })
  }

  private func siteRow(_ site: Site) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(site.name)
          .font(.system(size: 13, weight: .medium))
        Text(lastConnectedText(site))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Button("Connect") {
        model.connectToSite(site)
        model.showDashboard()
      }
      .disabled(model.isBusy)
      .accessibilityIdentifier("sites.connect.\(site.id)")
    }
    .padding(.vertical, 6)
    .contentShape(Rectangle())
    .contextMenu {
      Button("Rename…") {
        renameDraft = site.name
        renamingSite = site
      }
      Button("Remove", role: .destructive) {
        model.removeSite(site)
      }
    }
  }

  private func lastConnectedText(_ site: Site) -> String {
    guard let lastConnectedDate = site.lastConnectedDate else { return "Never connected" }
    return "Last connected \(lastConnectedDate.formatted(date: .abbreviated, time: .shortened))"
  }
}
