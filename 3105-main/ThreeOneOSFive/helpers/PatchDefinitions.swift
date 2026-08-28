import Foundation

struct PatchDefinition: Identifiable {
    let id: String
    let featureName: String
    let assetName: String
    let targetPath: String
}

enum PatchDefinitions {
    static let all: [PatchDefinition] = [
        PatchDefinition(
            id: "aim_body",
            featureName: "Proxy Aim Body",
            assetName: "AimBody",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
        ),
        PatchDefinition(
            id: "aim_neck_v1",
            featureName: "Proxy Aim Neck V1",
            assetName: "AimNeckV1",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
        ),
        PatchDefinition(
            id: "aim_neck_v2",
            featureName: "Proxy Aim Neck V2",
            assetName: "AimNeckV2",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
        ),
        PatchDefinition(
            id: "magic_v4",
            featureName: "Magic V4",
            assetName: "MagicV4",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
        )
    ]
    
    static func forFeatureName(_ name: String) -> PatchDefinition? {
        all.first { $0.featureName == name }
    }
    
    static func forAssetName(_ assetName: String) -> PatchDefinition? {
        all.first { $0.assetName == assetName }
    }
}
