import Foundation

enum ModelUsageL10n {
    enum Key {
        case title, localLogs, noRecords, unknownModel
    }

    static func text(_ key: Key, language: AppLanguage) -> String {
        let values: [String]
        switch language {
        case .simplifiedChinese:
            values = ["模型用量", "本机日志", "该周期暂无模型用量记录", "未知模型"]
        case .traditionalChinese:
            values = ["模型用量", "本機日誌", "該期間暫無模型用量紀錄", "未知模型"]
        case .english:
            values = ["Model usage", "Local logs", "No model usage in this period", "Unknown model"]
        case .japanese:
            values = ["モデル別使用量", "ローカルログ", "この期間のモデル使用記録はありません", "不明なモデル"]
        case .korean:
            values = ["모델별 사용량", "로컬 로그", "이 기간의 모델 사용 기록이 없습니다", "알 수 없는 모델"]
        case .spanish:
            values = ["Uso por modelo", "Registros locales", "Sin uso por modelo en este periodo", "Modelo desconocido"]
        }
        let index = switch key {
        case .title: 0
        case .localLogs: 1
        case .noRecords: 2
        case .unknownModel: 3
        }
        return values[index]
    }
}
