import SwiftUI

struct PasswordStrengthBar: View {
    let password: String

    private var strengthScore: Int {
        var score = 0
        if password.count >= 6 { score += 1 }
        if password.count >= 10 { score += 1 }
        if password.contains(where: { $0.isUppercase }) { score += 1 }
        if password.contains(where: { $0.isNumber }) { score += 1 }
        if password.contains(where: { $0.isPunctuation || $0.isSymbol }) { score += 1 }
        return score
    }

    private var strengthLevel: Int {
        switch strengthScore {
        case 0...1: return 1
        case 2...3: return 2
        default: return 3
        }
    }

    private var strengthLabel: String {
        switch strengthLevel {
        case 1: return "Yếu"
        case 2: return "Trung bình"
        default: return "Mạnh"
        }
    }

    private var strengthColor: Color {
        switch strengthLevel {
        case 1: return Theme.Colors.softPink
        case 2: return Theme.Colors.softOrange
        default: return Theme.Colors.mintGreen
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(1...3, id: \.self) { segment in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(segment <= strengthLevel ? strengthColor : Theme.Colors.separator)
                        .frame(height: 4)
                }
            }

            Text(strengthLabel)
                .font(Theme.Fonts.caption())
                .foregroundStyle(strengthColor)
        }
        .animation(.easeInOut(duration: 0.2), value: strengthLevel)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        PasswordStrengthBar(password: "ab")
        PasswordStrengthBar(password: "abc123")
        PasswordStrengthBar(password: "Abc123!@#long")
    }
    .padding()
}
