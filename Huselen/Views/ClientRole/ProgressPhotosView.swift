import SwiftUI

// MARK: - Progress Photos View

struct ProgressPhotosView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: ProgressPhoto.PhotoCategory? = nil
    @State private var showCamera = false
    @State private var captureCategory: ProgressPhoto.PhotoCategory = .front
    @State private var captureNote = ""
    @State private var isSaving = false
    @State private var showCompare = false
    @State private var selectedPhoto: ProgressPhoto?
    @State private var showDeleteConfirm = false
    @State private var photoToDelete: ProgressPhoto?

    private var filteredPhotos: [ProgressPhoto] {
        let photos = syncManager.progressPhotos
        guard let cat = selectedCategory else { return photos }
        return photos.filter { $0.category == cat }
    }

    private var groupedByMonth: [(String, [ProgressPhoto])] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: filteredPhotos) { photo in
            formatter.string(from: photo.takenAt)
        }

        return grouped.sorted { lhs, rhs in
            guard let ld = lhs.value.first?.takenAt, let rd = rhs.value.first?.takenAt else { return false }
            return ld > rd
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    categoryFilter
                    photoGrid
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Theme.Colors.screenBackground)
            .navigationTitle("Ảnh tiến trình")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if filteredPhotos.count >= 2 {
                        Button {
                            showCompare = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left.arrow.right")
                                Text("So sánh")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.fitGreen)
                        }
                    }
                }
            }
            .task { await syncManager.fetchProgressPhotos() }
            .refreshable { await syncManager.fetchProgressPhotos() }
            .fullScreenCover(isPresented: $showCamera) {
                LocketCameraView(title: "Progress") { data in
                    showCamera = false
                    Task {
                        isSaving = true
                        await syncManager.saveProgressPhoto(
                            photoData: data,
                            note: captureNote,
                            category: captureCategory
                        )
                        captureNote = ""
                        isSaving = false
                    }
                }
            }
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailSheet(photo: photo) {
                    photoToDelete = photo
                    selectedPhoto = nil
                    showDeleteConfirm = true
                }
            }
            .sheet(isPresented: $showCompare) {
                ComparePhotosView(photos: filteredPhotos)
            }
            .alert("Xoá ảnh này?", isPresented: $showDeleteConfirm) {
                Button("Xoá", role: .destructive) {
                    if let photo = photoToDelete {
                        Task { await syncManager.deleteProgressPhoto(photo) }
                    }
                }
                Button("Huỷ", role: .cancel) {}
            } message: {
                Text("Ảnh sẽ bị xoá vĩnh viễn.")
            }
            .overlay { if isSaving { savingOverlay } }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                statBubble(
                    value: "\(syncManager.progressPhotos.count)",
                    label: "Tổng ảnh",
                    color: Color.fitGreen
                )
                statBubble(
                    value: monthsTracked,
                    label: "Tháng theo dõi",
                    color: Color.fitIndigo
                )
                statBubble(
                    value: "\(categoriesUsed)",
                    label: "Góc chụp",
                    color: Color.fitOrange
                )
            }

            // Add photo buttons
            HStack(spacing: 8) {
                ForEach(ProgressPhoto.PhotoCategory.allCases) { cat in
                    Button {
                        captureCategory = cat
                        showCamera = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text(cat.displayName)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.fitGreen, Color.fitGreenDark],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.fitCard))
    }

    private var monthsTracked: String {
        let photos = syncManager.progressPhotos
        guard let first = photos.last?.takenAt else { return "0" }
        let months = Calendar.current.dateComponents([.month], from: first, to: Date()).month ?? 0
        return "\(max(months, photos.isEmpty ? 0 : 1))"
    }

    private var categoriesUsed: Int {
        Set(syncManager.progressPhotos.map { $0.category }).count
    }

    private func statBubble(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.fitTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "Tất cả", selected: selectedCategory == nil) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = nil }
                }
                ForEach(ProgressPhoto.PhotoCategory.allCases) { cat in
                    filterChip(
                        title: cat.displayName,
                        icon: cat.icon,
                        selected: selectedCategory == cat
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = cat }
                    }
                }
            }
        }
    }

    private func filterChip(title: String, icon: String? = nil, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(selected ? .white : Color.fitTextSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(selected ? Color.fitGreen : Color.fitCard)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            if filteredPhotos.isEmpty {
                emptyState
            } else {
                ForEach(groupedByMonth, id: \.0) { month, photos in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(month.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.fitTextTertiary)
                            .tracking(1)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)
                            ],
                            spacing: 8
                        ) {
                            ForEach(photos) { photo in
                                photoThumbnail(photo)
                            }
                        }
                    }
                }
            }
        }
    }

    private func photoThumbnail(_ photo: ProgressPhoto) -> some View {
        Button {
            selectedPhoto = photo
        } label: {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: photo.photoUrl)) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else if case .failure = phase {
                        placeholder
                    } else {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: 140)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Date badge
                VStack(alignment: .leading, spacing: 1) {
                    Text(photo.takenAt, format: .dateTime.day().month(.abbreviated))
                        .font(.system(size: 9, weight: .bold))
                    Text(photo.category.displayName)
                        .font(.system(size: 8, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.black.opacity(0.55))
                )
                .padding(6)
            }
        }
        .buttonStyle(.plain)
    }

    private var placeholder: some View {
        ZStack {
            Color.fitCard
            Image(systemName: "photo")
                .font(.system(size: 24))
                .foregroundStyle(Color.fitTextTertiary.opacity(0.4))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 44))
                .foregroundStyle(Color.fitTextTertiary.opacity(0.4))
            Text("Chưa có ảnh tiến trình")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.fitTextPrimary)
            Text("Chụp ảnh mỗi tuần để thấy sự thay đổi!")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.fitTextTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.fitCard))
    }

    // MARK: - Saving Overlay

    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().scaleEffect(1.3).tint(.white)
                Text("Đang lưu ảnh...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(30)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial))
        }
    }
}

// MARK: - Photo Detail Sheet

struct PhotoDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let photo: ProgressPhoto
    let onDelete: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AsyncImage(url: URL(string: photo.photoUrl)) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFit()
                    } else {
                        ProgressView().frame(maxHeight: .infinity)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 16)

                VStack(spacing: 8) {
                    HStack {
                        Label(photo.category.displayName, systemImage: photo.category.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.fitGreen)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.fitGreen.opacity(0.12)))

                        Spacer()

                        Text(photo.takenAt, format: .dateTime.day().month(.wide).year())
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.fitTextSecondary)
                    }

                    if !photo.note.isEmpty {
                        Text(photo.note)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.fitTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Chi tiết ảnh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button {
                        dismiss()
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Color.fitCoral)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Compare Photos View (Before / After)

struct ComparePhotosView: View {
    @Environment(\.dismiss) private var dismiss
    let photos: [ProgressPhoto]

    @State private var beforeIndex: Int = 0
    @State private var afterIndex: Int = 0
    @State private var sliderPosition: CGFloat = 0.5

    private var sortedPhotos: [ProgressPhoto] {
        photos.sorted { $0.takenAt < $1.takenAt }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if sortedPhotos.count >= 2 {
                    // Date selectors
                    HStack(spacing: 12) {
                        datePicker(label: "Trước", index: $beforeIndex, color: Color.fitCoral)
                        datePicker(label: "Sau", index: $afterIndex, color: Color.fitGreen)
                    }
                    .padding(.horizontal, 20)

                    // Comparison view
                    GeometryReader { geo in
                        let width = geo.size.width - 40
                        ZStack {
                            // "After" photo (full)
                            photoImage(sortedPhotos[afterIndex].photoUrl)
                                .frame(width: width, height: width * 1.2)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                            // "Before" photo (clipped by slider)
                            photoImage(sortedPhotos[beforeIndex].photoUrl)
                                .frame(width: width, height: width * 1.2)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .mask(
                                    HStack(spacing: 0) {
                                        Rectangle().frame(width: width * sliderPosition)
                                        Spacer(minLength: 0)
                                    }
                                )

                            // Slider line
                            HStack(spacing: 0) {
                                Spacer().frame(width: width * sliderPosition - 16)
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .fill(.white)
                                        .frame(width: 2)
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Image(systemName: "arrow.left.and.right")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.black)
                                        )
                                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                                    Rectangle()
                                        .fill(.white)
                                        .frame(width: 2)
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(width: width, height: width * 1.2)
                        }
                        .frame(width: width, height: width * 1.2)
                        .frame(maxWidth: .infinity)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newPos = value.location.x / width
                                    sliderPosition = min(max(newPos, 0.05), 0.95)
                                }
                        )
                    }
                    .frame(height: (UIScreen.main.bounds.width - 40) * 1.2)
                    .padding(.horizontal, 20)

                    // Date labels
                    HStack {
                        dateLabel(sortedPhotos[beforeIndex].takenAt, title: "Trước", color: Color.fitCoral)
                        Spacer()
                        dateLabel(sortedPhotos[afterIndex].takenAt, title: "Sau", color: Color.fitGreen)
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                } else {
                    Text("Cần ít nhất 2 ảnh để so sánh")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.fitTextTertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.top, 8)
            .navigationTitle("So sánh tiến trình")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .onAppear {
                if sortedPhotos.count >= 2 {
                    beforeIndex = 0
                    afterIndex = sortedPhotos.count - 1
                }
            }
        }
    }

    private func photoImage(_ urlStr: String) -> some View {
        AsyncImage(url: URL(string: urlStr)) { phase in
            if case .success(let img) = phase {
                img.resizable().scaledToFill()
            } else {
                Color.fitCard
            }
        }
    }

    private func datePicker(label: String, index: Binding<Int>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)

            Picker(label, selection: index) {
                ForEach(0..<sortedPhotos.count, id: \.self) { i in
                    Text(sortedPhotos[i].takenAt, format: .dateTime.day().month(.abbreviated).year())
                        .tag(i)
                }
            }
            .pickerStyle(.menu)
            .tint(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.fitCard))
    }

    private func dateLabel(_ date: Date, title: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(date, format: .dateTime.day().month(.abbreviated).year())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.fitTextPrimary)
        }
    }
}
