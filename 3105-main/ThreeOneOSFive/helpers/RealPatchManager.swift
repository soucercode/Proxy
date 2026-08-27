private func handleFeature(_ feature: DemoFeature, index: Int, value: Bool) {
    guard busyIndex == nil else { return }
    
    guard state.canUseFeatures else {
        enabled.remove(index)
        state.showToast(state.isLicenseExpired ? "⚠️ Key đã hết hạn" : "⚠️ Vui lòng kích hoạt Key trước")
        return
    }
    
    // Kiểm tra có patch không
    guard let resourceName = feature.patchResource else {
        enabled.remove(index)
        failedIndices.insert(index)
        state.showToast("⚠️ Chức năng chưa có patch")
        return
    }
    
    busyIndex = index
    failedIndices.remove(index)
    
    Task { @MainActor in
        defer {
            withAnimation(.easeOut(duration: 0.16)) {
                busyIndex = nil
            }
        }
        
        let success = RealPatchManager.applyMagicPatch(
            gameBundleID: bundleID,
            isOn: value
        )
        
        if success {
            if value {
                enabled.insert(index)
                state.showToast("Đã kích hoạt thành công \(feature.name)")
            } else {
                enabled.remove(index)
                state.showToast("Đã tắt \(feature.name)")
            }
            failedIndices.remove(index)
        } else {
            enabled.remove(index)
            failedIndices.insert(index)
            state.showToast("⚠️ Chức năng đang bảo trì")
        }
    }
}
