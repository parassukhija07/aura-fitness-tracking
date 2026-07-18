import SwiftUI
import PhotosUI

struct ProgressPhotosView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var compareMode = "Side by Side"
    @State private var photosPickerItem: PhotosPickerItem? = nil
    @State private var compareBeforeItem: PhotosPickerItem? = nil
    @State private var compareAfterItem: PhotosPickerItem? = nil

    // In-memory photo store (persisted via AppState.progressPhotos)
    @State private var beforeImage: UIImage? = nil
    @State private var afterImage: UIImage? = nil
    @State private var showAddSheet = false
    @State private var newPhotoImage: UIImage? = nil
    @State private var newPhotoWeight = ""
    @State private var newPhotoNote = ""

    private var photos: [ProgressPhoto] { appState.progressPhotos.sorted { $0.date > $1.date } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AuraSpacing.s4) {
                    // Compare mode picker
                    AuraSegmentedPicker(
                        options: ["Side by Side", "Top / Bottom"],
                        selection: $compareMode
                    )
                    .padding(.horizontal, AuraSpacing.screenPad)
                    .padding(.top, AuraSpacing.s2)

                    // Before / After compare slots
                    compareSlots

                    // Delta card
                    if let first = photos.last, let latest = photos.first,
                       first.id != latest.id {
                        deltaCard(first: first, latest: latest)
                            .padding(.horizontal, AuraSpacing.screenPad)
                    }

                    // Library grid
                    AuraSectionLabel(title: "Library")
                        .padding(.horizontal, AuraSpacing.screenPad)

                    if photos.isEmpty {
                        VStack(spacing: AuraSpacing.s3) {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 40))
                                .foregroundColor(.aura.text3)
                            Text("No photos yet")
                                .font(AuraFont.body())
                                .foregroundColor(.aura.text2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AuraSpacing.s5)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 2
                        ) {
                            ForEach(photos) { photo in
                                if let img = UIImage(data: photo.imageData) {
                                    ZStack(alignment: .bottomLeading) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .aspectRatio(3/4, contentMode: .fit)
                                            .clipped()
                                        Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(Color.black.opacity(0.45))
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                        .padding(.horizontal, AuraSpacing.screenPad)
                    }

                    Spacer().frame(height: 40)
                }
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle("Progress Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    PhotosPicker(selection: $photosPickerItem, matching: .images) {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.aura.accent)
                    }
                }
            }
            .onChange(of: photosPickerItem) { _, item in
                Task {
                    guard let item,
                          let data = try? await item.loadTransferable(type: Data.self),
                          let img = UIImage(data: data) else { return }
                    newPhotoImage = img
                    showAddSheet = true
                }
            }
            .sheet(isPresented: $showAddSheet) {
                addPhotoSheet
            }
            .onChange(of: compareBeforeItem) { _, item in
                Task {
                    guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
                    beforeImage = UIImage(data: data)
                }
            }
            .onChange(of: compareAfterItem) { _, item in
                Task {
                    guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
                    afterImage = UIImage(data: data)
                }
            }
        }
    }

    // MARK: Compare slots
    @ViewBuilder
    private var compareSlots: some View {
        let isVertical = compareMode == "Top / Bottom"
        Group {
            if isVertical {
                VStack(spacing: AuraSpacing.s3) {
                    compareSlot(image: firstPhoto, label: "Before", pickerItem: $compareBeforeItem)
                    compareSlot(image: lastPhoto, label: "After", pickerItem: $compareAfterItem)
                }
            } else {
                HStack(spacing: AuraSpacing.s3) {
                    compareSlot(image: firstPhoto, label: "Before", pickerItem: $compareBeforeItem)
                    compareSlot(image: lastPhoto, label: "After", pickerItem: $compareAfterItem)
                }
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
    }

    private var firstPhoto: UIImage? {
        beforeImage ?? photos.last.flatMap { UIImage(data: $0.imageData) }
    }
    private var lastPhoto: UIImage? {
        afterImage ?? photos.first.flatMap { UIImage(data: $0.imageData) }
    }

    @ViewBuilder
    private func compareSlot(image: UIImage?, label: String, pickerItem: Binding<PhotosPickerItem?>) -> some View {
        PhotosPicker(selection: pickerItem, matching: .images) {
            ZStack(alignment: .bottom) {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .aspectRatio(3/4, contentMode: .fit)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
                } else {
                    RoundedRectangle(cornerRadius: AuraRadius.lg)
                        .fill(Color.aura.surface)
                        .aspectRatio(3/4, contentMode: .fit)
                        .overlay(
                            RoundedRectangle(cornerRadius: AuraRadius.lg)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                .foregroundColor(.aura.separator)
                        )
                    VStack(spacing: AuraSpacing.s2) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 28))
                            .foregroundColor(.aura.text3)
                        Text(label)
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                    }
                }

                // Label pill at bottom
                if image != nil {
                    Text(label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                        .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: Delta card
    private func deltaCard(first: ProgressPhoto, latest: ProgressPhoto) -> some View {
        AuraCard {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(weeksDiff(first.date, latest.date))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.aura.text)
                    if let fw = first.weight, let lw = latest.weight {
                        let delta = lw - fw
                        let d = UnitFormatter.weightValue(delta, unit: appState.weightUnit)
                        Text("\(d >= 0 ? "+" : "")\(String(format: "%.1f", d)) \(appState.weightUnit) · body change")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                    }
                }
                Spacer()
                Button {
                    shareCompare()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13))
                        Text("Share")
                            .font(AuraFont.secondary())
                    }
                    .foregroundColor(.aura.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.aura.accentSoft)
                    .clipShape(Capsule())
                }
            }
            .padding(AuraSpacing.s4)
        }
    }

    // MARK: Add photo sheet
    private var addPhotoSheet: some View {
        NavigationStack {
            Form {
                if let img = newPhotoImage {
                    Section {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                    }
                }
                Section("Details") {
                    HStack {
                        Text("Weight (\(appState.weightUnit))")
                        Spacer()
                        TextField("Optional", text: $newPhotoWeight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.aura.accent)
                    }
                    TextField("Note (optional)", text: $newPhotoNote)
                }
            }
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newPhotoImage = nil
                        showAddSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePhoto()
                        showAddSheet = false
                    }
                    .foregroundColor(.aura.accent)
                }
            }
        }
    }

    // MARK: Helpers
    private func savePhoto() {
        guard let img = newPhotoImage,
              let data = img.jpegData(compressionQuality: 0.75) else { return }
        let photo = ProgressPhoto(
            date: Date(),
            imageData: data,
            weight: UnitFormatter.parseWeightToKg(newPhotoWeight, unit: appState.weightUnit),
            note: newPhotoNote
        )
        appState.progressPhotos.append(photo)
        newPhotoImage = nil
        newPhotoWeight = ""
        newPhotoNote = ""
    }

    private func weeksDiff(_ a: Date, _ b: Date) -> String {
        let days = abs(Calendar.current.dateComponents([.day], from: a, to: b).day ?? 0)
        let weeks = days / 7
        return weeks > 0 ? "\(weeks) weeks apart" : "\(days) days apart"
    }

    private func shareCompare() {
        // UIActivityViewController requires UIKit – launch from SwiftUI via UIApplication
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let root = window.rootViewController else { return }
        let items: [Any] = [firstPhoto, lastPhoto].compactMap { $0 }
        guard !items.isEmpty else { return }
        let av = UIActivityViewController(activityItems: items, applicationActivities: nil)
        root.present(av, animated: true)
    }
}
