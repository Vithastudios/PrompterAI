import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: PrompterViewModel
    @Environment(\.dismiss) var dismiss
    
    private let colors: [(String, UIColor)] = [
        ("Blanco", .white),
        ("Amarillo", .yellow),
        ("Verde", .green),
        ("Rojo", .red),
        ("Cian", .cyan)
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Tamano de letra") {
                    Slider(value: $viewModel.fontSize, in: 10...72, step: 1) { editing in
                        if !editing {
                            viewModel.applyFontSize(viewModel.fontSize)
                        }
                    }
                    Text("\(Int(viewModel.fontSize)) pt")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                Section("Color del texto") {
                    ForEach(colors, id: \.0) { item in
                        Button {
                            viewModel.updateTextColor(item.1)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(item.1))
                                    .frame(width: 24, height: 24)
                                Text(item.0)
                                    .foregroundColor(.primary)
                                Spacer()
                                if viewModel.textColor == item.1 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Configuracion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}
