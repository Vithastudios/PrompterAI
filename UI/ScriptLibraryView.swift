import SwiftUI

struct ScriptLibraryView: View {
    @ObservedObject var viewModel: PrompterViewModel
    @Environment(\.dismiss) var dismiss
    @State private var scripts: [ScriptEntity] = []
    @State private var showNewScript = false
    @State private var scriptToEdit: ScriptEntity?
    @State private var showEditor = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(scripts, id: \.objectID) { script in
                    Button(action: { load(script) }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(script.title ?? "Sin titulo")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(script.content ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions {
                        Button {
                            scriptToEdit = script
                            showEditor = true
                        } label: {
                            Label("Editar", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            delete(script)
                        } label: {
                            Label("Borrar", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Mis Guiones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        scriptToEdit = nil
                        showNewScript = true
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                ScriptEditorView(viewModel: viewModel,
                                 script: scriptToEdit) { title, content in
                    if let script = scriptToEdit {
                        viewModel.dataManager.updateScript(script, title: title, content: content)
                    } else {
                        viewModel.dataManager.createScript(title: title, content: content)
                    }
                    reload()
                }
            }
        }
        .task { reload() }
    }
    
    private func load(_ script: ScriptEntity) {
        viewModel.updateScript(script.content ?? "")
        dismiss()
    }
    
    private func delete(_ script: ScriptEntity) {
        viewModel.dataManager.deleteScript(script: script)
        reload()
    }
    
    private func reload() {
        viewModel.dataManager.fetchScripts { results, _ in
            scripts = results
        }
    }
}
