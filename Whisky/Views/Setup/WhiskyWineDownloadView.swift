//
//  WhiskyWineDownloadView.swift
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

struct WhiskyWineDownloadView: View {
    @State private var fractionProgress: Double = 0
    @State private var completedBytes: Int64 = 0
    @State private var totalBytes: Int64 = 0
    @State private var downloadSpeed: Double = 0
    @State private var startTime: Date?
    @State private var errorMessage: String?
    @Binding var tarLocation: URL
    @Binding var path: [SetupStage]

    @State private var downloadManager: WhiskyWineDownloader?

    var body: some View {
        VStack {
            VStack {
                Text("setup.whiskywine.download")
                    .font(.title)
                    .fontWeight(.bold)
                Text("setup.whiskywine.download.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let errorMessage = errorMessage {
                    VStack(spacing: 8) {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .multilineTextAlignment(.center)
                        Button("install.viewLog") {
                            WhiskyApp.showErrorLog(
                                title: String(localized: "install.errorTitle"),
                                message: errorMessage
                            )
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal)
                }
                Spacer()
                VStack {
                    ProgressView(value: fractionProgress, total: 1)
                    HStack {
                        HStack {
                            Text(String(format: String(localized: "setup.whiskywine.progress"),
                                        formatBytes(bytes: completedBytes),
                                        formatBytes(bytes: totalBytes)))
                            + Text(String(" "))
                            + (shouldShowEstimate()
                               ? Text(String(format: String(localized: "setup.whiskywine.eta"),
                                           formatRemainingTime(
                                               remainingBytes: max(0, totalBytes - completedBytes))))
                               : Text(String()))
                            Spacer()
                        }
                        .font(.subheadline)
                        .monospacedDigit()
                    }
                }
                .padding(.horizontal)
                Spacer()
            }
            Spacer()
        }
        .frame(width: 400, height: 280)
        .onAppear {
            Task {
                await startDownload()
            }
        }
    }

    private func startDownload() async {
        guard let url = URL(string: WhiskyWineInstaller.whiskyWineBaseURL + "Libraries.tar.gz") else {
            errorMessage = "Invalid download URL"
            return
        }

        startTime = Date()

        let manager = WhiskyWineDownloader(
            downloadURL: url,
            totalBytesHandler: { [self] total in
                if totalBytes == 0 { totalBytes = total }
            },
            progressHandler: { [self] completed, total in
                completedBytes = completed
                if total > 0 {
                    totalBytes = total
                }
                fractionProgress = totalBytes > 0 ? Double(completedBytes) / Double(totalBytes) : 0
                if let start = startTime {
                    let elapsed = Date().timeIntervalSince(start)
                    if elapsed > 0 {
                        downloadSpeed = Double(completedBytes) / elapsed
                    }
                }
            },
            completionHandler: { [self] resultURL in
                tarLocation = resultURL
                path.append(.whiskyWineInstall)
            },
            errorHandler: { [self] error in
                errorMessage = "Download failed: \(error.safeLocalizedDescription)"
            }
        )
        downloadManager = manager
        manager.start()
    }

    private func formatBytes(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.zeroPadsFractionDigits = true
        return formatter.string(fromByteCount: bytes)
    }

    private func shouldShowEstimate() -> Bool {
        let elapsedTime = Date().timeIntervalSince(startTime ?? Date())
        return Int(elapsedTime.rounded()) > 5 && completedBytes != 0
    }

    private func formatRemainingTime(remainingBytes: Int64) -> String {
        let remainingTimeInSeconds = Double(remainingBytes) / downloadSpeed
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .full
        return formatter.string(from: TimeInterval(remainingTimeInSeconds)) ?? ""
    }
}
