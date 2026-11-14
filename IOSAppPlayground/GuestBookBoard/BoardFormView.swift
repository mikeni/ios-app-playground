import SwiftUI

/// The form that is mounted on the standing board inside the 3D world.
/// It is an ordinary SwiftUI view, so every control stays interactive.
/// `ContentView` warps it onto the board; `WorldScene` uses `size` to
/// keep the board's form area at the same aspect ratio.
struct BoardFormView: View {
    /// Fixed layout size in points. The world-space form area in
    /// `WorldScene` is derived from this aspect ratio.
    static let size = CGSize(width: 440, height: 360)

    let guestBook: GuestBook

    @State private var name = ""
    @State private var email = ""
    @State private var mood: Mood = .happy
    @State private var notes = ""
    @State private var didSubmit = false

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Sign the guest book", systemImage: "pencil.and.list.clipboard")
                .font(.title2.bold())

            TextField("Name", text: $name)
                .textContentType(.name)
                .textFieldStyle(.roundedBorder)

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                #endif
                .textFieldStyle(.roundedBorder)

            MoodPicker(selection: $mood)

            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(2...3)
                .textFieldStyle(.roundedBorder)

            Spacer(minLength: 0)

            // Full width so the card reads as filled from any camera angle.
            Button(action: submit) {
                Label(
                    didSubmit ? "Saved" : "Submit",
                    systemImage: didSubmit ? "checkmark.circle.fill" : "paperplane.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(didSubmit ? .green : .accentColor)
            .disabled(!canSubmit && !didSubmit)
            .animation(.snappy(duration: 0.2), value: didSubmit)
        }
        .padding(20)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func submit() {
        guestBook.add(name: name, email: email, mood: mood, notes: notes)
        name = ""
        email = ""
        notes = ""
        mood = .happy
        didSubmit = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            didSubmit = false
        }
    }
}

/// A segmented control built from plain SwiftUI views.
///
/// The system segmented picker is backed by UIKit on iOS and does not
/// follow the projective warp `ContentView` applies to the form, so it
/// rendered with the wrong skew on the board. This one is pure SwiftUI
/// and transforms correctly.
private struct MoodPicker: View {
    @Binding var selection: Mood

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Mood.allCases) { mood in
                let isSelected = mood == selection
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selection = mood }
                } label: {
                    Label(mood.rawValue, systemImage: mood.symbolName)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(.background)
                                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mood")
    }
}

#Preview {
    BoardFormView(guestBook: GuestBook())
        .padding()
}
