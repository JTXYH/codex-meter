import Foundation

enum ResetCreditsL10n {
    enum Key: Int {
        case title, available, fullReset, fullResetScope, expires, neverExpires
        case emptyTitle, emptyDetail, unavailableTitle, unavailableDetail, detailsUnavailable
        case unknownType
    }

    static func text(_ key: Key, language: AppLanguage) -> String {
        let values: [String]
        switch language {
        case .simplifiedChinese:
            values = ["充值卡", "张可用", "完全重置", "恢复 5 小时与每周额度", "到期", "永不过期", "暂无可用充值卡", "获得新卡后，会显示在这里。", "暂时无法读取充值卡", "请稍后刷新。", "卡片详情暂不可用", "额度重置"]
        case .traditionalChinese:
            values = ["充值卡", "張可用", "完全重置", "恢復 5 小時與每週額度", "到期", "永不過期", "目前沒有可用充值卡", "取得新卡後，會顯示在這裡。", "暫時無法讀取充值卡", "請稍後重新整理。", "卡片詳情暫時無法使用", "額度重置"]
        case .english:
            values = ["Reset cards", "available", "Full reset", "Restores 5-hour and weekly limits", "expires", "Never expires", "No reset cards available", "New cards will appear here.", "Unable to load reset cards", "Please refresh later.", "Card details unavailable", "Limit reset"]
        case .japanese:
            values = ["リセットカード", "枚利用可能", "完全リセット", "5 時間枠と週間枠を回復", "期限", "有効期限なし", "利用可能なカードはありません", "新しいカードを取得すると、ここに表示されます。", "カードを読み込めません", "後でもう一度更新してください。", "カードの詳細を取得できません", "上限リセット"]
        case .korean:
            values = ["초기화 카드", "개 사용 가능", "전체 초기화", "5시간 및 주간 한도 복원", "만료", "만료 없음", "사용 가능한 카드가 없습니다", "새 카드를 받으면 여기에 표시됩니다.", "카드를 불러올 수 없습니다", "나중에 새로고침하세요.", "카드 상세 정보를 사용할 수 없습니다", "한도 초기화"]
        case .spanish:
            values = ["Tarjetas de reinicio", "disponibles", "Reinicio completo", "Restaura los límites de 5 horas y semanales", "vence", "Sin vencimiento", "No hay tarjetas disponibles", "Las tarjetas nuevas aparecerán aquí.", "No se pueden cargar las tarjetas", "Actualiza más tarde.", "Detalles no disponibles", "Reinicio del límite"]
        }
        return values[key.rawValue]
    }

    static func countOnly(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: "已有 \(count) 张可用卡片，稍后再查看详情。"
        case .traditionalChinese: "已有 \(count) 張可用卡片，請稍後再查看詳情。"
        case .english: "\(count) cards available. Check back later for details."
        case .japanese: "\(count) 枚利用できます。詳細は後でもう一度確認してください。"
        case .korean: "\(count)개의 카드를 사용할 수 있습니다. 자세한 정보는 나중에 확인하세요."
        case .spanish: "Hay \(count) tarjetas disponibles. Consulta los detalles más tarde."
        }
    }

    static func missingDetails(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: "另有 \(count) 张可用卡片，详情暂不可用"
        case .traditionalChinese: "另有 \(count) 張可用卡片，詳情暫時無法使用"
        case .english: "Details unavailable for \(count) more available cards"
        case .japanese: "ほかに \(count) 枚利用可能ですが、詳細を取得できません"
        case .korean: "사용 가능한 카드 \(count)개의 상세 정보를 불러올 수 없습니다"
        case .spanish: "Faltan los detalles de otras \(count) tarjetas disponibles"
        }
    }
}
