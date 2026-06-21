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
                errorMessage = "Download failed: \(error.localizedDescription)"
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
final class WhiskyWineDownloadManager: NSObject, URLSessionDownloadDelegate {
    private let downloadURL: URL
    private let totalBytesHandler: (Int64) -> Void
    private let progressHandler: (Int64, Int64) -> Void
    private let completionHandler: (URL) -> Void
    private let errorHandler: (Error) -> Void

    private var session: URLSession!
    private var downloadTask: URLSessionDownloadTask?
    private var retryCount = 0
    private let maxRetries = 3

    private var resumeDataURL: URL {
        let fileManager = FileManager.default
        if let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let whiskyCacheDir = cacheDir.appendingPathComponent("Whisky", isDirectory: true)
            try? fileManager.createDirectory(at: whiskyCacheDir, withIntermediateDirectories: true)
            return whiskyCacheDir.appendingPathComponent("whiskywine.resumeData")
        }
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("whiskywine.resumeData")
    }

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
        let config = URLSessionConfiguration.default

        // Timeouts — large file (123 MB) needs generous limits
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600

        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = false
        config.httpMaximumConnectionsPerHost = 4

        self.session = URLSession(configuration: config, delegate: self, delegateQueue: .main)

        // Check if we have resume data from a previous attempt
        if FileManager.default.fileExists(atPath: resumeDataURL.path),
           let resumeData = try? Data(contentsOf: resumeDataURL) {
            print("[WhiskyWineDownload] Resuming from saved resume data")
            downloadTask = session.downloadTask(withResumeData: resumeData)
        } else {
            print("[WhiskyWineDownload] Starting fresh download: \(downloadURL)")
            downloadTask = session.downloadTask(with: downloadURL)
        }
        downloadTask?.resume()
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Clean up resume data on success
        try? FileManager.default.removeItem(at: resumeDataURL)
        print("[WhiskyWineDownload] Download complete")
        completionHandler(location)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        // GitHub CDN may return -1 for totalBytesExpectedToWrite (chunked encoding).
        // We always report what the delegate tells us, even if it's -1.
        if totalBytesExpectedToWrite > 0 {
            totalBytesHandler(totalBytesExpectedToWrite)
        }
        progressHandler(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didResumeAtOffset fileOffset: Int64,
        expectedTotalBytes: Int64
    ) {
        print("[WhiskyWineDownload] Resumed at \(fileOffset)/\(expectedTotalBytes)")
        if expectedTotalBytes > 0 {
            totalBytesHandler(expectedTotalBytes)
        }
        progressHandler(fileOffset, expectedTotalBytes)
    }

    // MARK: - URLSessionTaskDelegate

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error = error as NSError? else { return }

        print("[WhiskyWineDownload] Error: \(error.code) \(error.localizedDescription)")

        // Extract resume data from the error
        let resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        if let data = resumeData {
            try? data.write(to: resumeDataURL, options: .atomic)
            print("[WhiskyWineDownload] Saved resume data: \(data.count) bytes")
        }

        if retryCount < maxRetries {
            retryCount += 1
            print("[WhiskyWineDownload] Retry \(retryCount)/\(maxRetries) in 3 seconds...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self else { return }
                if let data = try? Data(contentsOf: self.resumeDataURL) {
                    self.downloadTask = self.session.downloadTask(withResumeData: data)
                } else {
                    self.downloadTask = self.session.downloadTask(with: self.downloadURL)
                }
                self.downloadTask?.resume()
            }
        } else {
            errorHandler(error)
        }
    }
}
