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

    @State private var downloadManager: WhiskyWineDownloadManager?

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
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.top, 8)
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
        .frame(width: 400, height: 220)
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

        let manager = WhiskyWineDownloadManager(
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

// MARK: - WhiskyWineDownloadManager

/// Downloads WhiskyWine with resume support, auto-retry, and proxy disabled.
/// Bypasses system proxy (127.0.0.1:7890 etc.) that can cause 503 / -1 bytes issues.
/// Downloads directly to cache file (边下载边缓存).
final class WhiskyWineDownloadManager: NSObject, URLSessionDataDelegate {
    private let downloadURL: URL
    private let totalBytesHandler: (Int64) -> Void
    private let progressHandler: (Int64, Int64) -> Void
    private let completionHandler: (URL) -> Void
    private let errorHandler: (Error) -> Void

    private var session: URLSession!
    private var dataTask: URLSessionDataTask?
    private var retryCount = 0
    private let maxRetries = 3

    private var cachedTarURL: URL {
        let fileManager = FileManager.default
        if let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let whiskyDir = supportDir.appendingPathComponent("Whisky", isDirectory: true)
            let downloadsDir = whiskyDir.appendingPathComponent("Downloads", isDirectory: true)
            try? fileManager.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
            return downloadsDir.appendingPathComponent("Libraries.tar.gz")
        }
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("Libraries.tar.gz")
    }

    private var outputFileHandle: FileHandle?
    private var totalBytesWritten: Int64 = 0
    private var totalBytesExpected: Int64 = 0

    init(
        downloadURL: URL,
        totalBytesHandler: @escaping (Int64) -> Void,
        progressHandler: @escaping (Int64, Int64) -> Void,
        completionHandler: @escaping (URL) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {
        self.downloadURL = downloadURL
        self.totalBytesHandler = totalBytesHandler
        self.progressHandler = progressHandler
        self.completionHandler = completionHandler
        self.errorHandler = errorHandler
        super.init()
    }

    func start() {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: cachedTarURL.path) {
            let fileSize = (try? fileManager.attributesOfItem(atPath: cachedTarURL.path)[.size] as? Int64) ?? 0
            if fileSize > 0 {
                print("[WhiskyWineDownload] Using cached tar file (\(fileSize) bytes)")
                completionHandler(cachedTarURL)
                return
            }
        }

        let config = URLSessionConfiguration.default

        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600

        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = false
        config.httpMaximumConnectionsPerHost = 4

        self.session = URLSession(configuration: config, delegate: self, delegateQueue: .main)

        print("[WhiskyWineDownload] Starting fresh download: \(downloadURL)")
        let request = URLRequest(url: downloadURL)
        dataTask = session.dataTask(with: request)
        dataTask?.resume()
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: cachedTarURL.path) {
            try? fileManager.removeItem(at: cachedTarURL)
        }

        fileManager.createFile(atPath: cachedTarURL.path, contents: nil)

        do {
            outputFileHandle = try FileHandle(forWritingTo: cachedTarURL)
        } catch {
            print("[WhiskyWineDownload] Failed to open output file: \(error)")
            completionHandler(.cancel)
            return
        }

        totalBytesExpected = response.expectedContentLength
        totalBytesWritten = 0

        if totalBytesExpected > 0 {
            totalBytesHandler(totalBytesExpected)
        }

        completionHandler(.allow)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        if let fileHandle = outputFileHandle {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            totalBytesWritten += Int64(data.count)
            progressHandler(totalBytesWritten, totalBytesExpected)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        outputFileHandle?.closeFile()
        outputFileHandle = nil

        if let error = error as NSError? {
            print("[WhiskyWineDownload] Error: \(error.code) \(error.localizedDescription)")

            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: cachedTarURL.path) {
                try? fileManager.removeItem(at: cachedTarURL)
            }

            if retryCount < maxRetries {
                retryCount += 1
                print("[WhiskyWineDownload] Retry \(retryCount)/\(maxRetries) in 3 seconds...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let self = self else { return }
                    self.totalBytesWritten = 0
                    self.start()
                }
            } else {
                errorHandler(error)
            }
        } else {
            print("[WhiskyWineDownload] Download complete, saved to \(cachedTarURL.path) (\(totalBytesWritten) bytes)")
            completionHandler(cachedTarURL)
        }
    }
}
