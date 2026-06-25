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

    public var errorDescription: String? {
        switch self {
        case .invalidInstallation(let reason):
            return "Invalid installation: \(reason)"
        case .extractionFailed(let reason):
            return "Extraction failed: \(reason)"
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
        }
    }

    public var errorUserInfo: [String: Any] {
        return [NSLocalizedDescriptionKey: errorDescription ?? "InstallationError"]
    }
}
