// SPDX-License-Identifier: MPL-2.0
import SwiftUI

struct LibraryView: View {
    var body: some View {
        ContentUnavailableView(
            "Library",
            systemImage: "books.vertical",
            description: Text("Your filed invoices will show up here.")
        )
    }
}
