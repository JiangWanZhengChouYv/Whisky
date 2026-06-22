//
//  Error+Extensions.swift
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

public extension Error {
    /// Returns a human-readable, non-empty description of this error.
    ///
    /// Foundation's default `error.localizedDescription` can return the
    /// "Swift.String 错误 1" placeholder when an Error type's
    /// `errorDescription` is not properly bridged to NSError. This helper
    /// detects that placeholder and any other empty/garbled values, then
    /// falls back to `String(describing:)` so the UI always shows
    /// something useful.
    var safeLocalizedDescription: String {
        let direct = self.localizedDescription
        if !direct.isEmpty,
           !direct.contains("Swift.String"),
           !direct.lowercased().contains("operation couldn") {
            return direct
        }
        let described = String(describing: self)
        if described.isEmpty || described == "nil" {
            return "An unknown error occurred"
        }
        return described
    }
}
