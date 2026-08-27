import Foundation

// MARK: - Quản lý áp dụng patch thật vào game
enum RealPatchManager {
    private static let fm = FileManager.default
    
    // MARK: - Lấy container path của game
    static func getContainerPath(bundleID: String) -> String? {
        var error: NSString?
        guard let path = MCMActivateContainerPath(2, bundleID, false, &error) else {
            print("❌ MCM failed for \(bundleID): \(error ?? "unknown")")
            return nil
        }
        print("✅ Container path: \(path)")
        return path
    }
    
    // MARK: - Lấy đường dẫn thư mục asset bundle
    static func getAssetPath(containerPath: String) -> String {
        return (containerPath as NSString).appendingPathComponent(
            "Documents/contentcache/Compulsory/ios/gameassetbundles/"
        )
    }
    
    // MARK: - Áp dụng patch từ file .3105 (kết nối với chức năng bật/tắt)
    static func applyPatchFrom3105(
        resourceName: String,
        gameBundleID: String,
        isOn: Bool
    ) -> Bool {
        print("📦 Bắt đầu áp dụng patch từ \(resourceName).3105 cho \(gameBundleID), isOn=\(isOn)")
        
        // Bước 1: Lấy container path
        guard let containerPath = getContainerPath(bundleID: gameBundleID) else {
            print("❌ Không tìm thấy container cho \(gameBundleID)")
            return false
        }
        
        let assetPath = getAssetPath(containerPath: containerPath)
        print("📁 Asset path: \(assetPath)")
        
        // Bước 2: Kiểm tra thư mục asset tồn tại
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: assetPath, isDirectory: &isDir), isDir.boolValue else {
            print("❌ Không tìm thấy thư mục asset: \(assetPath)")
            return false
        }
        
        // Bước 3: Đọc file .3105 từ bundle
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "3105") else {
            print("❌ Không tìm thấy file \(resourceName).3105 trong bundle")
            return false
        }
        print("✅ Tìm thấy file: \(url.path)")
        
        guard let data = try? Data(contentsOf: url) else {
            print("❌ Không đọc được file \(resourceName).3105")
            return false
        }
        print("✅ Đọc file thành công, dung lượng: \(data.count) bytes")
        
        // Bước 4: Giải mã file .3105
        guard let summary = try? PatchPackageCodec.inspect(data) else {
            print("❌ Không thể kiểm tra file .3105")
            return false
        }
        print("✅ Package ID: \(summary.packageID), có password: \(summary.isPasswordProtected)")
        
        guard let decoded = try? PatchPackageCodec.decode(data, password: nil) else {
            print("❌ Giải mã \(resourceName).3105 thất bại")
            return false
        }
        
        let project = decoded.project
        print("✅ Project: \(project.name), có \(project.rules.count) rules")
        
        // Bước 5: Lọc rules theo bundleID game
        let rules = project.rules.filter { $0.bundleID == gameBundleID }
        guard !rules.isEmpty else {
            print("❌ Không có rule nào cho \(gameBundleID)")
            return false
        }
        print("✅ Tìm thấy \(rules.count) rules cho \(gameBundleID)")
        
        // Bước 6: Áp dụng hoặc khôi phục từng rule
        var successCount = 0
        for (index, rule) in rules.enumerated() {
            print("📄 Rule \(index + 1): \(rule.relativePath)")
            
            // Lấy tên file từ relativePath
            let fileName = (rule.relativePath as NSString).lastPathComponent
            let targetPath = (assetPath as NSString).appendingPathComponent(fileName)
            let backupPath = targetPath + ".backup"
            
            print("📁 Target: \(targetPath)")
            print("💾 Backup: \(backupPath)")
            
            if isOn {
                // 🟢 BẬT PATCH: Ghi replacementData vào file game
                guard !rule.replacementData.isEmpty else {
                    print("❌ replacementData trống cho rule \(rule.id)")
                    continue
                }
                print("📦 replacementData size: \(rule.replacementData.count) bytes")
                
                // Backup file gốc nếu chưa có
                if fm.fileExists(atPath: targetPath) && !fm.fileExists(atPath: backupPath) {
                    do {
                        try fm.copyItem(atPath: targetPath, toPath: backupPath)
                        print("✅ Đã backup: \(backupPath)")
                    } catch {
                        print("❌ Backup thất bại: \(error)")
                        continue
                    }
                }
                
                // Ghi patch
                do {
                    try rule.replacementData.write(to: URL(fileURLWithPath: targetPath), options: .atomic)
                    print("✅ Đã áp dụng patch vào: \(targetPath)")
                    successCount += 1
                } catch {
                    print("❌ Ghi patch thất bại: \(error)")
                }
            } else {
                // 🔴 TẮT PATCH: Khôi phục từ backup hoặc originalData
                if let originalData = rule.originalData, !originalData.isEmpty {
                    // Nếu có originalData trong rule, dùng nó
                    do {
                        try originalData.write(to: URL(fileURLWithPath: targetPath), options: .atomic)
                        print("✅ Đã khôi phục từ originalData: \(targetPath)")
                        successCount += 1
                    } catch {
                        print("❌ Khôi phục từ originalData thất bại: \(error)")
                    }
                } else if fm.fileExists(atPath: backupPath) {
                    // Nếu không có originalData, dùng backup
                    do {
                        try fm.copyItem(atPath: backupPath, toPath: targetPath)
                        try fm.removeItem(atPath: backupPath)
                        print("✅ Đã khôi phục từ backup: \(targetPath)")
                        successCount += 1
                    } catch {
                        print("❌ Khôi phục từ backup thất bại: \(error)")
                    }
                } else {
                    print("⚠️ Không tìm thấy backup hoặc originalData cho: \(targetPath)")
                }
            }
        }
        
        let finalResult = successCount == rules.count
        print(finalResult ? "✅ Áp dụng patch thành công!" : "❌ Áp dụng patch thất bại, chỉ \(successCount)/\(rules.count) rules thành công")
        return finalResult
    }
    
    // MARK: - Kiểm tra trạng thái patch (đã áp dụng hay chưa)
    static func isPatchApplied(
        resourceName: String,
        gameBundleID: String
    ) -> Bool {
        guard let containerPath = getContainerPath(bundleID: gameBundleID) else {
            return false
        }
        
        let assetPath = getAssetPath(containerPath: containerPath)
        
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "3105") else {
            return false
        }
        
        guard let data = try? Data(contentsOf: url) else {
            return false
        }
        
        guard let decoded = try? PatchPackageCodec.decode(data, password: nil) else {
            return false
        }
        
        let rules = decoded.project.rules.filter { $0.bundleID == gameBundleID }
        
        for rule in rules {
            let fileName = (rule.relativePath as NSString).lastPathComponent
            let targetPath = (assetPath as NSString).appendingPathComponent(fileName)
            let backupPath = targetPath + ".backup"
            
            // Nếu có backup và file đích tồn tại → patch đang được áp dụng
            if fm.fileExists(atPath: backupPath) && fm.fileExists(atPath: targetPath) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Lấy trạng thái của tất cả rules
    static func getRulesStatus(
        resourceName: String,
        gameBundleID: String
    ) -> [(relativePath: String, isApplied: Bool)] {
        guard let containerPath = getContainerPath(bundleID: gameBundleID) else {
            return []
        }
        
        let assetPath = getAssetPath(containerPath: containerPath)
        
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "3105") else {
            return []
        }
        
        guard let data = try? Data(contentsOf: url) else {
            return []
        }
        
        guard let decoded = try? PatchPackageCodec.decode(data, password: nil) else {
            return []
        }
        
        let rules = decoded.project.rules.filter { $0.bundleID == gameBundleID }
        var result: [(String, Bool)] = []
        
        for rule in rules {
            let fileName = (rule.relativePath as NSString).lastPathComponent
            let targetPath = (assetPath as NSString).appendingPathComponent(fileName)
            let backupPath = targetPath + ".backup"
            
            let isApplied = fm.fileExists(atPath: backupPath) && fm.fileExists(atPath: targetPath)
            result.append((rule.relativePath, isApplied))
        }
        
        return result
    }
}
