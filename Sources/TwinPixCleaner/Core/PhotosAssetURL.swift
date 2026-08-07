import Foundation
import Photos

/// A `photos://asset?id=…` URL is how this app represents a `PHAsset` wherever a
/// filesystem `URL` is otherwise expected (see `CLAUDE.md`). Building and parsing that
/// URL was previously copy-pasted at every call site that needed to go from one
/// representation to the other; this centralizes it.
enum PhotosAssetURL {
    static func build(for localIdentifier: String) -> URL {
        var components = URLComponents()
        components.scheme = "photos"
        components.host = "asset"
        components.queryItems = [URLQueryItem(name: "id", value: localIdentifier)]
        // Fallback is a static, always-valid literal — the dynamic localIdentifier is the
        // only part that could theoretically fail percent-encoding, so this never masks a
        // real per-asset failure, it just avoids a force-unwrap crash if it ever did.
        return components.url ?? URL(string: "photos://asset")!
    }

    static func localIdentifier(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let idItem = components.queryItems?.first(where: { $0.name == "id" }) else {
            return nil
        }
        return idItem.value
    }

    static func asset(from url: URL) -> PHAsset? {
        guard let localIdentifier = localIdentifier(from: url) else { return nil }
        return PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
    }
}
