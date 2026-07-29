// SPDX-License-Identifier: MPL-2.0
import SwiftUI

struct ReviewView: View {
    var body: some View {
        ContentUnavailableView(
            "Review",
            systemImage: "checkmark.circle",
            description: Text("Low-confidence extractions will wait here for a quick confirm.")
        )
    }
}
