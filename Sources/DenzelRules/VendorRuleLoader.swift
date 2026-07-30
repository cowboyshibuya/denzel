// SPDX-License-Identifier: MPL-2.0
import Foundation
import Yams

public enum VendorRuleLoaderError: Error {
    case decodeFailed(file: String, underlying: Error)
}

public enum VendorRuleLoader {
    /// Loads every `.yaml`/`.yml` file bundled under `VendorRules/` in this
    /// module's resource bundle. A contributor adds vendor support by
    /// dropping a new file in that directory — no Swift edit, no
    /// registration list.
    public static func loadBundledRules(bundle: Bundle? = nil) throws -> [VendorRule] {
        guard let resourceURL = (bundle ?? .module).resourceURL else { return [] }
        let vendorRulesDir = resourceURL.appendingPathComponent("VendorRules")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: vendorRulesDir,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        let yamlFiles = files.filter { ["yaml", "yml"].contains($0.pathExtension) }
        return try yamlFiles.map(loadRule(from:))
    }

    public static func loadRule(from url: URL) throws -> VendorRule {
        let yamlString = try String(contentsOf: url, encoding: .utf8)
        do {
            return try YAMLDecoder().decode(VendorRule.self, from: yamlString)
        } catch {
            throw VendorRuleLoaderError.decodeFailed(file: url.lastPathComponent, underlying: error)
        }
    }
}
