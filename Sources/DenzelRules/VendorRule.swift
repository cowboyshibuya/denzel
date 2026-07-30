// SPDX-License-Identifier: MPL-2.0
import Foundation

public struct VendorRule: Codable, Equatable {
    public struct Match: Codable, Equatable {
        public struct Condition: Codable, Equatable {
            public var textContains: String?
            public var vatID: String?

            enum CodingKeys: String, CodingKey {
                case textContains = "text_contains"
                case vatID = "vat_id"
            }
        }
        public var any: [Condition]
    }

    public struct FieldRule: Codable, Equatable {
        public var regex: String?
        public var near: [String]?
        public var money: Bool?
    }

    public var id: String
    public var name: String
    public var aliases: [String]
    public var match: Match
    public var fields: [String: FieldRule]
}
