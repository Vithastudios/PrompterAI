import SwiftUI

struct ScriptEditorView: View {
    @ObservedObject var viewModel: PrompterViewModel
    @Environment(\.dismiss) var dismiss
    
    var script: ScriptEntity?
    var onSave: (String, String) -> Void
    
    @State private var title: String = ""
    @State private var content: String = ""
    
    init(viewModel: PrompterViewModel,
         script: ScriptEntity? = nil,
         onSave: @escaping (String, String) -> Void) {
        self.viewModel = viewModel
        self.script = script
        self.onSave = onSave
        _title = State(initialValue: script?.title ?? "")
        _content = State(initialValue: script?.content ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Titulo") {
                    TextField("Nombre del guion", text: $title)
                }
                Section("Contenido") {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle(script == nil ? "Nuevo Guion" : "Editar Guion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onSave(title, content)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty ||
                              content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
