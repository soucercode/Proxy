import Foundation

enum RealPatchManager {
    private static let fm = FileManager.default
    
    // MARK: - Ghi log ra file trong Documents
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
    
    // MARK: - Lấy container path của game
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
    
    // MARK: - Áp dụng patch cho 1 game cụ thể
    static func applyPatchToSingleGame(
        definition: PatchDefinition,
        gameBundleID: String,
        isOn: Bool
    ) -> Bool {
        writeLog("========================================")
        writeLog("📦 \(definition.featureName) -> \(gameBundleID), isOn=\(isOn)")
        
        // Bước 1: Lấy container path
        guard let containerPath = getContainerPath(bundleID: gameBundleID) else {
            writeLog("❌ KHÔNG CÓ CONTAINER cho \(gameBundleID)")
            return false
        }
        
        // Bước 2: Xác định đường dẫn đích
        let fullTargetPath = (containerPath as NSString).appendingPathComponent(definition.targetPath)
        let backupPath = fullTargetPath + ".backup"
        writeLog("📁 Target: \(fullTargetPath)")
        writeLog("💾 Backup: \(backupPath)")
        
        let targetExists = fm.fileExists(atPath: fullTargetPath)
        writeLog("📄 File đích tồn tại: \(targetExists)")
        
        // Bước 3: Load file .3105 theo đúng game
        guard let (project, _) = try? PatchAssetLoader.load(
            definition: definition,
            gameBundleID: gameBundleID
        ) else {
            writeLog("❌ Không load được file cho \(gameBundleID)")
            return false
        }
        
        writeLog("✅ Project: \(project.name), rules: \(project.rules.count)")
        
        guard let rule = project.rules.first else {
            writeLog("❌ KHÔNG CÓ RULE")
            return false
        }
        
        writeLog("📦 replacementData size: \(rule.replacementData.count) bytes")
        writeLog("📦 originalData size: \(rule.originalData?.count ?? 0) bytes")
        
        // Bước 4: Áp dụng hoặc khôi phục
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
                writeLog("⚠️ File đích không tồn tại, sẽ tạo mới")
            }
            
            // Ghi patch
            do {
                try rule.replacementData.write(to: URL(fileURLWithPath: fullTargetPath), options: .atomic)
                writeLog("✅ PATCH APPLIED: \(fullTargetPath)")
                
                // Verify
                let written = try? Data(contentsOf: URL(fileURLWithPath: fullTargetPath))
                if written == rule.replacementData {
                    writeLog("✅ VERIFY OK")
                    return true
                } else {
                    writeLog("❌ VERIFY FAIL: dữ liệu không khớp")
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
    
    // MARK: - Áp dụng patch cho game đang chọn (gọi từ GameDemoView)
    static func applyPatchFromDefinition(
        definition: PatchDefinition,
        gameBundleID: String,
        isOn: Bool
    ) -> Bool {
        writeLog("========================================")
        writeLog("🚀 applyPatchFromDefinition: \(definition.featureName)")
        writeLog("🎮 gameBundleID: \(gameBundleID)")
        writeLog("🔄 isOn: \(isOn)")
        
        // Chỉ áp dụng cho game đang chọn
        let result = applyPatchToSingleGame(
            definition: definition,
            gameBundleID: gameBundleID,
            isOn: isOn
        )
        
        writeLog("📊 Kết quả: \(result ? "✅ THÀNH CÔNG" : "❌ THẤT BẠI")")
        return result
    }
    
    // MARK: - Áp dụng patch cho CẢ 2 GAME (dùng nếu muốn bật 1 lần cho cả 2)
    static func applyPatchToBothGames(
        definition: PatchDefinition,
        isOn: Bool
    ) -> (freefire: Bool, freefiremax: Bool) {
        writeLog("========================================")
        writeLog("🚀 Áp dụng cho CẢ 2 GAME: \(definition.featureName), isOn=\(isOn)")
        
        let ffResult = applyPatchToSingleGame(
            definition: definition,
            gameBundleID: "com.dts.freefireth",
            isOn: isOn
        )
        
        let ffmaxResult = applyPatchToSingleGame(
            definition: definition,
            gameBundleID: "com.dts.freefiremax",
            isOn: isOn
        )
        
        writeLog("📊 Free Fire: \(ffResult ? "✅" : "❌")")
        writeLog("📊 Free Fire Max: \(ffmaxResult ? "✅" : "❌")")
        
        return (ffResult, ffmaxResult)
    }
}
