import SwiftUI

/// A month grid calendar where each day shows meal photos in a fan/deck layout.
struct MealCalendarView: View {
    @ObservedObject var viewModel: MealLogViewModel
    let userId: String
    let onSelectDate: (Date) -> Void

    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    private var monthLabel: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "MMMM yyyy"
        return df.string(from: viewModel.displayedMonth).capitalized
    }

    var body: some View {
        VStack(spacing: 8) {
            // Month navigation
            monthNavigationBar

            // Weekday headers
            weekdayHeaders

            // Day grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(generateMonthDays(), id: \.self) { date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: cellHeight)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .task {
            await viewModel.loadMonthPhotos(userId: userId)
        }
        .onChange(of: viewModel.displayedMonth) { _, _ in
            Task { await viewModel.loadMonthPhotos(userId: userId) }
        }
    }

    private var cellHeight: CGFloat { 52 }

    // MARK: - Month Navigation

    private var monthNavigationBar: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.goToPreviousMonth()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.fitTextSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.fitCard))
            }

            Spacer()

            HStack(spacing: 8) {
                Text(monthLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.fitTextPrimary)

                if !viewModel.isCurrentMonth {
                    Button {
                        viewModel.goToToday()
                        Task { await viewModel.selectDate(Date(), userId: userId) }
                        onSelectDate(Date())
                    } label: {
                        Text("Hôm nay")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.fitGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(Color.fitGreen.opacity(0.12))
                            )
                    }
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.goToNextMonth()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(viewModel.isCurrentMonth ? Color.fitTextTertiary : Color.fitTextSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.fitCard))
            }
            .disabled(viewModel.isCurrentMonth)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Weekday Headers

    private var weekdayHeaders: some View {
        HStack(spacing: 0) {
            ForEach(["CN", "T2", "T3", "T4", "T5", "T6", "T7"], id: \.self) { d in
                Text(d)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.fitTextTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Day Cell

    private func dayCell(_ date: Date) -> some View {
        let isToday = cal.isDateInToday(date)
        let isSelected = cal.isDate(date, inSameDayAs: viewModel.selectedDate)
        let isCurrentM = cal.isDate(date, equalTo: viewModel.displayedMonth, toGranularity: .month)
        let dateKey = DateFormatters.localDateOnly.string(from: date)
        let photos = viewModel.monthPhotoData[dateKey] ?? []

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                Task { await viewModel.selectDate(date, userId: userId) }
                onSelectDate(date)
            }
        } label: {
            VStack(spacing: 2) {
                // Fan photos or day circle
                ZStack {
                    if !photos.isEmpty {
                        fanPhotosView(photos: photos, size: 36)
                            .overlay(
                                Color.black.opacity(isSelected ? 0.1 : 0)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            )
                    } else if isToday || isSelected {
                        Circle()
                            .fill(isSelected ? Color.fitGreen : Color.fitGreen.opacity(0.15))
                            .frame(width: 34, height: 34)
                    }

                    // Day number
                    if photos.isEmpty {
                        Text(date.formatted(.dateTime.day()))
                            .font(.system(size: 13, weight: isToday || isSelected ? .bold : .medium))
                            .foregroundStyle(
                                isToday || isSelected ? .white :
                                !isCurrentM ? Color.fitTextTertiary.opacity(0.4) :
                                Color.fitTextPrimary
                            )
                    }

                    // Selection ring
                    if isSelected && !photos.isEmpty {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.fitGreen, lineWidth: 2.5)
                            .frame(width: 38, height: 38)
                    }
                }
                .frame(width: 40, height: 38)

                // Day number below photos
                if !photos.isEmpty {
                    Text(date.formatted(.dateTime.day()))
                        .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(
                            isSelected ? Color.fitGreen :
                            isToday ? Color.fitGreen :
                            !isCurrentM ? Color.fitTextTertiary.opacity(0.4) :
                            Color.fitTextSecondary
                        )
                } else {
                    Color.clear.frame(height: 10)
                }
            }
            .frame(height: cellHeight)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fan Photos View

    /// Shows up to 3 meal photos in a fan/deck layout with rotation.
    private func fanPhotosView(photos: [String], size: CGFloat) -> some View {
        let displayPhotos = Array(photos.prefix(3))
        let count = displayPhotos.count

        // Fan angles: distribute photos symmetrically
        let maxAngle: Double = count == 1 ? 0 : (count == 2 ? 8 : 12)
        let angles: [Double] = {
            switch count {
            case 1: return [0]
            case 2: return [-maxAngle, maxAngle]
            default: return [-maxAngle, 0, maxAngle]
            }
        }()

        // Slight offsets for depth
        let offsets: [CGSize] = {
            switch count {
            case 1: return [.zero]
            case 2: return [CGSize(width: -2, height: 1), CGSize(width: 2, height: -1)]
            default: return [CGSize(width: -3, height: 2), .zero, CGSize(width: 3, height: -2)]
            }
        }()

        return ZStack {
            ForEach(Array(displayPhotos.enumerated()), id: \.offset) { index, urlStr in
                if let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.fitCard)
                        }
                    }
                    .frame(width: size - 4, height: size - 4)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(.white, lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .rotationEffect(.degrees(angles[index]))
                    .offset(offsets[index])
                }
            }

            // Badge for extra photos
            if photos.count > 3 {
                Text("+\(photos.count - 3)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.fitGreen))
                    .offset(x: 12, y: -14)
            }
        }
    }

    // MARK: - Generate Month Days

    private func generateMonthDays() -> [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: viewModel.displayedMonth) else { return [] }
        let first = interval.start
        let firstWeekday = cal.component(.weekday, from: first)
        let daysInMonth = cal.range(of: .day, in: .month, for: viewModel.displayedMonth)?.count ?? 30

        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for i in 0..<daysInMonth {
            days.append(cal.date(byAdding: .day, value: i, to: first))
        }
        return days
    }
}
