import Foundation

// MARK: - Quản lý áp dụng patch từ file .3105 vào game
enum RealPatchManager {
    private static let fm = FileManager.default
    
    // MARK: - Lấy container path của game
    static func getContainerPath(bundleID: String) -> String? {
        var error: NSString?
        guard let path = MCMActivateContainerPath(2, bundleID, false, &error) else {
            print("❌ MCM failed: \(error ?? "unknown")")
            return nil
        }
        print("✅ Container: \(path)")
        return path
    }
    
    // MARK: - Áp dụng patch từ file .3105
    static func applyPatchFrom3105(
        resourceName: String,
        gameBundleID: String,
        isOn: Bool
    ) -> Bool {
        // Bước 1: Lấy container path
        guard let containerPath = getContainerPath(bundleID: gameBundleID) else {
            print("❌ Không tìm thấy container")
            return false
        }
        
        // Bước 2: Xác định đường dẫn đích
        let targetPath = (containerPath as NSString).appendingPathComponent(
            "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
        )
        let backupPath = targetPath + ".backup"
        print("📁 Target: \(targetPath)")
        
        // Bước 3: Đọc file .3105 từ bundle
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "3105") else {
            print("❌ Không tìm thấy \(resourceName).3105")
            return false
        }
        
        guard let data = try? Data(contentsOf: url) else {
            print("❌ Không đọc được file")
            return false
        }
        
        // Bước 4: Giải mã .3105
        guard let decoded = try? PatchPackageCodec.decode(data, password: nil) else {
            print("❌ Giải mã thất bại")
            return false
        }
        
        let project = decoded.project
        print("✅ Project: \(project.name), rules: \(project.rules.count)")
        
        // Bước 5: Lấy rule đầu tiên (hoặc rule phù hợp)
        guard let rule = project.rules.first else {
            print("❌ Không có rule nào")
            return false
        }
        
        // Bước 6: Áp dụng hoặc khôi phục
        if isOn {
            // 🟢 BẬT: Ghi replacementData vào file đích
            guard !rule.replacementData.isEmpty else {
                print("❌ replacementData rỗng")
                return false
            }
            
            // Backup nếu chưa có
            if fm.fileExists(atPath: targetPath) && !fm.fileExists(atPath: backupPath) {
                do {
                    try fm.copyItem(atPath: targetPath, toPath: backupPath)
                    print("✅ Backup: \(backupPath)")
                } catch {
                    print("❌ Backup thất bại: \(error)")
                    return false
                }
            }
            
            // Ghi patch
            do {
                try rule.replacementData.write(to: URL(fileURLWithPath: targetPath), options: .atomic)
                print("✅ Patch applied: \(targetPath)")
                return true
            } catch {
                print("❌ Ghi patch thất bại: \(error)")
                return false
            }
        } else {
            // 🔴 TẮT: Khôi phục từ backup
            guard fm.fileExists(atPath: backupPath) else {
                print("⚠️ Không có backup")
                return false
            }
            
            do {
                try fm.copyItem(atPath: backupPath, toPath: targetPath)
                try fm.removeItem(atPath: backupPath)
                print("✅ Restored: \(targetPath)")
                return true
            } catch {
                print("❌ Khôi phục thất bại: \(error)")
                return false
            }
        }
    }
}
