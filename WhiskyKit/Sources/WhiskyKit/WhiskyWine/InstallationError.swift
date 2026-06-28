//
//  InstallationError.swift
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

public enum InstallationError: Error, LocalizedError, CustomStringConvertible, CustomNSError {
    case invalidInstallation(String)
    case extractionFailed(String)
    case downloadFailed(statusCode: Int, message: String)
    case missingBinary(String)
    case missingLibrary(String)
    case missingShareData(String)
    case versionCheckFailed(String)
    case wineRunFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidInstallation(let reason):
            return "Invalid installation: \(reason)"
        case .extractionFailed(let reason):
            return "Extraction failed: \(reason)"
        case .downloadFailed(let statusCode, let message):
            return "Download failed (status \(statusCode)): \(message)"
        case .missingBinary(let binary):
            return "Missing binary: \(binary)"
        case .missingLibrary(let path):
            return "Missing library directory: \(path)"
        case .missingShareData(let path):
            return "Missing share data: \(path)"
        case .versionCheckFailed(let reason):
            return "Version check failed: \(reason)"
        case .wineRunFailed(let reason):
            return "Wine run failed: \(reason)"
        }
    }

    public var description: String {
        return errorDescription ?? "InstallationError"
    }

    public var localizedDescription: String {
        return errorDescription ?? "InstallationError"
    }

    public static var errorDomain: String { "com.Whisky.InstallationError" }

    public var errorCode: Int {
        switch self {
        case .invalidInstallation:
            return 1
        case .extractionFailed:
            return 2
        case .downloadFailed:
            return 3
        case .missingBinary:
            return 4
        case .missingLibrary:
            return 5
        case .missingShareData:
            return 6
        case .versionCheckFailed:
            return 7
        case .wineRunFailed:
            return 8
        }
    }

    public var errorUserInfo: [String: Any] {
        return [NSLocalizedDescriptionKey: errorDescription ?? "InstallationError"]
    }
}
