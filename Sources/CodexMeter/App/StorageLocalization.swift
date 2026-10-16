import Foundation

enum StorageL10n {
    enum Key: Int {
        case empty, customDays, cancel, success, error
    }
    static func text(_ key: Key, language: AppLanguage) -> String {
        let values: [String]
        switch language {
        case .simplifiedChinese:
            values = ["暂无使用记录", "保留天数", "取消", "清理完成，已回收可释放的空间。", "存储操作失败"]
        case .traditionalChinese:
            values = ["暫無使用紀錄", "保留天數", "取消", "清理完成，已回收可釋放的空間。", "儲存操作失敗"]
        case .japanese:
            values = ["使用履歴なし", "保持する日数", "キャンセル", "削除が完了し、空き容量を回収しました。", "保存操作に失敗しました"]
        case .korean:
            values = ["사용 기록 없음", "보관 일수", "취소", "정리가 완료되어 공간이 확보되었습니다.", "저장 작업 실패"]
        case .spanish:
            values = ["Sin registros", "Días a conservar", "Cancelar", "Limpieza completada y espacio recuperado.", "Error de almacenamiento"]
        case .english:
            values = ["No usage records", "Days to keep", "Cancel", "Cleanup complete. Available space has been reclaimed.", "Storage operation failed"]
        }
        return values[key.rawValue]
    }

}
