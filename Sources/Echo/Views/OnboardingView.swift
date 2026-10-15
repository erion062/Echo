import SwiftUI

struct OnboardingView: View {
    @AppStorage("userName") private var userName = ""
    @State private var step = 0
    @State private var appeared = false
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(colors: [Color.echoAccent.opacity(0.22), .clear], center: .top, startRadius: 0, endRadius: 520)
                .ignoresSafeArea()
                .opacity(appeared ? 1 : 0)

            if step == 0 {
                welcome
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
            } else {
                nameStep
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1)) { appeared = true }
        }
    }

    // MARK: Step 1

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer()
            AppMark()
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1), value: appeared)

            Text("Welcome to Echo")
                .font(.system(size: 36, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 28)
                .modifier(Reveal(appeared: appeared, delay: 0.25))

            VStack(alignment: .leading, spacing: 26) {
                FeatureRow(symbol: "magnifyingglass", title: "Find anything",
                           detail: "Search every song on YouTube in seconds.")
                    .modifier(Reveal(appeared: appeared, delay: 0.4))
                FeatureRow(symbol: "plus.circle.fill", title: "Keep it with one tap",
                           detail: "Tap + and the song is saved to your library.")
                    .modifier(Reveal(appeared: appeared, delay: 0.5))
                FeatureRow(symbol: "airplane", title: "Listen anywhere",
                           detail: "Everything you save plays offline. No signal needed.")
                    .modifier(Reveal(appeared: appeared, delay: 0.6))
            }
            .padding(.top, 44)
            .padding(.horizontal, 12)

            Spacer()
            Spacer()

            Button("Continue") {
                Haptics.tap()
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { step = 1 }
            }
            .buttonStyle(PrimaryButtonStyle())
            .modifier(Reveal(appeared: appeared, delay: 0.75))
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
    }

    // MARK: Step 2

    private var nameStep: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("What should we\ncall you?")
                .font(.system(size: 34, weight: .bold))
                .multilineTextAlignment(.center)
            Text("Echo greets you by name. No account,\nno email, no password. Ever.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            TextField("", text: $name, prompt: Text("Your name").foregroundStyle(.white.opacity(0.22)))
                .font(.system(size: 34, weight: .semibold))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .textContentType(.givenName)
                .submitLabel(.done)
                .focused($nameFocused)
                .onSubmit(finish)
                .padding(.top, 48)
            Capsule()
                .fill(trimmedName.isEmpty ? Color.white.opacity(0.15) : Color.echoAccent)
                .frame(width: trimmedName.isEmpty ? 120 : 200, height: 3)
                .padding(.top, 10)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: trimmedName.isEmpty)

            Spacer()
            Spacer()

            Button("Get Started", action: finish)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(trimmedName.isEmpty)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { nameFocused = true }
        }
    }

    private func finish() {
        guard !trimmedName.isEmpty else { return }
        Haptics.success()
        nameFocused = false
        userName = trimmedName
    }
}

private struct Reveal: ViewModifier {
    let appeared: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(delay), value: appeared)
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Color.echoAccent)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

/// The Echo logo: a glowing waveform tile.
struct AppMark: View {
    var size: CGFloat = 96

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(LinearGradient(colors: [Color(white: 0.16), Color(white: 0.04)], startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "waveform")
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.45, blue: 0.53), .echoAccent],
                                                    startPoint: .top, endPoint: .bottom))
                    .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
            }
            .overlay(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
            .shadow(color: Color.echoAccent.opacity(0.35), radius: 30, y: 10)
    }
}
