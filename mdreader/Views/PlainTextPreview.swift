import SwiftUI

struct PlainTextPreview: View {
    let text: String
    let fontSize: Double

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(size: fontSize, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
        }
        .background(Color(.systemBackground))
    }
}
