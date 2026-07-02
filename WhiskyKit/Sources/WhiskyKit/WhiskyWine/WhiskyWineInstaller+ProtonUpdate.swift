//
//  WhiskyWineInstaller+ProtonUpdate.swift
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
import SemanticVersion

extension WhiskyWineInstaller {
    public static func shouldUpdateProton(mode: WineMode) async -> (Bool, SemanticVersion) {
        guard mode == .proton11 || mode == .proton10 else {
            return (false, SemanticVersion(0, 0, 0))
        }

        let baseURL = mode == .proton11 ? proton11BaseURL : proton10BaseURL
        let versionPlistURL = baseURL + "ProtonVersion.plist"
        let localVersion = protonVersion(mode: mode)
        var remoteVersion: SemanticVersion?

        if let remoteUrl = URL(string: versionPlistURL) {
            remoteVersion = await withCheckedContinuation { continuation in
                URLSession(configuration: .ephemeral)
                    .dataTask(with: URLRequest(url: remoteUrl)) { data, _, error in
                    do {
                        if error == nil, let data = data {
                            let decoder = PropertyListDecoder()
                            let remoteInfo = try decoder.decode(WhiskyWineVersion.self, from: data)
                            continuation.resume(returning: remoteInfo.version)
                            return
                        }
                        if let error = error {
                            print(error)
                        }
                    } catch {
                        print(error)
                    }
                    continuation.resume(returning: nil)
                }.resume()
            }
        }

        if let localVersion = localVersion, let remoteVersion = remoteVersion {
            if localVersion < remoteVersion {
                return (true, remoteVersion)
            }
        }

        return (false, SemanticVersion(0, 0, 0))
    }

    public static func protonVersion(mode: WineMode) -> SemanticVersion? {
        guard mode == .proton11 || mode == .proton10 else {
            return nil
        }

        do {
            let versionPlist: URL
            switch mode {
            case .proton11:
                versionPlist = applicationFolder
                    .appending(path: "Libraries/Proton11/ProtonVersion")
                    .appendingPathExtension("plist")
            case .proton10:
                versionPlist = applicationFolder
                    .appending(path: "Libraries/Proton10/ProtonVersion")
                    .appendingPathExtension("plist")
            default:
                return nil
            }

            let decoder = PropertyListDecoder()
            let data = try Data(contentsOf: versionPlist)
            let info = try decoder.decode(WhiskyWineVersion.self, from: data)
            return info.version
        } catch {
            print(error)
            return nil
        }
    }
}
