import Foundation

enum PatchAssetLoader {
    static func load(_ definition: PatchDefinition) throws -> (project: PatchProject, data: Data) {
        guard let url = Bundle.main.url(
            forResource: definition.assetName,
            withExtension: "3105",
            subdirectory: "Patches"
        ) else {
            throw NSError(
                domain: "PatchAssetLoader",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy \(definition.assetName).3105 trong thư mục Patches"]
            )
        }
        
        let data = try Data(contentsOf: url)
        let decoded = try PatchPackageCodec.decode(data, password: nil)
        return (decoded.project, data)
    }
}
