import Foundation

enum ModelUsageL10n {
    enum Key {
        case title, localLogs, noRecords, unknownModel, share, shareHint, shareUnavailable
    }

    static func text(_ key: Key, language: AppLanguage) -> String {
        let values: [String]
        switch language {
        case .simplifiedChinese:
            values = ["模型用量", "本机日志", "该周期暂无模型用量记录", "未知模型", "使用占比", "按所选周期接口返回的模型用量权重计算，不是 Token 占比。", "接口未提供完整的模型用量权重"]
        case .traditionalChinese:
            values = ["模型用量", "本機日誌", "該期間暫無模型用量紀錄", "未知模型", "使用占比", "依所選期間介面回傳的模型用量權重計算，並非 Token 占比。", "介面未提供完整的模型用量權重"]
        case .english:
            values = ["Model usage", "Local logs", "No model usage in this period", "Unknown model", "Usage share", "Based on the model usage weights returned by the account API for this period, not token counts.", "The API did not return complete model usage weights"]
        case .japanese:
            values = ["モデル別使用量", "ローカルログ", "この期間のモデル使用記録はありません", "不明なモデル", "使用割合", "選択した期間の API のモデル使用量に基づく割合です。Token 数の割合ではありません。", "API のモデル使用量データが不足しています"]
        case .korean:
            values = ["모델별 사용량", "로컬 로그", "이 기간의 모델 사용 기록이 없습니다", "알 수 없는 모델", "사용 비율", "선택한 기간에 API가 반환한 모델 사용량 가중치로 계산하며, Token 수의 비율이 아닙니다.", "API가 완전한 모델 사용량 가중치를 제공하지 않았습니다"]
        case .spanish:
            values = ["Uso por modelo", "Registros locales", "Sin uso por modelo en este periodo", "Modelo desconocido", "Porcentaje de uso", "Se calcula con los pesos de uso de modelos devueltos por la API para este periodo, no con el número de tokens.", "La API no devolvió todos los pesos de uso por modelo"]
        }
        let index = switch key {
        case .title: 0
        case .localLogs: 1
        case .noRecords: 2
        case .unknownModel: 3
        case .share: 4
        case .shareHint: 5
        case .shareUnavailable: 6
        }
        return values[index]
    }

    static func share(_ value: Double?, language: AppLanguage) -> String {
        guard let value, value.isFinite, (0...1).contains(value) else { return "—" }
        let precision = value > 0 && value < 0.0001 ? 4 : 2
        let format = FloatingPointFormatStyle<Double>.Percent(locale: language.locale)
            .precision(.fractionLength(0...precision))
        if value > 0 && value < 0.000001 { return "<" + 0.000001.formatted(format) }
        return value.formatted(format)
    }
}
