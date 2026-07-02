//
//  DXVKSettingsView.swift
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

struct DXVKSettingsView: View {
    var onInstalled: (() -> Void)?
    var refreshTrigger: Int = 0

    @State private var isInstalled: Bool?
    @State private var isDXVKInstalling = false
    @State private var dxvkProgress: Double = 0
    @State private var dxvkTotalBytes: Int64 = 0
    @State private var dxvkCompletedBytes: Int64 = 0
    @State private var dxvkError: String?

    private var currentMode: WhiskyWineInstaller.WineMode {
        WhiskyWineInstaller.currentMode
    }
    private var buttonText: String {
        if isDXVKInstalling {
            return "安装中..."
        }
        if let isInstalled = isInstalled, isInstalled {
            return "重新安装 DXVK"
        }
        return "安装 DXVK"
    }

    private var showUninstallButton: Bool {
        if let isInstalled = isInstalled, isInstalled, !isDXVKInstalling {
            return true
        }
        return false
    }

    var body: some View {
        Section("DXVK") {
            if currentMode == .crossover {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CrossOver 模式使用自带的图形加速方案")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Text("CrossOver 已内置 D3DM 图形驱动和 Apple GPTK 支持，无需额外安装 DXVK")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .lineLimit(2)
                }
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Text("DXVK (DX10/DX11 硬件加速)")
                        Spacer()
                        if let isInstalled = isInstalled {
                            if isInstalled {
                                Label("已安装", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Label("未安装", systemImage: "questionmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    if isDXVKInstalling {
                        VStack(spacing: 6) {
                            ProgressView(value: dxvkProgress)
                                .progressViewStyle(.linear)
                            HStack {
                                Text(formatBytes(dxvkCompletedBytes))
                                Spacer()
                                Text(formatBytes(dxvkTotalBytes))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    if let dxvkError = dxvkError {
                        Text(dxvkError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }

                    HStack {
                        Spacer()
                        Button(buttonText) {
                            installDXVK()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isDXVKInstalling)

                        if showUninstallButton {
                            Button("卸载 DXVK") {
                                uninstallDXVK()
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
        isInstalled = WhiskyWineInstaller.isDXVKInstalled(mode: currentMode)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func installDXVK() {
        isDXVKInstalling = true
        dxvkError = nil
        dxvkProgress = 0
        dxvkCompletedBytes = 0
        dxvkTotalBytes = 0

        let mode = currentMode
        print("[DXVK] Starting install for mode: \(mode.rawValue)")
        let downloader = WhiskyWineDownloader(
            downloadURL: WhiskyWineInstaller.dxvkDownloadURL,
            cacheFileName: "DXVK.tar.gz",
            totalBytesHandler: { total in
                Task { @MainActor in
                    self.dxvkTotalBytes = total
                }
            },
            progressHandler: { completed, total in
                Task { @MainActor in
                    self.dxvkCompletedBytes = completed
                    if total > 0 {
                        self.dxvkProgress = Double(completed) / Double(total)
                    }
                }
            },
            completionHandler: { tarURL in
                Task { @MainActor in
                    do {
                        try WhiskyWineInstaller.installDXVK(from: tarURL, mode: mode)
                        self.isInstalled = true
                        self.isDXVKInstalling = false
                        self.onInstalled?()
                    } catch {
                        self.dxvkError = "安装失败: \(error.localizedDescription)"
                        self.isDXVKInstalling = false
                    }
                }
            },
            errorHandler: { error in
                Task { @MainActor in
                    self.dxvkError = "下载失败: \(error.localizedDescription)"
                    self.isDXVKInstalling = false
                }
            }
        )
        downloader.start()
    }

    private func uninstallDXVK() {
        let mode = currentMode
        print("[DXVK] Starting uninstall for mode: \(mode.rawValue)")
        Task {
            do {
                try WhiskyWineInstaller.uninstallDXVK(mode: mode)
                Task { @MainActor in
                    self.isInstalled = false
                    self.dxvkError = nil
                }
            } catch {
                Task { @MainActor in
                    self.dxvkError = "卸载失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    DXVKSettingsView()
}
