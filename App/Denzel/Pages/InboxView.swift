// SPDX-License-Identifier: MPL-2.0
import SwiftUI

struct InboxView: View {
    var body: some View {
        ContentUnavailableView(
            "Inbox",
            systemImage: "tray",
            description: Text("Incoming invoices will land here.")
        )
    }
}
