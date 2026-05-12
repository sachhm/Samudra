import SwiftUI

struct ExportSheet: View {
    @Binding var metadata: VoyageMetadata
    let hazardCount: Int
    let ntmCount: Int
    let onExport: (ExportFormat) -> Void
    let onCancel: () -> Void

    @State private var selectedFormat: ExportFormat = .pdf
    @State private var isExporting: Bool = false
    @State private var lastError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Voyage") {
                    TextField("Vessel name", text: $metadata.vesselName)
                    TextField("IMO number", text: $metadata.imoNumber)
                        .keyboardType(.numberPad)
                    TextField("Callsign", text: $metadata.callsign)
                        .textInputAutocapitalization(.characters)
                    DatePicker("Date", selection: $metadata.voyageDate, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Pilot") {
                    TextField("Pilot name", text: $metadata.pilotName)
                    TextField("License #", text: $metadata.pilotLicense)
                }

                Section("Route") {
                    TextField("Departure port", text: $metadata.departurePort)
                    TextField("Arrival port", text: $metadata.arrivalPort)
                    TextField("Chart number", text: $metadata.chartNumber)
                }

                Section("Annotations") {
                    LabeledContent("Hazards") { Text("\(hazardCount)") }
                    LabeledContent("Notices to Mariner") { Text("\(ntmCount)") }
                    // TODO: route distance once route stroke length wired
                    // TODO: estimated transit time
                }

                Section("Briefing notes") {
                    TextField("Free-form notes", text: $metadata.notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases) { fmt in
                            Label(fmt.label, systemImage: fmt.symbol).tag(fmt)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if let lastError {
                    Section {
                        Label(lastError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(ChartPalette.hazardRed)
                    }
                }
            }
            .navigationTitle("Export Passage Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isExporting = true
                        onExport(selectedFormat)
                    } label: {
                        if isExporting {
                            ProgressView()
                        } else {
                            Text("Export")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isExporting)
                }
            }
        }
    }
}
