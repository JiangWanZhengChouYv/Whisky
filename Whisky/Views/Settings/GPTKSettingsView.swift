//
//  GPTKSettingsView.swift
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

struct GPTKSettingsView: View {
    var onInstalled: (() -> Void)?
    var refreshTrigger: Int = 0

    @State private var isInstalled: Bool?
    @State private var isGPTKInstalling = false
    @State private var gptkProgress: Double = 0
    @State private var gptkTotalBytes: Int64 = 0
    @State private var gptkCompletedBytes: Int64 = 0
    @State private var gptkError: String?

    private var currentMode: WhiskyWineInstaller.WineMode {
        WhiskyWineInstaller.currentMode
    }

    private var buttonText: String {
        if isGPTKInstalling {
            return String(localized: "gptk.installing")
        }
        if let isInstalled = isInstalled, isInstalled {
            return String(localized: "gptk.reinstall")
        }
        return String(localized: "gptk.install")
    }

    private var showUninstallButton: Bool {
        if let isInstalled = isInstalled, isInstalled, !isGPTKInstalling {
            return true
        }
        return false
    }

    var body: some View {
        Section("GPTK") {
            if currentMode == .crossover {
                VStack(alignment: .leading, spacing: 4) {
                    Text("gptk.crossoverGraphic")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Text("gptk.crossoverNotNeeded")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .lineLimit(2)
                }
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Text("gptk.title")
                        Spacer()
                        if let isInstalled = isInstalled {
                            if isInstalled {
                                Label("gptk.installed", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Label("gptk.notInstalled", systemImage: "questionmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    if isGPTKInstalling {
                        VStack(spacing: 6) {
                            ProgressView(value: gptkProgress)
                                .progressViewStyle(.linear)
                            HStack {
                                Text(formatBytes(gptkCompletedBytes))
                                Spacer()
                                Text(formatBytes(gptkTotalBytes))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    if let gptkError = gptkError {
                        Text(gptkError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }

                    HStack {
                        Spacer()
                        Button(buttonText) {
                            installGPTK()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isGPTKInstalling)

                        if showUninstallButton {
                            Button("gptk.uninstall") {
                                uninstallGPTK()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.red)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .onAppear {
            refreshStatus()
        }
        .onChange(of: refreshTrigger) { _ in
            refreshStatus()
        }
    }

    private func refreshStatus() {
        isInstalled = WhiskyWineInstaller.isGPTKInstalled(mode: currentMode)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func installGPTK() {
        isGPTKInstalling = true
        gptkError = nil
        gptkProgress = 0
        gptkCompletedBytes = 0
        gptkTotalBytes = 0

        let mode = currentMode
        let downloader = WhiskyWineDownloader(
            downloadURL: WhiskyWineInstaller.gptkDownloadURL,
            cacheFileName: "GPTK.tar.gz",
            totalBytesHandler: { total in
                Task { @MainActor in
                    self.gptkTotalBytes = total
                }
            },
            progressHandler: { completed, total in
                Task { @MainActor in
                    self.gptkCompletedBytes = completed
                    if total > 0 {
                        self.gptkProgress = Double(completed) / Double(total)
                    }
                }
            },
            completionHandler: { tarURL in
                Task { @MainActor in
                    do {
                        try WhiskyWineInstaller.installGPTK(from: tarURL, mode: mode)
                        self.isInstalled = true
                        self.isGPTKInstalling = false
                        self.onInstalled?()
                    } catch {
                        self.gptkError = String(format: String(localized: "gptk.installFailedError"),
                                                error.localizedDescription)
                        self.isGPTKInstalling = false
                    }
                }
            },
            errorHandler: { error in
                Task { @MainActor in
                    self.gptkError = String(format: String(localized: "gptk.downloadFailedError"),
                                            error.localizedDescription)
                    self.isGPTKInstalling = false
                }
            }
        )
        downloader.start()
    }

    private func uninstallGPTK() {
        let mode = currentMode
        Task {
            do {
                try WhiskyWineInstaller.uninstallGPTK(mode: mode)
                Task { @MainActor in
                    self.isInstalled = false
                    self.gptkError = nil
                }
            } catch {
                Task { @MainActor in
                    self.gptkError = String(format: String(localized: "gptk.uninstallFailedError"),
                                            error.localizedDescription)
                }
            }
        }
    }
}

#Preview {
    GPTKSettingsView()
}