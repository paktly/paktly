import PhotosUI
import SwiftUI
import UIKit
import Vision
import VisionKit

private struct ReceiptExtraction: Sendable {
    let merchant: String
    let amount: String
    let currency: String
    let date: Date
    let category: String
}

private actor ReceiptOCRService {
    func extract(from pages: [Data], defaultCurrency: String) throws -> ReceiptExtraction {
        let lines = try pages.flatMap { imageData -> [String] in
            guard let image = UIImage(data: imageData), let cgImage = image.cgImage else {
                throw ReceiptScanError.invalidImage
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            try VNImageRequestHandler(cgImage: cgImage, orientation: .up).perform([request])
            return (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        guard !lines.isEmpty else { throw ReceiptScanError.noText }

        let merchant = Self.merchant(from: lines)
        let amount = Self.total(from: lines) ?? ""
        let combined = lines.joined(separator: " ")
        let date = (try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue))?
            .firstMatch(in: combined, range: NSRange(location: 0, length: (combined as NSString).length))?.date ?? .now
        return ReceiptExtraction(
            merchant: merchant,
            amount: amount,
            currency: Self.currency(from: combined) ?? defaultCurrency,
            date: date,
            category: Self.category(from: combined)
        )
    }

    private static func merchant(from lines: [String]) -> String {
        let ignored = ["receipt", "invoice", "thank you", "welcome", "www.", "tel:", "phone"]
        return lines.prefix(8).first { line in
            let lowered = line.lowercased()
            let hasLetter = line.rangeOfCharacter(from: .letters) != nil
            return hasLetter && line.count >= 2 && line.count <= 80 && !ignored.contains(where: lowered.contains)
        } ?? "Receipt expense"
    }

    private static func total(from lines: [String]) -> String? {
        let preferred = lines.filter { line in
            let value = line.lowercased()
            return (value.contains("total") || value.contains("amount due") || value.contains("balance due"))
                && !value.contains("subtotal")
        }
        let candidates = preferred.isEmpty ? Array(lines.suffix(10)) : preferred
        for line in candidates.reversed() {
            let matches = line.matches(of: /(?:\d{1,3}(?:[,.]\d{3})*|\d+)[.,]\d{2}/)
            if let raw = matches.last.map({ String($0.output) }) {
                return normalizedAmount(raw)
            }
        }
        return nil
    }

    private static func normalizedAmount(_ raw: String) -> String {
        guard let comma = raw.lastIndex(of: ","), let period = raw.lastIndex(of: ".") else {
            return raw.replacingOccurrences(of: ",", with: ".")
        }
        if comma > period {
            return raw.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        }
        return raw.replacingOccurrences(of: ",", with: "")
    }

    private static func currency(from text: String) -> String? {
        let value = text.uppercased()
        if value.contains("€") || value.contains(" EUR") { return "EUR" }
        if value.contains("£") || value.contains(" GBP") { return "GBP" }
        if value.contains("¥") || value.contains(" JPY") { return "JPY" }
        if value.contains(" CAD") { return "CAD" }
        if value.contains(" AUD") { return "AUD" }
        if value.contains("$") || value.contains(" USD") { return "USD" }
        return nil
    }

    private static func category(from text: String) -> String {
        let value = text.lowercased()
        if ["restaurant", "cafe", "coffee", "kitchen", "grill", "pizza"].contains(where: value.contains) { return "Food" }
        if ["hotel", "hostel", "resort", "inn"].contains(where: value.contains) { return "Accommodation" }
        if ["uber", "taxi", "parking", "transit", "rail"].contains(where: value.contains) { return "Transportation" }
        if ["market", "grocery", "supermarket"].contains(where: value.contains) { return "Groceries" }
        if ["bar", "pub", "brewery"].contains(where: value.contains) { return "Drinks" }
        return "Other"
    }
}

private enum ReceiptScanError: Error { case invalidImage, noText }

private struct ReceiptExpenseContext: Identifiable {
    let id = UUID()
    let prefill: ExpensePrefill
}

struct ReceiptScannerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let group: APIGroup
    let members: [APIGroupMember]
    let completed: () async -> Void

    @State private var showingCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var receiptImageData: Data?
    @State private var expenseContext: ReceiptExpenseContext?
    @State private var processing = false
    @State private var errorMessage: String?
    private let ocr = ReceiptOCRService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    if let receiptImageData, let image = UIImage(data: receiptImageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 310)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay { RoundedRectangle(cornerRadius: 22).stroke(PaktlyColor.secondaryInk.opacity(0.12)) }
                    } else {
                        capturePanel
                    }

                    if processing {
                        HStack(spacing: 12) {
                            ProgressView().tint(PaktlyColor.forest)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Reading your receipt").font(.subheadline.weight(.semibold))
                                Text("Finding the merchant, total, and date…").font(.caption).foregroundStyle(PaktlyColor.secondaryInk)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 18))
                    }

                    if let errorMessage {
                        PaktlyStatusBanner(icon: "exclamationmark.triangle", title: "Check the receipt", message: errorMessage, tint: PaktlyColor.coral)
                        captureActions
                        Button("Enter the details manually") { openManualExpense() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PaktlyColor.forest)
                    } else if receiptImageData != nil && !processing {
                        captureActions
                    }

                    Label("Nothing is saved until you review the details, payer, and split.", systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle("Scan receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .fullScreenCover(isPresented: $showingCamera) {
                ReceiptDocumentCamera { pages in
                    showingCamera = false
                    guard let pages, let first = pages.first else { return }
                    receiptImageData = first
                    Task { await extract(pages) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self) else { throw ReceiptScanError.invalidImage }
                        receiptImageData = data
                        await extract([data])
                        photoItem = nil
                    } catch {
                        errorMessage = "We couldn’t read that image. Choose a clear, well-lit photo and try again."
                    }
                }
            }
            .sheet(item: $expenseContext) { context in
                ExpenseEditorView(
                    groupID: group.id,
                    currency: group.defaultCurrency,
                    members: members,
                    existing: nil,
                    prefill: context.prefill,
                    completed: {
                        await completed()
                        dismiss()
                    }
                )
                .environmentObject(model)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(PaktlyColor.forest)
                .frame(width: 72, height: 72)
                .background(PaktlyColor.mint.opacity(0.35), in: RoundedRectangle(cornerRadius: 24))
            Text("Add a receipt to \(group.name)")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PaktlyColor.ink)
                .multilineTextAlignment(.center)
            Text("Paktly reads the basics on this device, then lets you correct everything before saving.")
                .font(.subheadline)
                .foregroundStyle(PaktlyColor.secondaryInk)
                .multilineTextAlignment(.center)
        }
    }

    private var capturePanel: some View {
        VStack(spacing: 16) {
            Image(systemName: "receipt")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(PaktlyColor.forest)
            Text("Keep the full receipt inside the frame and avoid glare.")
                .font(.subheadline)
                .foregroundStyle(PaktlyColor.secondaryInk)
                .multilineTextAlignment(.center)
            captureActions
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var captureActions: some View {
        VStack(spacing: 10) {
            Button {
                errorMessage = nil
                showingCamera = true
            } label: { Label("Scan with camera", systemImage: "camera.fill").frame(maxWidth: .infinity) }
                .buttonStyle(PaktlyPrimaryButtonStyle())
                .disabled(!VNDocumentCameraViewController.isSupported || processing)

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Choose from photos", systemImage: "photo").frame(maxWidth: .infinity)
            }
            .buttonStyle(PaktlySecondaryButtonStyle())
            .disabled(processing)
        }
    }

    private func extract(_ pages: [Data]) async {
        processing = true
        errorMessage = nil
        do {
            let result = try await ocr.extract(from: pages, defaultCurrency: group.defaultCurrency)
            expenseContext = ReceiptExpenseContext(prefill: ExpensePrefill(
                description: result.merchant,
                amount: result.amount,
                currency: result.currency,
                category: result.category,
                date: result.date,
                notes: "Scanned receipt · Review completed by user"
            ))
        } catch {
            errorMessage = "We couldn’t find readable receipt details. Retake it in good light or choose another photo."
        }
        processing = false
    }

    private func openManualExpense() {
        expenseContext = ReceiptExpenseContext(prefill: ExpensePrefill(
            description: "",
            amount: "",
            currency: group.defaultCurrency,
            category: "Other",
            date: .now,
            notes: "Entered from receipt scan"
        ))
    }
}

private struct ReceiptDocumentCamera: UIViewControllerRepresentable {
    let completed: ([Data]?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(completed: completed) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    @MainActor final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completed: ([Data]?) -> Void
        init(completed: @escaping ([Data]?) -> Void) { self.completed = completed }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { completed(nil) }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { completed(nil) }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let pages = (0..<scan.pageCount).compactMap { scan.imageOfPage(at: $0).jpegData(compressionQuality: 0.9) }
            completed(pages.isEmpty ? nil : pages)
        }
    }
}
