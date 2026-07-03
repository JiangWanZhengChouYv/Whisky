//
//  WhiskyWineVersion.swift
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

struct WhiskyWineVersion: Codable {
    var version: SemanticVersion = SemanticVersion(11, 0, 1)

    enum CodingKeys: String, CodingKey {
        case version
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Try string format first (e.g., "1.0.0")
        if let versionString = try? container.decode(String.self, forKey: .version),
           let parsedVersion = SemanticVersion(versionString) {
            self.version = parsedVersion
            return
        }
        // Fall back to default Codable format (nested dict with major/minor/patch)
        self.version = try container.decode(SemanticVersion.self, forKey: .version)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode as string for compatibility
        try container.encode(version.description, forKey: .version)
    }
}
