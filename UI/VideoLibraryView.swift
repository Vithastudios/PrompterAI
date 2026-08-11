import SwiftUI

struct VideoLibraryView: View {
    @ObservedObject var viewModel: PrompterViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var videos: [VideoEntity] = []
    
    var body: some View {
        NavigationView {
            Group {
                if videos.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Todavia no hay videos grabados")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Graba tu primer video desde la pantalla principal.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(videos, id: \.objectID) { video in
                            VideoRow(video: video, manager: viewModel.videoLibraryManager)
                        }
                        .onDelete { offsets in
                            for idx in offsets {
                                viewModel.videoLibraryManager.deleteVideo(videos[idx])
                            }
                            reload()
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Mis Videos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .task { reload() }
    }
    
    private func reload() {
        viewModel.videoLibraryManager.fetchVideos { results in
            videos = results
        }
    }
}

private struct VideoRow: View {
    let video: VideoEntity
    let manager: VideoLibraryManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "video.fill")
                    .foregroundColor(.blue)
                Text(video.resolutionName ?? "Video")
                    .font(.headline)
                Spacer()
                Text(formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(formattedDate)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(formattedDuration)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let url = manager.url(for: video) {
                ShareLink(item: url) {
                    Label("Compartir / Exportar", systemImage: "square.and.arrow.up")
                        .font(.callout)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var formattedDate: String {
        guard let date = video.createdAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private var formattedDuration: String {
        let seconds = Int(video.duration)
        guard seconds > 0 else { return "" }
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private var formattedSize: String {
        let bytes = Double(video.fileSize)
        guard bytes > 0 else { return "" }
        if bytes >= 1_000_000 {
            return String(format: "%.1f MB", bytes / 1_000_000)
        }
        return String(format: "%.0f KB", bytes / 1_000)
    }
}
