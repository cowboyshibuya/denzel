// SPDX-License-Identifier: MPL-2.0

/// Named, tunable in one place rather than buried in pipeline logic.
public enum ConfidenceThresholds {
    /// Vendor match confidence below this sends the whole document to review.
    public static let vendorMatch = 0.95

    /// Per-field confidence below this (or a missing required field) sends
    /// the document to review, but doesn't discard whatever *did* extract.
    public static let fieldMinimum = 0.6
}
