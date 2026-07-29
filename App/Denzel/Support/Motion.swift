// SPDX-License-Identifier: MPL-2.0
import SwiftUI

/// Central motion convention — every future screen inherits this for free.
enum Motion {
    /// Apple's damping-ratio spring, critically damped for ordinary UI settle.
    static let settle = Animation.spring(response: 0.35, dampingFraction: 1.0)

    static func page(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : settle
    }
}
