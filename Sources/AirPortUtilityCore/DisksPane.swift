import AppKit
import SwiftUI

struct DisksPane: View {
  @EnvironmentObject private var model: AirportAppModel
  @State private var showErase = false
  @State private var showArchive = false

  var body: some View {
    DashboardSection(title: "Disks", icon: "externaldrive") {
      VStack(alignment: .leading, spacing: 12) {
        DiskInventoryList(
          records: model.disks.inventory,
          selectedID: $model.disks.selectedDiskID,
          didLoadInventory: model.disks.didLoadInventory,
          isLoading: isLoadingDiskInventory)
        HStack {
          Button("Erase Disk…") {
            showErase = true
          }
          .buttonStyle(.bordered)
          .disabled(selectedDisk == nil)
          .accessibilityIdentifier("disks.erase.open")
          Spacer()
          Button("Archive Disk…") {
            showArchive = true
          }
          .buttonStyle(.bordered)
          .disabled(!canArchiveDisk)
          .accessibilityIdentifier("disks.archive.open")
        }
        Toggle("Enable file sharing", isOn: $model.disks.fileSharing)
          .accessibilityIdentifier("disks.file.sharing")
        PaneFieldRow("Secure Shared Disks") {
          Picker("", selection: $model.disks.secureSharedDisks) {
            Text("With accounts").tag("accounts")
            Text("With a disk password").tag("disk-password")
            Text("With device password").tag("device-password")
          }
          .pickerStyle(.menu)
          .labelsHidden()
          .accessibilityIdentifier("disks.secure.shared.disks")
        }
        if model.disks.secureSharedDisks == "disk-password" {
          PaneFieldRow("Disk Password") {
            AirPortSecureField(
              text: $model.disks.diskPassword,
              placeholder: "Disk password",
              identifier: "disks.disk.password")
              .frame(height: 24)
          }
          PaneFieldRow("Verify Password") {
            AirPortSecureField(
              text: $model.disks.verifyDiskPassword,
              placeholder: "Verify disk password",
              identifier: "disks.verify.password")
              .frame(height: 24)
          }
        }
        if model.disks.secureSharedDisks == "accounts" {
          PaneFieldRow("Accounts") {
            DiskAccountsEditor(
              accounts: $model.disks.fileSharingAccounts,
              selectedID: $model.disks.selectedFileSharingAccountID,
              isEnabled: model.supportsDiskFileSharingAccountEditing)
          }
          if model.supportsDiskFileSharingAccountEditing,
            let selectedAccount = selectedFileSharingAccountBinding
          {
            PaneFieldRow("Account Name") {
              AirPortTextField(
                text: selectedAccount.name,
                placeholder: "Account name",
                identifier: "disks.account.name")
                .frame(height: 24)
            }
            PaneFieldRow("Password") {
              AirPortSecureField(
                text: selectedAccount.password,
                placeholder: "Account password",
                identifier: "disks.account.password")
                .frame(height: 24)
            }
            PaneFieldRow("Verify Password") {
              AirPortSecureField(
                text: selectedAccount.verifyPassword,
                placeholder: "Verify account password",
                identifier: "disks.account.verify.password")
                .frame(height: 24)
            }
            PaneFieldRow("File Sharing Access") {
              Picker("", selection: selectedAccount.access) {
                Text("Read and Write").tag("read-write")
                Text("Read Only").tag("read-only")
                Text("Not Allowed").tag("not-allowed")
              }
              .pickerStyle(.menu)
              .labelsHidden()
              .accessibilityIdentifier("disks.account.file.sharing.access")
            }
          }
        } else {
          Toggle(
            "Remember this password in my keychain",
            isOn: Binding(
              get: { model.remembersCurrentDiskPassword },
              set: { model.updateRememberCurrentDiskPassword($0) })
          )
          .accessibilityIdentifier("disks.remember.password")
        }
      }
    }
    .sheet(isPresented: $showErase) {
      EraseDiskSheet()
        .environmentObject(model)
    }
    .sheet(isPresented: $showArchive) {
      ArchiveDiskSheet()
        .environmentObject(model)
    }
  }

  private var isLoadingDiskInventory: Bool {
    model.isBusy && !model.disks.didLoadInventory
  }

  private var selectedDisk: DiskRecord? {
    Self.selectedDisk(in: model.disks)
  }

  private var canArchiveDisk: Bool {
    Self.canArchiveDisk(in: model.disks)
  }

  private var selectedFileSharingAccountBinding: (
    name: Binding<String>,
    password: Binding<String>,
    verifyPassword: Binding<String>,
    access: Binding<String>
  )? {
    guard
      let index = model.disks.fileSharingAccounts.firstIndex(where: {
        $0.id == model.disks.selectedFileSharingAccountID
      })
    else { return nil }
    return (
      name: Binding(
        get: { model.disks.fileSharingAccounts[index].name },
        set: { model.disks.fileSharingAccounts[index].name = $0 }),
      password: Binding(
        get: { model.disks.fileSharingAccounts[index].password },
        set: { model.disks.fileSharingAccounts[index].password = $0 }),
      verifyPassword: Binding(
        get: { model.disks.fileSharingAccounts[index].verifyPassword },
        set: { model.disks.fileSharingAccounts[index].verifyPassword = $0 }),
      access: Binding(
        get: { model.disks.fileSharingAccounts[index].access },
        set: { model.disks.fileSharingAccounts[index].access = $0 })
    )
  }

  nonisolated static func selectedDisk(in disks: DisksState) -> DiskRecord? {
    disks.inventory.first { $0.id == disks.selectedDiskID }
  }

  nonisolated static func canArchiveDisk(in disks: DisksState) -> Bool {
    disks.inventory.contains { $0.builtIn } && disks.inventory.contains { !$0.builtIn }
  }
}

private struct DiskAccountsEditor: View {
  @Binding var accounts: [DiskAccount]
  @Binding var selectedID: String
  var isEnabled: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      VStack(spacing: 0) {
        HStack {
          Text("Account Name")
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Color.primary.opacity(0.06))

        if accounts.isEmpty {
          HStack {
            Spacer()
          }
          .frame(height: 50)
          .background(Color.primary.opacity(0.03))
        } else {
          VStack(spacing: 0) {
            ForEach(accounts.indices, id: \.self) { index in
              DiskAccountRow(
                name: accountNameBinding(for: index),
                isSelected: accounts[index].id == selectedID,
                isEnabled: isEnabled,
                identifier: "disks.accounts.row.\(index).name"
              ) {
                if isEnabled {
                  selectedID = accounts[index].id
                }
              }
            }
            Spacer(minLength: accounts.count < 2 ? 25 : 0)
          }
          .frame(height: 50)
          .background(Color.primary.opacity(0.03))
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 6))

      HStack(spacing: 6) {
        Button("+") {
          addAccount()
        }
        .buttonStyle(.bordered)
        .disabled(!isEnabled)
        .accessibilityIdentifier("disks.accounts.add")
        Button("-") {
          deleteSelectedAccount()
        }
        .buttonStyle(.bordered)
        .disabled(!isEnabled || selectedAccountIndex == nil)
        .accessibilityIdentifier("disks.accounts.remove")
      }
    }
    .onAppear(perform: reconcileSelection)
    .onChange(of: accounts) { _ in
      reconcileSelection()
    }
  }

  private var selectedAccountIndex: Int? {
    accounts.firstIndex { $0.id == selectedID }
  }

  private func accountNameBinding(for index: Int) -> Binding<String> {
    Binding(
      get: {
        guard accounts.indices.contains(index) else { return "" }
        return accounts[index].name
      },
      set: { newValue in
        guard accounts.indices.contains(index) else { return }
        accounts[index].name = newValue
      })
  }

  private func addAccount() {
    let account = DiskAccount(name: nextAccountName())
    accounts.append(account)
    selectedID = account.id
  }

  private func deleteSelectedAccount() {
    guard let index = selectedAccountIndex else { return }
    accounts.remove(at: index)
    reconcileSelection()
  }

  private func reconcileSelection() {
    guard let firstAccount = accounts.first else {
      selectedID = ""
      return
    }
    if !accounts.contains(where: { $0.id == selectedID }) {
      selectedID = firstAccount.id
    }
  }

  private func nextAccountName() -> String {
    let existingNames = Set(accounts.map(\.name))
    var index = accounts.count + 1
    while existingNames.contains("Account \(index)") {
      index += 1
    }
    return "Account \(index)"
  }
}

private struct DiskAccountRow: View {
  @Binding var name: String
  var isSelected: Bool
  var isEnabled: Bool
  var identifier: String?
  var select: () -> Void

  var body: some View {
    TextField("", text: $name)
      .textFieldStyle(.plain)
      .font(.caption)
      .foregroundStyle(isEnabled ? .primary : .secondary)
      .padding(.horizontal, 8)
      .frame(height: 25)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(isSelected ? Color.accentColor.opacity(0.35) : Color.clear)
      .disabled(!isEnabled)
      .contentShape(Rectangle())
      .onTapGesture(perform: select)
      .accessibilityLabel(name.isEmpty ? "File sharing account" : name)
      .accessibilityValue(isSelected ? "selected" : "")
      .accessibilityIdentifier(identifier ?? "")
  }
}

struct DiskInventoryList: View {
  var records: [DiskRecord]
  @Binding var selectedID: String
  var didLoadInventory = false
  var isLoading = false

  var body: some View {
    PaneFieldRow("Partitions") {
      if records.isEmpty {
        Text(emptyStateText)
          .foregroundStyle(.secondary)
      } else {
        VStack(spacing: 0) {
          ForEach(records) { record in
            Button {
              selectedID = record.id
            } label: {
              DiskInventoryRow(record: record, isSelected: selectedID == record.id)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(record.name)
            .accessibilityValue(selectedID == record.id ? "selected" : "")
            .accessibilityIdentifier("disks.partition.\(record.id)")
          }
          Spacer(minLength: records.count < 2 ? 56 : 0)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
      }
    }
    .onAppear(perform: reconcileSelection)
    .onChange(of: records) { _ in
      reconcileSelection()
    }
  }

  private var emptyStateText: String {
    Self.emptyStateText(didLoadInventory: didLoadInventory, isLoading: isLoading)
  }

  private func reconcileSelection() {
    guard let firstRecord = records.first else {
      selectedID = ""
      return
    }
    if !records.contains(where: { $0.id == selectedID }) {
      selectedID = firstRecord.id
    }
  }

  nonisolated static func emptyStateText(didLoadInventory: Bool, isLoading: Bool) -> String {
    if isLoading {
      return "Loading disk information..."
    }
    if didLoadInventory {
      return "No disk partitions found."
    }
    return "No disk information loaded."
  }
}

private struct DiskInventoryRow: View {
  var record: DiskRecord
  var isSelected: Bool

  var body: some View {
    HStack(spacing: 6) {
      airPortResourceImage(named: iconResourceName, fallbackSystemName: iconFallbackSystemName)
        .resizable()
        .scaledToFit()
        .frame(width: 50, height: 50)
        .accessibilityLabel(iconAccessibilityLabel)
      VStack(alignment: .leading, spacing: 3) {
        Text(record.name)
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
          .truncationMode(.tail)
        if let free = record.sizeFree {
          Text("\(ByteCountFormatter.string(fromByteCount: free, countStyle: .file)) Free")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Spacer()
    }
    .padding(.horizontal, 8)
    .frame(height: 56)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(isSelected ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.06))
    .contentShape(Rectangle())
  }

  private var iconResourceName: String {
    record.builtIn ? "AirDisk.icns" : "Drives.icns"
  }

  private var iconFallbackSystemName: String {
    record.builtIn ? "internaldrive" : "externaldrive"
  }

  private var iconAccessibilityLabel: String {
    record.builtIn ? "AirDisk" : "Drives"
  }
}
