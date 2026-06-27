//
//  SettingsView.swift
//  Whisky
//
//  This file is part of Whisky.
//
//  Whisky is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Whisky is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Whisky.
//  If not, see https://www.gnu.org/licenses/.
//

import SwiftUI
import WhiskyKit

struct SettingsView: View {
    @AppStorage("SUEnableAutomaticChecks") var whiskyUpdate = true
    @AppStorage("killOnTerminate") var killOnTerminate = true
    @AppStorage("checkWhiskyWineUpdates") var checkWhiskyWineUpdates = true
    @AppStorage("defaultBottleLocation") var defaultBottleLocation = BottleData.defaultBottleDir

    @State private var wineMode: WhiskyWineInstaller.WineMode = WhiskyWineInstaller.currentMode
    @State private var wineVersion: String = ""
    @State private var showModeConfirmation = false
    @State private var pendingMode: WhiskyWineInstaller.WineMode?
    @State private var isLoadingVersion = false

    var body: some View {
        Form {
            Section("settings.general") {
                Toggle("settings.toggle.kill.on.terminate", isOn: $killOnTerminate)
                ActionView(
                    text: "settings.path",
                    subtitle: defaultBottleLocation.prettyPath(),
                    actionName: "create.browse"
                ) {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.canCreateDirectories = true
                    panel.directoryURL = BottleData.containerDir
                    panel.begin { result in
                        if result == .OK, let url = panel.urls.first {
                            defaultBottleLocation = url
                        }
                    }
                }
            }
            Section("settings.wine.engine") {
                Picker("settings.wine.mode", selection: $wineMode) {
                    Text("settings.wine.mode.whiskywine").tag(WhiskyWineInstaller.WineMode.whiskyWine)
                    Text("settings.wine.mode.crossover").tag(WhiskyWineInstaller.WineMode.crossover)
                }
                .onChange(of: wineMode) { newMode in
                    pendingMode = newMode
                    showModeConfirmation = true
                }

                HStack {
                    Text("settings.wine.version")
                    Spacer()
                    if isLoadingVersion {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(wineVersion.isEmpty ? "—" : wineVersion)
                            .foregroundStyle(.secondary)
                    }
                }

                if wineMode == .crossover && !WhiskyWineInstaller.isCrossOverInstalled() {
                    Label("settings.wine.crossover.not.installed", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }

                if wineMode == .whiskyWine && !WhiskyWineInstaller.isWhiskyWineInstalled() {
                    HStack {
                        Label("settings.wine.whiskywine.not.installed", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button(String(localized: "settings.wine.reinstall")) {
                            NotificationCenter.default.post(name: Notification.Name("WhiskyWineReinstall"), object: nil)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            Section("settings.updates") {
                Toggle("settings.toggle.whisky.updates", isOn: $whiskyUpdate)
                Toggle("settings.toggle.whiskywine.updates", isOn: $checkWhiskyWineUpdates)
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: ViewWidth.medium)
        .onAppear {
            loadWineVersion()
        }
        .alert("settings.wine.change.mode.title", isPresented: $showModeConfirmation) {
            Button("button.cancel", role: .cancel) {
                wineMode = WhiskyWineInstaller.currentMode
                pendingMode = nil
            }
            Button("settings.wine.change.mode.confirm") {
                if let pendingMode = pendingMode {
                    WhiskyWineInstaller.currentMode = pendingMode
                    loadWineVersion()
                }
                pendingMode = nil
            }
        } message: {
            Text("settings.wine.change.mode.message")
        }
    }

    private func loadWineVersion() {
        isLoadingVersion = true
        Task {
            do {
                let version = try await Wine.wineVersion()
                await MainActor.run {
                    wineVersion = version
                    isLoadingVersion = false
                }
            } catch {
                await MainActor.run {
                    wineVersion = ""
                    isLoadingVersion = false
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
