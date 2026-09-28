import SwiftUI
import PhotosUI
import ImageIO
import AgendaKit

// Fotografiile constatărilor (adăugire nativă, decizia utilizatorului din 27.09.2026): pe rândul constatat, butonul
// „Fotografii (N)” le arată / ascunde (ascunse implicit, ca rândul să nu se lungească), „Adaugă fotografie”
// deschide camera sau galeria. Imaginile se micșorează la cel mult 1600 px (JPEG), ~250 KB fiecare.

enum ProcesareFoto {
    static let latura: CGFloat = 1600

    /// JPEG micșorat, cu orientarea aplicată
    static func jpeg(_ img: UIImage) -> Data? {
        let s = img.size
        let k = min(1, latura / max(s.width, s.height))
        let marime = CGSize(width: (s.width * k).rounded(), height: (s.height * k).rounded())
        let f = UIGraphicsImageRendererFormat()
        f.scale = 1
        f.opaque = true
        let r = UIGraphicsImageRenderer(size: marime, format: f).image { _ in img.draw(in: CGRect(origin: .zero, size: marime)) }
        return r.jpegData(compressionQuality: 0.7)
    }

    /// Miniatura (ImageIO, fără a decoda imaginea întreagă)
    static func miniatura(_ d: Data, _ px: CGFloat) -> UIImage? {
        guard let src = CGImageSourceCreateWithData(d as CFData, nil) else { return nil }
        let o: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: px,
                                  kCGImageSourceCreateThumbnailWithTransform: true]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, o as CFDictionary).map(UIImage.init(cgImage:))
    }
}

/// Miniaturile, păstrate cât e deschisă aplicația
@MainActor
enum CacheFoto {
    private static let c = NSCache<NSString, UIImage>()
    static func miniatura(_ id: String, _ magazin: Magazin) -> UIImage? {
        if let i = c.object(forKey: id as NSString) { return i }
        guard let d = magazin.fotografie(id), let i = ProcesareFoto.miniatura(d, 360) else { return nil }
        c.setObject(i, forKey: id as NSString)
        return i
    }
}

/// Sub rândul constatat: „Fotografii (N)” (arată / ascunde) + „Adaugă fotografie”, apoi grila
struct SectiuneFotografii: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(Magazin.self) private var magazin
    @Environment(\.rem) private var rem
    let key: String
    let fotografii: [Fotografie]
    @State private var camera = false
    @State private var galerie = false
    @State private var alese: [PhotosPickerItem] = []
    @State private var deschisa: Fotografie?

    var body: some View {
        let arata = ses.fotoDeschise.contains(key) && !fotografii.isEmpty
        VStack(alignment: .leading, spacing: 0.6667 * rem) {
            FlowLayout(spatiu: 0.5556 * rem) {
                if !fotografii.isEmpty {
                    Button { ses.comutaFotografii(key) } label: {
                        HStack(spacing: 0.4444 * rem) {
                            Iconita(nume: "camera", marime: 1.2222 * rem)
                            Text("Fotografii (\(fotografii.count))").font(.system(size: 0.9444 * rem, weight: .bold))
                            Iconita(nume: arata ? "chevD" : "chevR", marime: rem)
                        }
                        .foregroundStyle(Color.accentInk)
                        .padding(.horizontal, 0.8889 * rem)
                        .frame(minHeight: tinta(3.1111 * rem))
                        .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(arata ? "Ascunde fotografiile" : "Arată fotografiile")
                }
                Menu {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { camera = true } label: { Label("Fă o fotografie", systemImage: "camera") }
                    }
                    Button { galerie = true } label: { Label("Alege din galerie", systemImage: "photo.on.rectangle") }
                } label: {
                    HStack(spacing: 0.4444 * rem) {
                        Iconita(nume: "plus", marime: 1.1111 * rem)
                        Text(fotografii.isEmpty ? "Adaugă fotografie" : "Adaugă").font(.system(size: 0.9444 * rem, weight: .bold))
                    }
                    .foregroundStyle(Color.text)
                    .padding(.horizontal, 0.8889 * rem)
                    .frame(minHeight: tinta(3.1111 * rem))
                    .background(Color.surface2, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(Color.line, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                }
            }
            if arata {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 7.7778 * rem), spacing: 0.5556 * rem)], alignment: .leading, spacing: 0.5556 * rem) {
                    ForEach(fotografii, id: \.id) { f in
                        Button { deschisa = f } label: { miniatura(f) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Fotografia din \(dataFoto(f))")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $camera) {
            Camera { img in
                camera = false
                if let img, let d = ProcesareFoto.jpeg(img) { ses.adaugaFotografii(key, [d]) }
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $galerie, selection: $alese, maxSelectionCount: 10, matching: .images)
        .onChange(of: alese) { _, l in
            guard !l.isEmpty else { return }
            alese = []
            Task {
                var date: [Data] = []
                for item in l {
                    if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d), let j = ProcesareFoto.jpeg(img) { date.append(j) }
                }
                ses.adaugaFotografii(key, date)
            }
        }
        .fullScreenCover(item: $deschisa) { f in
            VederFotografie(f: f, date: magazin.fotografie(f.id)) { deschisa = nil } sterge: {
                deschisa = nil
                ses.stergeFotografie(key, f.id)
            }
        }
    }

    private func miniatura(_ f: Fotografie) -> some View {
        Color.surface2
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let i = CacheFoto.miniatura(f.id, magazin) {
                    Image(uiImage: i).resizable().scaledToFill()
                } else {
                    Text("Lipsește").font(.system(size: 0.8333 * rem, weight: .semibold)).foregroundStyle(Color.muted)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous).strokeBorder(Color.line, lineWidth: 1))
    }
}

func dataFoto(_ f: Fotografie) -> String {
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let d = fmt.date(from: f.data) else { return "" }
    let c = Calendar.current.dateComponents([.hour, .minute], from: d)
    return fmtDate(todayISO(d)) + String(format: ", %02d:%02d", c.hour ?? 0, c.minute ?? 0)
}

extension Fotografie: @retroactive Identifiable {}

/// Fotografia pe tot ecranul, cu data, „Șterge” (cu confirmare) și „Închide”
struct VederFotografie: View {
    @Environment(\.rem) private var rem
    let f: Fotografie
    let date: Data?
    let inchide: () -> Void
    let sterge: () -> Void
    @State private var confirma = false
    @State private var zoom: CGFloat = 1

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0.6667 * rem) {
                Text(dataFoto(f)).font(.system(size: rem, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { confirma = true } label: {
                    Label("Șterge", systemImage: "trash").font(.system(size: rem, weight: .bold)).foregroundStyle(Color(hex: 0xff8a80))
                        .padding(.horizontal, rem).frame(minHeight: 44)
                }
                Button(action: inchide) {
                    Text("Închide").font(.system(size: rem, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, rem).frame(minHeight: 44)
                        .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
                }
            }
            .padding(.horizontal, rem).padding(.vertical, 0.5556 * rem)
            GeometryReader { g in
                if let date, let img = UIImage(data: date) {
                    Image(uiImage: img).resizable().scaledToFit()
                        .scaleEffect(zoom)
                        .frame(width: g.size.width, height: g.size.height)
                        .gesture(MagnifyGesture().onChanged { zoom = max(1, min(4, $0.magnification)) }.onEnded { _ in withAnimation { zoom = 1 } })
                } else {
                    Text("Fișierul fotografiei lipsește de pe \(dsp("această tabletă", "acest telefon")).").foregroundStyle(.white.opacity(0.8))
                        .frame(width: g.size.width, height: g.size.height)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .confirmationDialog("Ștergeți fotografia?", isPresented: $confirma, titleVisibility: .visible) {
            Button("Șterge", role: .destructive, action: sterge)
            Button("Renunță", role: .cancel) {}
        } message: {
            Text("Se poate recupera cu Anulează, cât timp aplicația e deschisă.")
        }
    }
}

/// Camera (UIImagePickerController)
struct Camera: UIViewControllerRepresentable {
    let gata: (UIImage?) -> Void
    func makeCoordinator() -> Coord { Coord(gata) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let gata: (UIImage?) -> Void
        init(_ gata: @escaping (UIImage?) -> Void) { self.gata = gata }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            gata(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { gata(nil) }
    }
}
