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
    
    private let languages: [(String, String)] = [
        ("Espanol", "es-ES"),
        ("Espanol (Latinoamerica)", "es-MX"),
        ("Ingles (EE.UU.)", "en-US"),
        ("Ingles (UK)", "en-GB"),
        ("Frances", "fr-FR"),
        ("Italiano", "it-IT"),
        ("Portugues", "pt-BR"),
        ("Aleman", "de-DE")
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
                
                Section("Idioma del reconocimiento de voz") {
                    Picker("Idioma", selection: Binding(
                        get: { viewModel.audioEngine.currentLocaleIdentifier },
                        set: { viewModel.audioEngine.updateLocale($0) }
                    )) {
                        ForEach(languages, id: \.1) { lang in
                            Text(lang.0).tag(lang.1)
                        }
                    }
                    .pickerStyle(.navigationLink)
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
