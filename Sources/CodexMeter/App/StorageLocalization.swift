import Foundation

enum StorageL10n {
    enum Key: Int {
        case title, hint, diskSize, imageSize, history, empty, cleanup, range, customDays,
             all, clean, confirm, cancel, confirmHint, preservation, success, refresh, error, checkpoints
    }
    static func text(_ key: Key, language: AppLanguage) -> String {
        let values: [String]
        switch language {
        case .simplifiedChinese:
            values = ["数据管理", "查看本机存储占用，按时间清理使用记录。", "本机数据大小", "其中背景图片", "已保存的统计", "暂无使用记录", "清理使用记录", "清理范围", "保留天数", "全部已记录的统计", "清理数据…", "确认清理", "取消", "将删除此时间之前的 Token 与费用统计：", "保留应用设置和背景图片，不删除 Codex 会话日志。已清理的旧统计不会再次导入；新的用量会继续记录。", "清理完成，已回收可释放的空间。", "刷新大小", "存储操作失败", "数据库保留少量读取进度，以避免重复导入。"]
        case .traditionalChinese:
            values = ["資料管理", "查看本機儲存空間，依時間清理使用紀錄。", "本機資料大小", "其中背景圖片", "已儲存的統計", "暫無使用紀錄", "清理使用紀錄", "清理範圍", "保留天數", "全部已記錄的統計", "清理資料…", "確認清理", "取消", "將刪除此時間之前的 Token 與費用統計：", "保留應用程式設定和背景圖片，不刪除 Codex 會話日誌。已清理的舊統計不會再次匯入；新的用量會繼續記錄。", "清理完成，已回收可釋放的空間。", "重新整理大小", "儲存操作失敗", "資料庫保留少量讀取進度，以避免重複匯入。"]
        case .japanese:
            values = ["データ管理", "ローカルの保存容量を確認し、期間を指定して使用履歴を削除します。", "保存容量", "背景画像", "保存済みの統計", "使用履歴なし", "使用履歴の削除", "削除範囲", "保持する日数", "記録済みの統計すべて", "データを削除…", "削除する", "キャンセル", "次の日時より前のトークンと費用の統計を削除します：", "設定、背景画像、Codex の会話ログは保持されます。削除した統計は再取り込みせず、新しい使用量の記録は続きます。", "削除が完了し、空き容量を回収しました。", "容量を更新", "保存操作に失敗しました", "再取り込みを防ぐため、少量の読み取り位置を保持します。"]
        case .korean:
            values = ["데이터 관리", "로컬 저장 공간을 확인하고 기간별 사용 기록을 정리합니다.", "로컬 데이터 크기", "배경 이미지", "저장된 통계", "사용 기록 없음", "사용 기록 정리", "정리 범위", "보관 일수", "기록된 모든 통계", "데이터 정리…", "정리 확인", "취소", "다음 시점 이전의 토큰 및 비용 통계를 삭제합니다:", "설정, 배경 이미지 및 Codex 대화 로그는 유지됩니다. 삭제한 통계는 다시 가져오지 않으며 새 사용량은 계속 기록됩니다.", "정리가 완료되어 공간이 확보되었습니다.", "크기 새로고침", "저장 작업 실패", "중복 가져오기를 방지하기 위해 읽기 위치를 유지합니다."]
        case .spanish:
            values = ["Datos", "Consulta el espacio local y elimina registros por antigüedad.", "Tamaño de datos", "Imágenes de fondo", "Estadísticas guardadas", "Sin registros", "Eliminar registros de uso", "Intervalo", "Días a conservar", "Todas las estadísticas registradas", "Limpiar datos…", "Confirmar eliminación", "Cancelar", "Se eliminarán los tokens y costes anteriores a:", "Se conservan los ajustes, fondos y registros de conversaciones de Codex. Los datos eliminados no se importarán de nuevo; se seguirá registrando el uso nuevo.", "Limpieza completada y espacio recuperado.", "Actualizar tamaño", "Error de almacenamiento", "Se conservan las posiciones de lectura para evitar importaciones duplicadas."]
        case .english:
            values = ["Data", "Review local storage and remove usage records by age.", "Local data size", "Background images", "Saved statistics", "No usage records", "Clean usage records", "Cleanup range", "Days to keep", "All recorded statistics", "Clean data…", "Confirm cleanup", "Cancel", "Delete token and cost statistics before:", "Settings, backgrounds and Codex conversation logs are preserved. Removed statistics will not be imported again; new usage will continue to be recorded.", "Cleanup complete. Available space has been reclaimed.", "Refresh size", "Storage operation failed", "A small amount of scan progress is retained to prevent duplicate imports."]
        }
        return values[key.rawValue]
    }

    static func olderThan(_ days: Int, language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: "清理 \(days) 天前的统计"
        case .traditionalChinese: "清理 \(days) 天前的統計"
        case .english: "Older than \(days) days"
        case .japanese: "\(days) 日より前の統計"
        case .korean: "\(days)일 이전 통계"
        case .spanish: "Anteriores a \(days) días"
        }
    }
}
