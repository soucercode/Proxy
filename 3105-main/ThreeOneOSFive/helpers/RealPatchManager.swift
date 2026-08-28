import Foundation

enum RealPatchManager {
    private static let fm = FileManager.default
    
    // MARK: - Ghi log
    private static func writeLog(_ message: String) {
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            return
        }
        let logPath = (documentsPath as NSString).appendingPathComponent("patch_debug.log")
        let timestamp = Date().description
        let logEntry = "[\(timestamp)] \(message)\n"
        
        var existing = ""
        if let old = try? String(contentsOfFile: logPath, encoding: .utf8) {
            existing = old
        }
        let fullLog = existing + logEntry
        try? fullLog.write(toFile: logPath, atomically: true, encoding: .utf8)
        print(logEntry)
    }
    
    // MARK: - Lấy container path
    static func getContainerPath(bundleID: String) -> String? {
        writeLog("🔍 getContainerPath: \(bundleID)")
        var error: NSString?
        guard let path = MCMActivateContainerPath(2, bundleID, false, &error) else {
            writeLog("❌ MCM failed: \(error ?? "unknown")")
            return nil
        }
        writeLog("✅ Container: \(path)")
        return path
    }
    
    // MARK: - Áp dụng patch từ Definition
    static func applyPatchFromDefinition(
        definition: PatchDefinition,
        gameBundleID: String,
        isOn: Bool
    ) -> Bool {
        writeLog("========================================")
        writeLog("📦 \(definition.featureName): bundle=\(gameBundleID), isOn=\(isOn)")
        
        // Lấy container path
        guard let containerPath = getContainerPath(bundleID: gameBundleID) else {
            writeLog("❌ KHÔNG CÓ CONTAINER")
            return false
        }
        
        // Đường dẫn đích
        let fullTargetPath = (containerPath as NSString).appendingPathComponent(definition.targetPath)
        let backupPath = fullTargetPath + ".backup"
        writeLog("📁 Target: \(fullTargetPath)")
        
        let targetExists = fm.fileExists(atPath: fullTargetPath)
        writeLog("📄 File đích tồn tại: \(targetExists)")
        
        // Đọc file .3105
        guard let (project, _) = try? PatchAssetLoader.load(definition) else {
            writeLog("❌ Không load được \(definition.assetName).3105")
            return false
        }
        
        writeLog("✅ Project: \(project.name), rules: \(project.rules.count)")
        
        guard let rule = project.rules.first else {
            writeLog("❌ KHÔNG CÓ RULE")
            return false
        }
        
        writeLog("📦 replacementData size: \(rule.replacementData.count) bytes")
        
        if isOn {
            writeLog("🟢 BẬT PATCH")
            
            guard !rule.replacementData.isEmpty else {
                writeLog("❌ replacementData RỖNG")
                return false
            }
            
            // Backup nếu chưa có
            if targetExists && !fm.fileExists(atPath: backupPath) {
                do {
                    try fm.copyItem(atPath: fullTargetPath, toPath: backupPath)
                    writeLog("✅ Backup OK: \(backupPath)")
                } catch {
                    writeLog("❌ Backup FAIL: \(error)")
                    return false
                }
            } else if targetExists {
                writeLog("ℹ️ Backup đã tồn tại")
            } else {
                writeLog("⚠️ File đích không tồn tại, tạo mới")
            }
            
            // Ghi patch
            do {
                try rule.replacementData.write(to: URL(fileURLWithPath: fullTargetPath), options: .atomic)
                writeLog("✅ PATCH APPLIED: \(fullTargetPath)")
                
                let written = try? Data(contentsOf: URL(fileURLWithPath: fullTargetPath))
                if written == rule.replacementData {
                    writeLog("✅ VERIFY OK")
                    return true
                } else {
                    writeLog("❌ VERIFY FAIL")
                    return false
                }
            } catch {
                writeLog("❌ GHI PATCH FAIL: \(error)")
                return false
            }
        } else {
            writeLog("🔴 TẮT PATCH")
            
            guard fm.fileExists(atPath: backupPath) else {
                writeLog("⚠️ KHÔNG CÓ BACKUP")
                return false
            }
            
            do {
                try fm.copyItem(atPath: backupPath, toPath: fullTargetPath)
                try fm.removeItem(atPath: backupPath)
                writeLog("✅ RESTORED: \(fullTargetPath)")
                return true
            } catch {
                writeLog("❌ RESTORE FAIL: \(error)")
                return false
            }
        }
    }
}
