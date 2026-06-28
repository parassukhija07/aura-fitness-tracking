import SwiftUI

struct ProgressPhotosView: View {
    @Environment(\.dismiss) var dismiss
    @State private var compareMode = "Side by Side"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AuraSpacing.s4) {
                    // Compare mode
                    AuraSegmentedPicker(options: ["Side by Side","Top / Bottom"], selection: $compareMode)
                        .padding(.horizontal, AuraSpacing.screenPad)

                    // Photo placeholder
                    HStack(spacing: AuraSpacing.s3) {
                        photoSlot("Before")
                        photoSlot("After")
                    }
                    .padding(.horizontal, AuraSpacing.screenPad)

                    // Delta card placeholder
                    AuraCard {
                        VStack(spacing: AuraSpacing.s2) {
                            Text("Add before & after photos to see your transformation delta.")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                                .multilineTextAlignment(.center)
                        }
                        .padding(AuraSpacing.s4)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, AuraSpacing.screenPad)

                    AuraSectionLabel(title: "Photo Library")
                        .padding(.horizontal, AuraSpacing.screenPad)

                    // Grid placeholder
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                        ForEach(0..<6, id: \.self) { _ in
                            ZStack {
                                Color.aura.surface2
                                    .aspectRatio(1, contentMode: .fit)
                                Image(systemName: "photo")
                                    .foregroundColor(.aura.text3)
                                    .font(.system(size: 24))
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle("Progress Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Share
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.aura.accent)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func photoSlot(_ label: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AuraRadius.lg)
                .fill(Color.aura.surface)
                .aspectRatio(0.75, contentMode: .fit)
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
    }
}
