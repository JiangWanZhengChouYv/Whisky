//
//  WhiskyWineDownloader.swift
//  WhiskyKit
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

import Foundation

/// Downloads WhiskyWine with resume support, auto-retry, and proxy disabled.
/// Bypasses system proxy (127.0.0.1:7890 etc.) that can cause 503 / -1 bytes issues.
/// Downloads directly to cache file (边下载边缓存).
public final class WhiskyWineDownloader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let downloadURL: URL
    private let cacheFileName: String
    private let totalBytesHandler: @Sendable (Int64) -> Void
    private let progressHandler: @Sendable (Int64, Int64) -> Void
    private let completionHandler: @Sendable (URL) -> Void
    private let errorHandler: @Sendable (Error) -> Void

    private var session: URLSession!
    private var dataTask: URLSessionDataTask?
    private var retryCount = 0
    private let maxRetries = 3

    private var cachedTarURL: URL {
        let fileManager = FileManager.default
        let downloadsDir = WhiskyWineInstaller.applicationFolder
            .appendingPathComponent("Downloads", isDirectory: true)
        try? fileManager.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        return downloadsDir.appendingPathComponent(cacheFileName)
    }

    private var completeMarkerURL: URL {
        cachedTarURL.appendingPathExtension("complete")
    }

    private var outputFileHandle: FileHandle?
    private var totalBytesWritten: Int64 = 0
    private var totalBytesExpected: Int64 = 0

    public init(
        downloadURL: URL,
        cacheFileName: String = "Libraries.tar.gz",
        totalBytesHandler: @escaping @Sendable (Int64) -> Void,
        progressHandler: @escaping @Sendable (Int64, Int64) -> Void,
        completionHandler: @escaping @Sendable (URL) -> Void,
        errorHandler: @escaping @Sendable (Error) -> Void
    ) {
        self.downloadURL = downloadURL
        self.cacheFileName = cacheFileName
        self.totalBytesHandler = totalBytesHandler
        self.progressHandler = progressHandler
        self.completionHandler = completionHandler
        self.errorHandler = errorHandler
        super.init()
    }

    public func start() {
        let fileManager = FileManager.default

        if cacheFileName == "Libraries.tar.gz" {
            migrateOldCacheIfNeeded()
        }

        if fileManager.fileExists(atPath: cachedTarURL.path),
           fileManager.fileExists(atPath: completeMarkerURL.path) {
            let fileSize = (try? fileManager.attributesOfItem(atPath: cachedTarURL.path)[.size] as? Int64) ?? 0
            if fileSize > 0 && fileSize >= 200 * 1024 * 1024 {
                print("[WhiskyWineDownload] Using cached tar file (\(fileSize) bytes)")
                completionHandler(cachedTarURL)
                return
            } else if fileSize > 0 && fileSize < 200 * 1024 * 1024 {
                print(
                    "[WhiskyWineDownload] Cache corrupted: " +
                    "file size \(fileSize) bytes is less than 200MB, cleaning cache..."
                )
                try? fileManager.removeItem(at: cachedTarURL)
                try? fileManager.removeItem(at: completeMarkerURL)
            }
        }

        if fileManager.fileExists(atPath: cachedTarURL.path) {
            try? fileManager.removeItem(at: cachedTarURL)
        }
        if fileManager.fileExists(atPath: completeMarkerURL.path) {
            try? fileManager.removeItem(at: completeMarkerURL)
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

    private func migrateOldCacheIfNeeded() {
        let fileManager = FileManager.default
        guard let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        let oldDownloadsDir = supportDir
            .appendingPathComponent("Whisky", isDirectory: true)
            .appendingPathComponent("Downloads", isDirectory: true)
        let oldCachedTarURL = oldDownloadsDir.appendingPathComponent("Libraries.tar.gz")
        let oldCompleteMarkerURL = oldCachedTarURL.appendingPathExtension("complete")

        guard fileManager.fileExists(atPath: oldCachedTarURL.path),
              fileManager.fileExists(atPath: oldCompleteMarkerURL.path) else {
            return
        }

        let oldFileSize = (try? fileManager.attributesOfItem(atPath: oldCachedTarURL.path)[.size] as? Int64) ?? 0
        guard oldFileSize >= 200 * 1024 * 1024 else {
            print("[WhiskyWineDownload] Old cache too small (\(oldFileSize) bytes), skipping migration")
            return
        }

        guard !fileManager.fileExists(atPath: cachedTarURL.path) else {
            print("[WhiskyWineDownload] New cache already exists, skipping migration")
            return
        }

        print("[WhiskyWineDownload] Migrating old cache from \(oldCachedTarURL.path) to \(cachedTarURL.path)")
        let newDownloadsDir = cachedTarURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: newDownloadsDir, withIntermediateDirectories: true)

        do {
            try fileManager.copyItem(at: oldCachedTarURL, to: cachedTarURL)
            try fileManager.copyItem(at: oldCompleteMarkerURL, to: completeMarkerURL)
            print("[WhiskyWineDownload] Cache migration successful")
        } catch {
            print("[WhiskyWineDownload] Cache migration failed: \(error)")
        }
    }

    // MARK: - URLSessionDataDelegate

    public func urlSession(
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

    public func urlSession(
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

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        outputFileHandle?.closeFile()
        outputFileHandle = nil

        if let error = error as NSError? {
            handleDownloadFailure(error)
            return
        }

        if let failureError = validateResponse(task.response) {
            handleDownloadFailure(failureError)
            return
        }

        if totalBytesExpected > 0 && totalBytesWritten != totalBytesExpected {
            let sizeError = NSError(
                domain: "WhiskyWineDownload",
                code: -2,
                userInfo: [
                    NSLocalizedDescriptionKey:
                    "Incomplete download: \(totalBytesWritten) of \(totalBytesExpected) bytes"
                ]
            )
            handleDownloadFailure(sizeError)
            return
        }

        print("[WhiskyWineDownload] Download complete, saved to \(cachedTarURL.path) (\(totalBytesWritten) bytes)")

        let fileManager = FileManager.default
        fileManager.createFile(atPath: completeMarkerURL.path, contents: nil)
        print("[WhiskyWineDownload] Created complete marker at \(completeMarkerURL.path)")

        completionHandler(cachedTarURL)
    }

    private func validateResponse(_ response: URLResponse?) -> NSError? {
        guard let httpResponse = response as? HTTPURLResponse else {
            return NSError(
                domain: "WhiskyWineDownload",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]
            )
        }

        guard httpResponse.statusCode == 200 else {
            return NSError(
                domain: "WhiskyWineDownload",
                code: Int(httpResponse.statusCode),
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]
            )
        }

        if totalBytesExpected > 0 && totalBytesWritten != totalBytesExpected {
            return NSError(
                domain: "WhiskyWineDownload",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Download size mismatch"]
            )
        }

        return nil
    }

    private func handleDownloadFailure(_ error: NSError) {
        print("[WhiskyWineDownload] Error: \(error.code) \(error.localizedDescription)")

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: cachedTarURL.path) {
            try? fileManager.removeItem(at: cachedTarURL)
        }
        if fileManager.fileExists(atPath: completeMarkerURL.path) {
            try? fileManager.removeItem(at: completeMarkerURL)
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
    }
}
