//
//  WelcomeView.swift
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

struct WelcomeView: View {
    @State var rosettaInstalled: Bool?
    @State var whiskyWineInstalled: Bool?
    @State var currentModeInstalled: Bool?
    @State var shouldCheckInstallStatus: Bool = false
    @Binding var path: [SetupStage]
    @Binding var showSetup: Bool
    var firstTime: Bool
    @Binding var installMode: WhiskyWineInstaller.WineMode

    private var currentMode: WhiskyWineInstaller.WineMode {
        WhiskyWineInstaller.currentMode
    }

    private var showCurrentModeStatus: Bool {
        currentMode != .whiskyWine
    }

    private var currentModeName: String {
        switch currentMode {
        case .whiskyWine:
            return String(localized: "settings.wine.mode.whiskywine")
        case .crossover:
            return String(localized: "settings.wine.mode.crossover")
        case .proton11:
            return String(localized: "settings.wine.mode.proton11")
        case .proton10:
            return String(localized: "settings.wine.mode.proton10")
        }
    }

    private var canProceed: Bool {
        guard let rosettaInstalled = rosettaInstalled,
              let whiskyWineInstalled = whiskyWineInstalled else {
            return false
        }
        if !rosettaInstalled || !whiskyWineInstalled {
            return false
        }
        if showCurrentModeStatus {
            guard let currentModeInstalled = currentModeInstalled else {
                return false
            }
            if !currentModeInstalled && !currentMode.isDownloadable {
                return false
            }
        }
        return true
    }

    var body: some View {
        VStack {
            VStack {
                if firstTime {
                    Text("setup.welcome")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("setup.welcome.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("setup.title")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("setup.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            Spacer()
            Form {
                InstallStatusView(isInstalled: $rosettaInstalled,
                                  shouldCheckInstallStatus: $shouldCheckInstallStatus,
                                  name: "Rosetta")
                InstallStatusView(isInstalled: $whiskyWineInstalled,
                                  shouldCheckInstallStatus: $shouldCheckInstallStatus,
                                  showUninstall: true,
                                  name: "WhiskyWine")
                if showCurrentModeStatus {
                    InstallStatusView(isInstalled: $currentModeInstalled,
                                      shouldCheckInstallStatus: $shouldCheckInstallStatus,
                                      name: currentModeName)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .onAppear {
                checkInstallStatus()
            }
            .onChange(of: shouldCheckInstallStatus) {
                checkInstallStatus()
            }
            Spacer()
            HStack {
                if let rosettaInstalled = rosettaInstalled,
                   let whiskyWineInstalled = whiskyWineInstalled {
                    if !rosettaInstalled || !whiskyWineInstalled {
                        Button("setup.quit") {
                            exit(0)
                        }
                        .keyboardShortcut(.cancelAction)
                    }
                    Spacer()
                    Button(canProceed ? "setup.done" : "setup.next") {
                        if !rosettaInstalled {
                            path.append(.rosetta)
                            return
                        }

                        if !whiskyWineInstalled {
                            installMode = .whiskyWine
                            path.append(.whiskyWineDownload)
                            return
                        }

                        if showCurrentModeStatus,
                           let currentModeInstalled = currentModeInstalled,
                           !currentModeInstalled {
                            if currentMode.isDownloadable {
                                installMode = currentMode
                                path.append(.whiskyWineDownload)
                                return
                            } else {
                                return
                            }
                        }

                        showSetup = false
                    }
                    .disabled(!canProceed && !(whiskyWineInstalled == false))
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(width: 400, height: showCurrentModeStatus ? 260 : 200)
    }

    func checkInstallStatus() {
        rosettaInstalled = Rosetta2.isRosettaInstalled
        whiskyWineInstalled = WhiskyWineInstaller.isWhiskyWineInstalled()
        if showCurrentModeStatus {
            currentModeInstalled = WhiskyWineInstaller.isInstalled(mode: currentMode)
        }
    }
}

struct InstallStatusView: View {
    @Binding var isInstalled: Bool?
    @Binding var shouldCheckInstallStatus: Bool
    @State var showUninstall: Bool = false
    @State var name: String
    @State var text: String = String(localized: "setup.install.checking")

    var body: some View {
        HStack {
            Group {
                if let installed = isInstalled {
                    Circle()
                        .foregroundColor(installed ? .green : .red)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(width: 10)
            Text(String.init(format: text, name))
            Spacer()
            if let installed = isInstalled {
                if installed && showUninstall {
                    Button("setup.uninstall") {
                        uninstall()
                    }
                }
            }
        }
        .onChange(of: isInstalled) {
            if let installed = isInstalled {
                if installed {
                    text = String(localized: "setup.install.installed")
                } else {
                    text = String(localized: "setup.install.notInstalled")
                }
            } else {
                text = String(localized: "setup.install.checking")
            }
        }
    }

    func uninstall() {
        if name == "WhiskyWine" {
            WhiskyWineInstaller.uninstall()
        }

        shouldCheckInstallStatus.toggle()
    }
}
