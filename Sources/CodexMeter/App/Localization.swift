import Foundation

enum L10n {
    enum Key {
        case menuBarHelp
        case showEmail
        case hideEmail
        case refreshQuota
        case settings
        case quit
        case followCodexAppApprovalHint
        case appearance
        case appearanceSystem
        case appearanceLight
        case appearanceDark
        case language
        case searchLanguage
        case noLanguagesFound
        case custom
        case retry
        case remainingQuota
        case noQuotaWindow
        case noQuotaExplanation
        case todayDetails
        case calculatingUsage
        case monthlyUsage
        case monthlyUsageRange
        case thisMonth
        case activityOverview
        case lastSevenDays
        case hoverHeatmap
        case less
        case more
        case creditsBalance
        case creditsBalanceUnavailable
        case unlimitedCredits
        case lifetimeTokens
        case longestStreak
        case longestTask
        case notAvailable
    }

    static func text(_ key: Key, language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese:
            simplifiedChinese(key)
        case .traditionalChinese:
            traditionalChinese(key)
        case .english:
            english(key)
        case .japanese:
            japanese(key)
        case .korean:
            korean(key)
        case .spanish:
            spanish(key)
        }
    }

    static func appearanceTitle(_ appearance: AppAppearance, language: AppLanguage) -> String {
        switch appearance {
        case .system: text(.appearanceSystem, language: language)
        case .light: text(.appearanceLight, language: language)
        case .dark: text(.appearanceDark, language: language)
        }
    }

    static func refreshIntervalTitle(_ interval: AutomaticRefreshInterval, language: AppLanguage) -> String {
        guard let minutes = interval.presetMinutes else {
            return text(.custom, language: language)
        }
        return refreshMinutesTitle(minutes, language: language)
    }

    static func refreshMinutesTitle(_ minutes: Int, language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese:
            return "每 \(minutes) 分钟"
        case .traditionalChinese:
            return "每 \(minutes) 分鐘"
        case .english:
            return minutes == 1 ? "Every minute" : "Every \(minutes) minutes"
        case .japanese:
            return "\(minutes) 分ごと"
        case .korean:
            return "\(minutes)분마다"
        case .spanish:
            return minutes == 1 ? "Cada minuto" : "Cada \(minutes) minutos"
        }
    }

    static func remaining(_ percent: Int, language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: "剩余 \(percent)%"
        case .traditionalChinese: "剩餘 \(percent)%"
        case .english: "\(percent)% remaining"
        case .japanese: "残り \(percent)%"
        case .korean: "\(percent)% 남음"
        case .spanish: "\(percent)% restante"
        }
    }

    static func streak(_ days: Int, language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: "连续使用 \(days) 天"
        case .traditionalChinese: "連續使用 \(days) 天"
        case .english: days == 1 ? "1 day streak" : "\(days) day streak"
        case .japanese: "\(days) 日連続"
        case .korean: "\(days)일 연속"
        case .spanish: days == 1 ? "Racha de 1 día" : "Racha de \(days) días"
        }
    }

    static func weekdaySymbols(language: AppLanguage) -> [String] {
        switch language {
        case .simplifiedChinese, .traditionalChinese:
            ["一", "二", "三", "四", "五", "六", "日"]
        case .english, .spanish:
            ["M", "T", "W", "T", "F", "S", "S"]
        case .japanese:
            ["月", "火", "水", "木", "金", "土", "日"]
        case .korean:
            ["월", "화", "수", "목", "금", "토", "일"]
        }
    }

    static func updatedAt(_ date: Date, language: AppLanguage) -> String {
        let time = date.formatted(
            .dateTime.hour().minute().locale(language.locale)
        )
        return switch language {
        case .simplifiedChinese: "更新于 \(time)"
        case .traditionalChinese: "更新於 \(time)"
        case .english: "Updated \(time)"
        case .japanese: "\(time) に更新"
        case .korean: "\(time) 업데이트"
        case .spanish: "Actualizado a las \(time)"
        }
    }

    static func errorMessage(for error: CodexMeterError, language: AppLanguage) -> String {
        switch (language, error) {
        case (.simplifiedChinese, .codexNotFound):
            "没有找到 Codex CLI。请先安装 Codex CLI 并登录。"
        case let (.simplifiedChinese, .launchFailed(message)):
            "无法启动 Codex App Server：\(message)"
        case (.simplifiedChinese, .timeout):
            "读取额度超时，请稍后重试。"
        case (.simplifiedChinese, .responseTooLarge):
            "Codex App Server 返回的数据超过安全大小限制。"
        case let (.simplifiedChinese, .connectionClosed(message)):
            message.isEmpty ? "Codex App Server 提前关闭了连接。" : "Codex App Server：\(message)"
        case let (.simplifiedChinese, .server(message)):
            "Codex 返回错误：\(message)"
        case let (.simplifiedChinese, .invalidResponse(message)):
            "无法解析额度数据：\(message)"

        case (.traditionalChinese, .codexNotFound):
            "找不到 Codex CLI。請先安裝 Codex CLI 並登入。"
        case let (.traditionalChinese, .launchFailed(message)):
            "無法啟動 Codex App Server：\(message)"
        case (.traditionalChinese, .timeout):
            "讀取額度逾時，請稍後再試。"
        case (.traditionalChinese, .responseTooLarge):
            "Codex App Server 傳回的資料超過安全大小限制。"
        case let (.traditionalChinese, .connectionClosed(message)):
            message.isEmpty ? "Codex App Server 提前關閉了連線。" : "Codex App Server：\(message)"
        case let (.traditionalChinese, .server(message)):
            "Codex 傳回錯誤：\(message)"
        case let (.traditionalChinese, .invalidResponse(message)):
            "無法解析額度資料：\(message)"

        case (.english, .codexNotFound):
            "Codex CLI was not found. Install Codex CLI and sign in first."
        case let (.english, .launchFailed(message)):
            "Could not start Codex App Server: \(message)"
        case (.english, .timeout):
            "The quota request timed out. Try again shortly."
        case (.english, .responseTooLarge):
            "Codex App Server returned more data than the safety limit allows."
        case let (.english, .connectionClosed(message)):
            message.isEmpty ? "Codex App Server closed the connection early." : "Codex App Server: \(message)"
        case let (.english, .server(message)):
            "Codex returned an error: \(message)"
        case let (.english, .invalidResponse(message)):
            "Could not parse quota data: \(message)"

        case (.japanese, .codexNotFound):
            "Codex CLI が見つかりません。Codex CLI をインストールし、サインインしてください。"
        case let (.japanese, .launchFailed(message)):
            "Codex App Server を起動できません: \(message)"
        case (.japanese, .timeout):
            "割り当ての取得がタイムアウトしました。しばらくしてから再試行してください。"
        case (.japanese, .responseTooLarge):
            "Codex App Server の応答が安全なサイズ上限を超えました。"
        case let (.japanese, .connectionClosed(message)):
            message.isEmpty ? "Codex App Server が接続を早期終了しました。" : "Codex App Server: \(message)"
        case let (.japanese, .server(message)):
            "Codex エラー: \(message)"
        case let (.japanese, .invalidResponse(message)):
            "割り当てデータを解析できません: \(message)"

        case (.korean, .codexNotFound):
            "Codex CLI를 찾을 수 없습니다. Codex CLI를 설치하고 로그인하세요."
        case let (.korean, .launchFailed(message)):
            "Codex App Server를 시작할 수 없습니다: \(message)"
        case (.korean, .timeout):
            "할당량 요청 시간이 초과되었습니다. 잠시 후 다시 시도하세요."
        case (.korean, .responseTooLarge):
            "Codex App Server 응답이 안전한 크기 제한을 초과했습니다."
        case let (.korean, .connectionClosed(message)):
            message.isEmpty ? "Codex App Server가 예상보다 일찍 연결을 종료했습니다." : "Codex App Server: \(message)"
        case let (.korean, .server(message)):
            "Codex 오류: \(message)"
        case let (.korean, .invalidResponse(message)):
            "할당량 데이터를 해석할 수 없습니다: \(message)"

        case (.spanish, .codexNotFound):
            "No se encontró Codex CLI. Instala Codex CLI e inicia sesión."
        case let (.spanish, .launchFailed(message)):
            "No se pudo iniciar Codex App Server: \(message)"
        case (.spanish, .timeout):
            "La solicitud de cuota agotó el tiempo de espera. Inténtalo de nuevo en unos momentos."
        case (.spanish, .responseTooLarge):
            "La respuesta de Codex App Server superó el límite de tamaño seguro."
        case let (.spanish, .connectionClosed(message)):
            message.isEmpty ? "Codex App Server cerró la conexión antes de tiempo." : "Codex App Server: \(message)"
        case let (.spanish, .server(message)):
            "Error de Codex: \(message)"
        case let (.spanish, .invalidResponse(message)):
            "No se pudieron interpretar los datos de cuota: \(message)"
        }
    }

    private static func simplifiedChinese(_ key: Key) -> String {
        switch key {
        case .menuBarHelp: "Codex 每周剩余额度"
        case .showEmail: "显示完整邮箱"
        case .hideEmail: "隐藏邮箱"
        case .refreshQuota: "刷新额度"
        case .settings: "设置"
        case .quit: "退出 Codex Meter"
        case .followCodexAppApprovalHint: "请在系统设置的登录项中允许 Codex Meter 后台运行"
        case .appearance: "外观"
        case .appearanceSystem: "跟随系统"
        case .appearanceLight: "浅色"
        case .appearanceDark: "深色"
        case .language: "语言"
        case .searchLanguage: "搜索语言"
        case .noLanguagesFound: "没有匹配的语言"
        case .custom: "自定义"
        case .retry: "重试"
        case .remainingQuota: "剩余额度"
        case .noQuotaWindow: "当前账户未返回额度窗口"
        case .noQuotaExplanation: "API Key 或 Bedrock 登录通常不会返回 ChatGPT 额度。"
        case .todayDetails: "今日明细"
        case .calculatingUsage: "统计中…"
        case .monthlyUsage: "用量统计"
        case .monthlyUsageRange: "显示范围"
        case .thisMonth: "本月"
        case .activityOverview: "活跃度概览"
        case .lastSevenDays: "近 7 天"
        case .hoverHeatmap: "鼠标移到方格上查看当天用量"
        case .less: "少"
        case .more: "多"
        case .creditsBalance: "Credits 余额"
        case .creditsBalanceUnavailable: "暂无数据"
        case .unlimitedCredits: "无限"
        case .lifetimeTokens: "累计 Token"
        case .longestStreak: "最长连续"
        case .longestTask: "最长任务"
        case .notAvailable: "暂无"
        }
    }

    private static func traditionalChinese(_ key: Key) -> String {
        switch key {
        case .menuBarHelp: "Codex 每週剩餘額度"
        case .showEmail: "顯示完整電子郵件"
        case .hideEmail: "隱藏電子郵件"
        case .refreshQuota: "重新整理額度"
        case .settings: "設定"
        case .quit: "結束 Codex Meter"
        case .followCodexAppApprovalHint: "請在系統設定的登入項目中允許 Codex Meter 在背景執行"
        case .appearance: "外觀"
        case .appearanceSystem: "跟隨系統"
        case .appearanceLight: "淺色"
        case .appearanceDark: "深色"
        case .language: "語言"
        case .searchLanguage: "搜尋語言"
        case .noLanguagesFound: "沒有符合的語言"
        case .custom: "自訂"
        case .retry: "再試一次"
        case .remainingQuota: "剩餘額度"
        case .noQuotaWindow: "目前帳戶未傳回額度視窗"
        case .noQuotaExplanation: "API Key 或 Bedrock 登入通常不會傳回 ChatGPT 額度。"
        case .todayDetails: "今日明細"
        case .calculatingUsage: "統計中…"
        case .monthlyUsage: "用量統計"
        case .monthlyUsageRange: "顯示範圍"
        case .thisMonth: "本月"
        case .activityOverview: "活躍度概覽"
        case .lastSevenDays: "近 7 天"
        case .hoverHeatmap: "將滑鼠移到方格上查看當天用量"
        case .less: "少"
        case .more: "多"
        case .creditsBalance: "Credits 餘額"
        case .creditsBalanceUnavailable: "暫無資料"
        case .unlimitedCredits: "無限"
        case .lifetimeTokens: "累計 Token"
        case .longestStreak: "最長連續"
        case .longestTask: "最長任務"
        case .notAvailable: "暫無"
        }
    }

    private static func english(_ key: Key) -> String {
        switch key {
        case .menuBarHelp: "Codex weekly quota remaining"
        case .showEmail: "Show full email"
        case .hideEmail: "Hide email"
        case .refreshQuota: "Refresh quota"
        case .settings: "Settings"
        case .quit: "Quit Codex Meter"
        case .followCodexAppApprovalHint: "Allow Codex Meter to run in the background in System Settings → Login Items"
        case .appearance: "Appearance"
        case .appearanceSystem: "System"
        case .appearanceLight: "Light"
        case .appearanceDark: "Dark"
        case .language: "Language"
        case .searchLanguage: "Search languages"
        case .noLanguagesFound: "No matching languages"
        case .custom: "Custom"
        case .retry: "Retry"
        case .remainingQuota: "Remaining quota"
        case .noQuotaWindow: "No quota window was returned for this account"
        case .noQuotaExplanation: "API Key and Bedrock sign-ins usually do not return ChatGPT quota data."
        case .todayDetails: "Today details"
        case .calculatingUsage: "Calculating…"
        case .monthlyUsage: "Usage statistics"
        case .monthlyUsageRange: "Display range"
        case .thisMonth: "This month"
        case .activityOverview: "Activity overview"
        case .lastSevenDays: "Last 7 days"
        case .hoverHeatmap: "Hover over a square to view that day's usage"
        case .less: "Less"
        case .more: "More"
        case .creditsBalance: "Credits balance"
        case .creditsBalanceUnavailable: "Not available"
        case .unlimitedCredits: "Unlimited"
        case .lifetimeTokens: "Lifetime tokens"
        case .longestStreak: "Longest streak"
        case .longestTask: "Longest task"
        case .notAvailable: "N/A"
        }
    }

    private static func japanese(_ key: Key) -> String {
        switch key {
        case .menuBarHelp: "Codex の週間割り当て残量"
        case .showEmail: "メールアドレスを表示"
        case .hideEmail: "メールアドレスを隠す"
        case .refreshQuota: "割り当てを更新"
        case .settings: "設定"
        case .quit: "Codex Meter を終了"
        case .followCodexAppApprovalHint: "システム設定のログイン項目で Codex Meter のバックグラウンド実行を許可してください"
        case .appearance: "外観"
        case .appearanceSystem: "システム"
        case .appearanceLight: "ライト"
        case .appearanceDark: "ダーク"
        case .language: "言語"
        case .searchLanguage: "言語を検索"
        case .noLanguagesFound: "一致する言語がありません"
        case .custom: "カスタム"
        case .retry: "再試行"
        case .remainingQuota: "残り割り当て"
        case .noQuotaWindow: "このアカウントの割り当て期間が返されませんでした"
        case .noQuotaExplanation: "API Key または Bedrock のサインインでは、通常 ChatGPT の割り当ては返されません。"
        case .todayDetails: "今日の内訳"
        case .calculatingUsage: "集計中…"
        case .monthlyUsage: "使用量の統計"
        case .monthlyUsageRange: "表示期間"
        case .thisMonth: "今月"
        case .activityOverview: "アクティビティ概要"
        case .lastSevenDays: "過去 7 日間"
        case .hoverHeatmap: "マスにポインタを置くとその日の使用量を表示します"
        case .less: "少"
        case .more: "多"
        case .creditsBalance: "クレジット残高"
        case .creditsBalanceUnavailable: "データなし"
        case .unlimitedCredits: "無制限"
        case .lifetimeTokens: "累計 Token"
        case .longestStreak: "最長連続"
        case .longestTask: "最長タスク"
        case .notAvailable: "データなし"
        }
    }

    private static func korean(_ key: Key) -> String {
        switch key {
        case .menuBarHelp: "Codex 주간 할당량 잔여"
        case .showEmail: "전체 이메일 표시"
        case .hideEmail: "이메일 숨기기"
        case .refreshQuota: "할당량 새로 고침"
        case .settings: "설정"
        case .quit: "Codex Meter 종료"
        case .followCodexAppApprovalHint: "시스템 설정의 로그인 항목에서 Codex Meter의 백그라운드 실행을 허용하세요"
        case .appearance: "모양"
        case .appearanceSystem: "시스템"
        case .appearanceLight: "라이트"
        case .appearanceDark: "다크"
        case .language: "언어"
        case .searchLanguage: "언어 검색"
        case .noLanguagesFound: "일치하는 언어가 없습니다"
        case .custom: "사용자 지정"
        case .retry: "다시 시도"
        case .remainingQuota: "남은 할당량"
        case .noQuotaWindow: "이 계정에 대한 할당량 기간이 반환되지 않았습니다"
        case .noQuotaExplanation: "API Key 또는 Bedrock 로그인은 일반적으로 ChatGPT 할당량을 반환하지 않습니다."
        case .todayDetails: "오늘 상세"
        case .calculatingUsage: "집계 중…"
        case .monthlyUsage: "사용량 통계"
        case .monthlyUsageRange: "표시 기간"
        case .thisMonth: "이번 달"
        case .activityOverview: "활동 개요"
        case .lastSevenDays: "최근 7일"
        case .hoverHeatmap: "칸 위에 마우스를 올려 해당 날짜의 사용량을 확인하세요"
        case .less: "적음"
        case .more: "많음"
        case .creditsBalance: "크레딧 잔액"
        case .creditsBalanceUnavailable: "데이터 없음"
        case .unlimitedCredits: "무제한"
        case .lifetimeTokens: "누적 Token"
        case .longestStreak: "최장 연속"
        case .longestTask: "가장 긴 작업"
        case .notAvailable: "데이터 없음"
        }
    }

    private static func spanish(_ key: Key) -> String {
        switch key {
        case .menuBarHelp: "Cuota semanal restante de Codex"
        case .showEmail: "Mostrar correo completo"
        case .hideEmail: "Ocultar correo"
        case .refreshQuota: "Actualizar cuota"
        case .settings: "Configuración"
        case .quit: "Salir de Codex Meter"
        case .followCodexAppApprovalHint: "Permite que Codex Meter se ejecute en segundo plano en Ajustes del Sistema → Ítems de inicio"
        case .appearance: "Apariencia"
        case .appearanceSystem: "Sistema"
        case .appearanceLight: "Clara"
        case .appearanceDark: "Oscura"
        case .language: "Idioma"
        case .searchLanguage: "Buscar idiomas"
        case .noLanguagesFound: "No hay idiomas coincidentes"
        case .custom: "Personalizado"
        case .retry: "Reintentar"
        case .remainingQuota: "Cuota restante"
        case .noQuotaWindow: "No se devolvió ningún periodo de cuota para esta cuenta"
        case .noQuotaExplanation: "Los inicios de sesión con API Key o Bedrock normalmente no devuelven datos de cuota de ChatGPT."
        case .todayDetails: "Detalle de hoy"
        case .calculatingUsage: "Calculando…"
        case .monthlyUsage: "Estadísticas de uso"
        case .monthlyUsageRange: "Periodo"
        case .thisMonth: "Este mes"
        case .activityOverview: "Resumen de actividad"
        case .lastSevenDays: "Últimos 7 días"
        case .hoverHeatmap: "Pasa el cursor sobre un cuadro para ver el uso de ese día"
        case .less: "Menos"
        case .more: "Más"
        case .creditsBalance: "Saldo de créditos"
        case .creditsBalanceUnavailable: "No disponible"
        case .unlimitedCredits: "Ilimitados"
        case .lifetimeTokens: "Tokens acumulados"
        case .longestStreak: "Racha más larga"
        case .longestTask: "Tarea más larga"
        case .notAvailable: "No disponible"
        }
    }
}
