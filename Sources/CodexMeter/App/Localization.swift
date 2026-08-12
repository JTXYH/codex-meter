import Foundation

enum L10n {
    enum Key {
        case menuBarHelp
        case currentMacServer
        case showEmail
        case hideEmail
        case refreshQuota
        case settings
        case quit
        case settingsHint
        case general
        case generalHint
        case launchAtLogin
        case launchAtLoginHint
        case refresh
        case refreshHint
        case appearance
        case appearanceHint
        case appearanceSystem
        case appearanceLight
        case appearanceDark
        case language
        case languageHint
        case searchLanguage
        case noLanguagesFound
        case automaticRefresh
        case automaticRefreshHint
        case customMinutes
        case minuteRangeHint
        case custom
        case loadingQuota
        case loadingDetail
        case loadFailed
        case retry
        case remainingQuota
        case currentPeriod
        case noQuotaWindow
        case noQuotaExplanation
        case tokenActivity
        case peakBaseline
        case today
        case todayDetails
        case statisticsCurrent
        case activityOverview
        case inputTokens
        case outputTokens
        case apiEquivalentCost
        case cachedInput
        case yesterday
        case lastSevenDays
        case lastNinetyDays
        case hoverHeatmap
        case total
        case less
        case more
        case streakUnavailable
        case usageOverview
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

    static func totalTokens(_ value: String, language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese, .traditionalChinese: "合计 \(value) Token"
        case .english: "Total \(value) tokens"
        case .japanese: "合計 \(value) Token"
        case .korean: "합계 \(value) Token"
        case .spanish: "Total: \(value) tokens"
        }
    }

    static func cachedInputSummary(
        _ value: String,
        hitPercent: Int,
        language: AppLanguage
    ) -> String {
        switch language {
        case .simplifiedChinese: "缓存输入 \(value) · 命中 \(hitPercent)%"
        case .traditionalChinese: "快取輸入 \(value) · 命中 \(hitPercent)%"
        case .english: "Cached input \(value) · \(hitPercent)% hit"
        case .japanese: "キャッシュ入力 \(value) · ヒット率 \(hitPercent)%"
        case .korean: "캐시 입력 \(value) · 적중률 \(hitPercent)%"
        case .spanish: "Entrada en caché \(value) · \(hitPercent)% de aciertos"
        }
    }

    static func hitRate(_ percent: Int, language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: "命中率 \(percent)%"
        case .traditionalChinese: "命中率 \(percent)%"
        case .english: "\(percent)% hit rate"
        case .japanese: "ヒット率 \(percent)%"
        case .korean: "적중률 \(percent)%"
        case .spanish: "\(percent)% de aciertos"
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

    static func longestStreakValue(_ days: Int?, language: AppLanguage) -> String {
        guard let days else { return text(.notAvailable, language: language) }
        return switch language {
        case .simplifiedChinese, .traditionalChinese: "\(days) 天"
        case .english: days == 1 ? "1 day" : "\(days) days"
        case .japanese: "\(days) 日"
        case .korean: "\(days)일"
        case .spanish: days == 1 ? "1 día" : "\(days) días"
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
        case .currentMacServer: "当前 Mac / Codex App Server"
        case .showEmail: "显示完整邮箱"
        case .hideEmail: "隐藏邮箱"
        case .refreshQuota: "刷新额度"
        case .settings: "设置"
        case .quit: "退出 Codex Meter"
        case .settingsHint: "更改会立即生效并自动保存"
        case .general: "通用"
        case .generalHint: "调整应用行为、外观和显示语言"
        case .launchAtLogin: "登录时启动"
        case .launchAtLoginHint: "登录这台 Mac 后自动启动 Codex Meter"
        case .refresh: "刷新"
        case .refreshHint: "设置 Codex 数据的自动刷新频率"
        case .appearance: "外观"
        case .appearanceHint: "选择跟随系统、浅色或深色模式"
        case .appearanceSystem: "跟随系统"
        case .appearanceLight: "浅色"
        case .appearanceDark: "深色"
        case .language: "语言"
        case .languageHint: "选择 Codex Meter 的界面语言"
        case .searchLanguage: "搜索语言"
        case .noLanguagesFound: "没有匹配的语言"
        case .automaticRefresh: "Codex 自动刷新"
        case .automaticRefreshHint: "按选定的分钟数定期获取最新额度"
        case .customMinutes: "自定义分钟数"
        case .minuteRangeHint: "可设置 1 到 1440 分钟"
        case .custom: "自定义"
        case .loadingQuota: "正在读取当前 Codex 额度..."
        case .loadingDetail: "通过本机 Codex App Server 复用已有登录态"
        case .loadFailed: "暂时无法读取额度"
        case .retry: "重试"
        case .remainingQuota: "剩余额度"
        case .currentPeriod: "当前周期"
        case .noQuotaWindow: "当前账户未返回额度窗口"
        case .noQuotaExplanation: "API Key 或 Bedrock 登录通常不会返回 ChatGPT 额度。"
        case .tokenActivity: "Token 活跃度"
        case .peakBaseline: "峰值基准"
        case .today: "今日"
        case .todayDetails: "今日明细"
        case .statisticsCurrent: "统计截至当前时刻"
        case .activityOverview: "活跃度概览"
        case .inputTokens: "输入"
        case .outputTokens: "输出"
        case .apiEquivalentCost: "API 等效费用"
        case .cachedInput: "缓存输入"
        case .yesterday: "昨日"
        case .lastSevenDays: "近 7 天"
        case .lastNinetyDays: "近 90 天用量"
        case .hoverHeatmap: "鼠标移到方格上查看当天用量"
        case .total: "合计"
        case .less: "少"
        case .more: "多"
        case .streakUnavailable: "连续使用暂无数据"
        case .usageOverview: "使用概览"
        case .lifetimeTokens: "累计 Token"
        case .longestStreak: "最长连续"
        case .longestTask: "最长任务"
        case .notAvailable: "暂无"
        }
    }

    private static func traditionalChinese(_ key: Key) -> String {
        switch key {
        case .menuBarHelp: "Codex 每週剩餘額度"
        case .currentMacServer: "目前 Mac / Codex App Server"
        case .showEmail: "顯示完整電子郵件"
        case .hideEmail: "隱藏電子郵件"
        case .refreshQuota: "重新整理額度"
        case .settings: "設定"
        case .quit: "結束 Codex Meter"
        case .settingsHint: "變更會立即生效並自動儲存"
        case .general: "一般"
        case .generalHint: "調整應用程式行為、外觀和顯示語言"
        case .launchAtLogin: "登入時啟動"
        case .launchAtLoginHint: "登入這台 Mac 後自動啟動 Codex Meter"
        case .refresh: "重新整理"
        case .refreshHint: "設定 Codex 資料的自動重新整理頻率"
        case .appearance: "外觀"
        case .appearanceHint: "選擇跟隨系統、淺色或深色模式"
        case .appearanceSystem: "跟隨系統"
        case .appearanceLight: "淺色"
        case .appearanceDark: "深色"
        case .language: "語言"
        case .languageHint: "選擇 Codex Meter 的介面語言"
        case .searchLanguage: "搜尋語言"
        case .noLanguagesFound: "沒有符合的語言"
        case .automaticRefresh: "Codex 自動重新整理"
        case .automaticRefreshHint: "依選定的分鐘數定期取得最新額度"
        case .customMinutes: "自訂分鐘數"
        case .minuteRangeHint: "可設定 1 到 1440 分鐘"
        case .custom: "自訂"
        case .loadingQuota: "正在讀取目前 Codex 額度..."
        case .loadingDetail: "透過本機 Codex App Server 使用現有登入狀態"
        case .loadFailed: "暫時無法讀取額度"
        case .retry: "再試一次"
        case .remainingQuota: "剩餘額度"
        case .currentPeriod: "目前週期"
        case .noQuotaWindow: "目前帳戶未傳回額度視窗"
        case .noQuotaExplanation: "API Key 或 Bedrock 登入通常不會傳回 ChatGPT 額度。"
        case .tokenActivity: "Token 活躍度"
        case .peakBaseline: "峰值基準"
        case .today: "今日"
        case .todayDetails: "今日明細"
        case .statisticsCurrent: "統計截至目前時刻"
        case .activityOverview: "活躍度概覽"
        case .inputTokens: "輸入"
        case .outputTokens: "輸出"
        case .apiEquivalentCost: "API 等效費用"
        case .cachedInput: "快取輸入"
        case .yesterday: "昨日"
        case .lastSevenDays: "近 7 天"
        case .lastNinetyDays: "近 90 天用量"
        case .hoverHeatmap: "將滑鼠移到方格上查看當天用量"
        case .total: "合計"
        case .less: "少"
        case .more: "多"
        case .streakUnavailable: "連續使用暫無資料"
        case .usageOverview: "使用概覽"
        case .lifetimeTokens: "累計 Token"
        case .longestStreak: "最長連續"
        case .longestTask: "最長任務"
        case .notAvailable: "暫無"
        }
    }

    private static func english(_ key: Key) -> String {
        switch key {
        case .menuBarHelp: "Codex weekly quota remaining"
        case .currentMacServer: "This Mac / Codex App Server"
        case .showEmail: "Show full email"
        case .hideEmail: "Hide email"
        case .refreshQuota: "Refresh quota"
        case .settings: "Settings"
        case .quit: "Quit Codex Meter"
        case .settingsHint: "Changes apply immediately and save automatically"
        case .general: "General"
        case .generalHint: "Adjust app behavior, appearance, and display language"
        case .launchAtLogin: "Launch at login"
        case .launchAtLoginHint: "Open Codex Meter automatically when you log in to this Mac"
        case .refresh: "Refresh"
        case .refreshHint: "Choose how often Codex data refreshes automatically"
        case .appearance: "Appearance"
        case .appearanceHint: "Use the system, light, or dark appearance"
        case .appearanceSystem: "System"
        case .appearanceLight: "Light"
        case .appearanceDark: "Dark"
        case .language: "Language"
        case .languageHint: "Choose the language used throughout Codex Meter"
        case .searchLanguage: "Search languages"
        case .noLanguagesFound: "No matching languages"
        case .automaticRefresh: "Codex auto-refresh"
        case .automaticRefreshHint: "Fetch the latest quota on the selected schedule"
        case .customMinutes: "Custom minutes"
        case .minuteRangeHint: "Enter a value from 1 to 1440 minutes"
        case .custom: "Custom"
        case .loadingQuota: "Reading your Codex quota..."
        case .loadingDetail: "Using your existing sign-in through the local Codex App Server"
        case .loadFailed: "Could not read quota"
        case .retry: "Retry"
        case .remainingQuota: "Remaining quota"
        case .currentPeriod: "Current period"
        case .noQuotaWindow: "No quota window was returned for this account"
        case .noQuotaExplanation: "API Key and Bedrock sign-ins usually do not return ChatGPT quota data."
        case .tokenActivity: "Token activity"
        case .peakBaseline: "Peak baseline"
        case .today: "Today"
        case .todayDetails: "Today details"
        case .statisticsCurrent: "Stats through now"
        case .activityOverview: "Activity overview"
        case .inputTokens: "Input"
        case .outputTokens: "Output"
        case .apiEquivalentCost: "API-equivalent cost"
        case .cachedInput: "Cached input"
        case .yesterday: "Yesterday"
        case .lastSevenDays: "Last 7 days"
        case .lastNinetyDays: "Last 90 days"
        case .hoverHeatmap: "Hover over a square to view that day's usage"
        case .total: "Total"
        case .less: "Less"
        case .more: "More"
        case .streakUnavailable: "Streak data unavailable"
        case .usageOverview: "Usage overview"
        case .lifetimeTokens: "Lifetime tokens"
        case .longestStreak: "Longest streak"
        case .longestTask: "Longest task"
        case .notAvailable: "N/A"
        }
    }

    private static func japanese(_ key: Key) -> String {
        switch key {
        case .menuBarHelp: "Codex の週間割り当て残量"
        case .currentMacServer: "この Mac / Codex App Server"
        case .showEmail: "メールアドレスを表示"
        case .hideEmail: "メールアドレスを隠す"
        case .refreshQuota: "割り当てを更新"
        case .settings: "設定"
        case .quit: "Codex Meter を終了"
        case .settingsHint: "変更はすぐに反映され、自動保存されます"
        case .general: "一般"
        case .generalHint: "アプリの動作、外観、表示言語を調整します"
        case .launchAtLogin: "ログイン時に起動"
        case .launchAtLoginHint: "この Mac へのログイン時に Codex Meter を自動起動します"
        case .refresh: "更新"
        case .refreshHint: "Codex データの自動更新間隔を設定します"
        case .appearance: "外観"
        case .appearanceHint: "システム、ライト、ダークから選択します"
        case .appearanceSystem: "システム"
        case .appearanceLight: "ライト"
        case .appearanceDark: "ダーク"
        case .language: "言語"
        case .languageHint: "Codex Meter 全体で使う言語を選択します"
        case .searchLanguage: "言語を検索"
        case .noLanguagesFound: "一致する言語がありません"
        case .automaticRefresh: "Codex の自動更新"
        case .automaticRefreshHint: "選択した間隔で最新の割り当てを取得します"
        case .customMinutes: "カスタム分数"
        case .minuteRangeHint: "1 から 1440 分の範囲で入力してください"
        case .custom: "カスタム"
        case .loadingQuota: "Codex の割り当てを読み込み中..."
        case .loadingDetail: "ローカルの Codex App Server で既存のサインインを使用しています"
        case .loadFailed: "割り当てを読み込めません"
        case .retry: "再試行"
        case .remainingQuota: "残り割り当て"
        case .currentPeriod: "現在の期間"
        case .noQuotaWindow: "このアカウントの割り当て期間が返されませんでした"
        case .noQuotaExplanation: "API Key または Bedrock のサインインでは、通常 ChatGPT の割り当ては返されません。"
        case .tokenActivity: "Token アクティビティ"
        case .peakBaseline: "ピーク基準"
        case .today: "今日"
        case .todayDetails: "今日の内訳"
        case .statisticsCurrent: "現在時点まで"
        case .activityOverview: "アクティビティ概要"
        case .inputTokens: "入力"
        case .outputTokens: "出力"
        case .apiEquivalentCost: "API 換算料金"
        case .cachedInput: "キャッシュ入力"
        case .yesterday: "昨日"
        case .lastSevenDays: "過去 7 日間"
        case .lastNinetyDays: "過去 90 日間"
        case .hoverHeatmap: "マスにポインタを置くとその日の使用量を表示します"
        case .total: "合計"
        case .less: "少"
        case .more: "多"
        case .streakUnavailable: "連続使用データなし"
        case .usageOverview: "使用状況"
        case .lifetimeTokens: "累計 Token"
        case .longestStreak: "最長連続"
        case .longestTask: "最長タスク"
        case .notAvailable: "データなし"
        }
    }

    private static func korean(_ key: Key) -> String {
        switch key {
        case .menuBarHelp: "Codex 주간 할당량 잔여"
        case .currentMacServer: "이 Mac / Codex App Server"
        case .showEmail: "전체 이메일 표시"
        case .hideEmail: "이메일 숨기기"
        case .refreshQuota: "할당량 새로 고침"
        case .settings: "설정"
        case .quit: "Codex Meter 종료"
        case .settingsHint: "변경 사항은 즉시 적용되고 자동으로 저장됩니다"
        case .general: "일반"
        case .generalHint: "앱 동작, 모양 및 표시 언어를 조정합니다"
        case .launchAtLogin: "로그인 시 실행"
        case .launchAtLoginHint: "이 Mac에 로그인하면 Codex Meter를 자동으로 실행합니다"
        case .refresh: "새로 고침"
        case .refreshHint: "Codex 데이터 자동 새로 고침 간격을 설정합니다"
        case .appearance: "모양"
        case .appearanceHint: "시스템, 라이트 또는 다크 모드를 선택합니다"
        case .appearanceSystem: "시스템"
        case .appearanceLight: "라이트"
        case .appearanceDark: "다크"
        case .language: "언어"
        case .languageHint: "Codex Meter 전체에서 사용할 언어를 선택합니다"
        case .searchLanguage: "언어 검색"
        case .noLanguagesFound: "일치하는 언어가 없습니다"
        case .automaticRefresh: "Codex 자동 새로 고침"
        case .automaticRefreshHint: "선택한 간격으로 최신 할당량을 가져옵니다"
        case .customMinutes: "사용자 지정 분"
        case .minuteRangeHint: "1분에서 1440분 사이의 값을 입력하세요"
        case .custom: "사용자 지정"
        case .loadingQuota: "현재 Codex 할당량을 읽는 중..."
        case .loadingDetail: "로컬 Codex App Server를 통해 기존 로그인을 사용합니다"
        case .loadFailed: "할당량을 읽을 수 없습니다"
        case .retry: "다시 시도"
        case .remainingQuota: "남은 할당량"
        case .currentPeriod: "현재 기간"
        case .noQuotaWindow: "이 계정에 대한 할당량 기간이 반환되지 않았습니다"
        case .noQuotaExplanation: "API Key 또는 Bedrock 로그인은 일반적으로 ChatGPT 할당량을 반환하지 않습니다."
        case .tokenActivity: "Token 활동"
        case .peakBaseline: "최고치 기준"
        case .today: "오늘"
        case .todayDetails: "오늘 상세"
        case .statisticsCurrent: "현재 시각 기준"
        case .activityOverview: "활동 개요"
        case .inputTokens: "입력"
        case .outputTokens: "출력"
        case .apiEquivalentCost: "API 환산 비용"
        case .cachedInput: "캐시 입력"
        case .yesterday: "어제"
        case .lastSevenDays: "최근 7일"
        case .lastNinetyDays: "최근 90일"
        case .hoverHeatmap: "칸 위에 마우스를 올려 해당 날짜의 사용량을 확인하세요"
        case .total: "합계"
        case .less: "적음"
        case .more: "많음"
        case .streakUnavailable: "연속 사용 데이터 없음"
        case .usageOverview: "사용 개요"
        case .lifetimeTokens: "누적 Token"
        case .longestStreak: "최장 연속"
        case .longestTask: "가장 긴 작업"
        case .notAvailable: "데이터 없음"
        }
    }

    private static func spanish(_ key: Key) -> String {
        switch key {
        case .menuBarHelp: "Cuota semanal restante de Codex"
        case .currentMacServer: "Este Mac / Codex App Server"
        case .showEmail: "Mostrar correo completo"
        case .hideEmail: "Ocultar correo"
        case .refreshQuota: "Actualizar cuota"
        case .settings: "Configuración"
        case .quit: "Salir de Codex Meter"
        case .settingsHint: "Los cambios se aplican al instante y se guardan automáticamente"
        case .general: "General"
        case .generalHint: "Ajusta el comportamiento, la apariencia y el idioma de la aplicación"
        case .launchAtLogin: "Abrir al iniciar sesión"
        case .launchAtLoginHint: "Abre Codex Meter automáticamente al iniciar sesión en este Mac"
        case .refresh: "Actualización"
        case .refreshHint: "Elige con qué frecuencia se actualizan los datos de Codex"
        case .appearance: "Apariencia"
        case .appearanceHint: "Usa la apariencia del sistema, clara u oscura"
        case .appearanceSystem: "Sistema"
        case .appearanceLight: "Clara"
        case .appearanceDark: "Oscura"
        case .language: "Idioma"
        case .languageHint: "Elige el idioma utilizado en Codex Meter"
        case .searchLanguage: "Buscar idiomas"
        case .noLanguagesFound: "No hay idiomas coincidentes"
        case .automaticRefresh: "Actualización automática de Codex"
        case .automaticRefreshHint: "Obtén la cuota más reciente con el intervalo seleccionado"
        case .customMinutes: "Minutos personalizados"
        case .minuteRangeHint: "Introduce un valor entre 1 y 1440 minutos"
        case .custom: "Personalizado"
        case .loadingQuota: "Leyendo tu cuota de Codex..."
        case .loadingDetail: "Usando tu sesión existente mediante Codex App Server local"
        case .loadFailed: "No se pudo leer la cuota"
        case .retry: "Reintentar"
        case .remainingQuota: "Cuota restante"
        case .currentPeriod: "Periodo actual"
        case .noQuotaWindow: "No se devolvió ningún periodo de cuota para esta cuenta"
        case .noQuotaExplanation: "Los inicios de sesión con API Key o Bedrock normalmente no devuelven datos de cuota de ChatGPT."
        case .tokenActivity: "Actividad de tokens"
        case .peakBaseline: "Referencia máxima"
        case .today: "Hoy"
        case .todayDetails: "Detalle de hoy"
        case .statisticsCurrent: "Datos hasta ahora"
        case .activityOverview: "Resumen de actividad"
        case .inputTokens: "Entrada"
        case .outputTokens: "Salida"
        case .apiEquivalentCost: "Coste API equivalente"
        case .cachedInput: "Entrada en caché"
        case .yesterday: "Ayer"
        case .lastSevenDays: "Últimos 7 días"
        case .lastNinetyDays: "Últimos 90 días"
        case .hoverHeatmap: "Pasa el cursor sobre un cuadro para ver el uso de ese día"
        case .total: "Total"
        case .less: "Menos"
        case .more: "Más"
        case .streakUnavailable: "Datos de racha no disponibles"
        case .usageOverview: "Resumen de uso"
        case .lifetimeTokens: "Tokens acumulados"
        case .longestStreak: "Racha más larga"
        case .longestTask: "Tarea más larga"
        case .notAvailable: "No disponible"
        }
    }
}
