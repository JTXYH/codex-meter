import Foundation

/// Copy introduced by the approved dashboard design; existing language choices stay intact.
enum RedesignL10n {
    enum Key: Int {
        case currentQuota, ready, low, exhausted, localLive, todayTokens, modelDetails
        case yesterdayTokens, accountSummary, extraCredits, waitingAccount, justUpdated, refreshing, stale
        case selectModules, selectModulesHint, configureLayout, modelsUsed, noModels, modelsFailed
        case resetTime, today, weeklyRemaining, month, heatmapTitle, input, output, cached, days, hours, minutes
        case modelsLoading, modelsUnavailable, updateFailed
        case readingAccount, readingAccountHint, accountFailed, accountFailedHint, signIn, signInHint, codexMissing, codexMissingHint, readAgain, detectAgain
        case readInProgress, readFailed, waitingLogin, waitingCodex
    }

    static func text(_ key: Key, language: AppLanguage) -> String {
        let values: [String]
        switch language {
        case .simplifiedChinese:
            values = ["当前额度", "可以继续使用", "额度即将用尽", "等待额度恢复", "本机 · 实时", "今日 Token", "模型明细", "昨日 Token", "账号摘要", "额外用量余额", "等待账号信息", "刚刚更新", "正在刷新…", "更新失败 · 保留上次数据", "选择你想看的内容", "在面板布局中开启需要的模块。", "设置面板布局", "使用过的模型", "暂无模型记录", "暂时无法获取模型记录", "重置时间", "今天", "本周剩余", "本月", "120 天活跃度", "输入", "输出", "缓存输入", "天", "小时", "分", "正在加载模型", "模型明细暂不可用", "更新失败", "正在读取账号", "正在同步额度与历史用量。", "暂时无法读取账号", "请检查连接后重试。", "先登录 Codex", "在 Codex 桌面应用或 CLI 中登录 ChatGPT 账号后，再回来检测。", "未找到 Codex", "请安装并打开 Codex，再回来检测。", "重新读取", "重新检测", "正在读取…", "读取失败", "等待登录", "等待 Codex"]
        case .traditionalChinese:
            values = ["目前額度", "可以繼續使用", "額度即將用盡", "等待額度恢復", "本機 · 即時", "今日 Token", "模型明細", "昨日 Token", "帳號摘要", "額外用量餘額", "等待帳號資訊", "剛剛更新", "正在重新整理…", "更新失敗 · 保留上次資料", "選擇你想看的內容", "在面板配置中開啟需要的模組。", "設定面板配置", "使用過的模型", "暫無模型紀錄", "暫時無法取得模型紀錄", "重設時間", "今天", "本週剩餘", "本月", "120 天活躍度", "輸入", "輸出", "快取輸入", "天", "小時", "分", "正在載入模型", "模型明細暫不可用", "更新失敗", "正在讀取帳號", "正在同步額度與歷史用量。", "暫時無法讀取帳號", "請檢查連線後重試。", "先登入 Codex", "在 Codex 桌面應用程式或 CLI 登入 ChatGPT 帳號後，再回來偵測。", "未找到 Codex", "請安裝並開啟 Codex，再回來偵測。", "重新讀取", "重新偵測", "正在讀取…", "讀取失敗", "等待登入", "等待 Codex"]
        case .english:
            values = ["Current quota", "Ready to use", "Quota running low", "Waiting for reset", "This Mac · Live", "Today's tokens", "Model details", "Yesterday", "Account summary", "Extra usage balance", "Waiting for account", "Just updated", "Refreshing…", "Update failed · Showing previous data", "Choose what to see", "Enable modules in Panel layout.", "Configure layout", "Models used", "No model records", "Model records unavailable", "Resets at", "Today", "Weekly remaining", "This month", "120-day activity", "Input", "Output", "Cached input", "days", "hr", "min", "Loading models", "Model details unavailable", "Update failed", "Reading your account", "Syncing quota and usage history.", "Unable to read your account", "Check your connection and try again.", "Sign in to Codex", "Sign in with ChatGPT in the Codex desktop app or CLI, then check again.", "Codex not found", "Install and open Codex, then check again.", "Try again", "Check again", "Reading…", "Read failed", "Waiting for sign-in", "Waiting for Codex"]
        case .japanese:
            values = ["現在の割り当て", "引き続き利用できます", "残りわずかです", "リセットを待っています", "この Mac · リアルタイム", "今日の Token", "モデルの内訳", "昨日の Token", "アカウント概要", "追加使用量の残高", "アカウント情報を待機中", "更新しました", "更新中…", "更新失敗 · 前回のデータを表示", "表示する内容を選択", "パネル配置で必要な項目を有効にします。", "パネル配置を設定", "使用したモデル", "モデル記録はありません", "モデル記録を取得できません", "リセット時刻", "今日", "今週の残り", "今月", "120 日間のアクティビティ", "入力", "出力", "キャッシュ入力", "日", "時間", "分", "モデルを読み込み中", "モデルの詳細は利用できません", "更新失敗", "アカウントを読み込み中", "割り当てと使用履歴を同期しています。", "アカウントを読み取れません", "接続を確認して再試行してください。", "Codex にログイン", "Codex アプリまたは CLI で ChatGPT にログインし、再検出してください。", "Codex が見つかりません", "Codex をインストールして開き、再検出してください。", "再読み込み", "再検出", "読み込み中…", "読み込み失敗", "ログインを待機", "Codex を待機"]
        case .korean:
            values = ["현재 할당량", "계속 사용할 수 있습니다", "할당량이 부족합니다", "재설정을 기다리는 중", "이 Mac · 실시간", "오늘 Token", "모델 상세", "어제 Token", "계정 요약", "추가 사용 잔액", "계정 정보 대기 중", "방금 업데이트", "새로 고치는 중…", "업데이트 실패 · 이전 데이터 표시", "보고 싶은 내용 선택", "패널 배치에서 필요한 모듈을 켜세요.", "패널 배치 설정", "사용한 모델", "모델 기록 없음", "모델 기록을 가져올 수 없음", "재설정 시간", "오늘", "이번 주 남음", "이번 달", "120일 활동", "입력", "출력", "캐시 입력", "일", "시간", "분", "모델 불러오는 중", "모델 상세를 사용할 수 없음", "업데이트 실패", "계정 읽는 중", "할당량과 사용 기록을 동기화합니다.", "계정을 읽을 수 없습니다", "연결을 확인하고 다시 시도하세요.", "Codex에 로그인", "Codex 앱이나 CLI에서 ChatGPT 계정에 로그인한 뒤 다시 확인하세요.", "Codex를 찾을 수 없음", "Codex를 설치하고 연 뒤 다시 확인하세요.", "다시 읽기", "다시 확인", "읽는 중…", "읽기 실패", "로그인 대기 중", "Codex 대기 중"]
        case .spanish:
            values = ["Cuota actual", "Puedes seguir usando", "Queda poca cuota", "Esperando el restablecimiento", "Este Mac · En vivo", "Tokens de hoy", "Detalle por modelo", "Tokens de ayer", "Resumen de la cuenta", "Saldo de uso adicional", "Esperando la cuenta", "Recién actualizado", "Actualizando…", "Error al actualizar · Datos anteriores", "Elige qué ver", "Activa módulos en Diseño del panel.", "Configurar diseño", "Modelos utilizados", "Sin registros de modelos", "Registros de modelos no disponibles", "Se restablece a las", "Hoy", "Resto semanal", "Este mes", "Actividad de 120 días", "Entrada", "Salida", "Entrada en caché", "días", "h", "min", "Cargando modelos", "Detalles de modelos no disponibles", "Error al actualizar", "Leyendo la cuenta", "Sincronizando cuota e historial de uso.", "No se pudo leer la cuenta", "Comprueba la conexión y reintenta.", "Inicia sesión en Codex", "Inicia sesión con ChatGPT en la app Codex o el CLI y vuelve a comprobar.", "No se encontró Codex", "Instala y abre Codex y vuelve a comprobar.", "Reintentar", "Comprobar de nuevo", "Leyendo…", "Error de lectura", "Esperando el inicio de sesión", "Esperando Codex"]
        }
        return values[key.rawValue]
    }

    static func window(_ window: RateLimitWindow, language: AppLanguage) -> String {
        guard let minutes = window.windowDurationMinutes else {
            return MeterFormatters.quotaTitle(for: window, language: language)
        }
        if minutes == 10_080 { return UsageStatisticsL10n.text(.weekly, language: language) }
        if minutes % 60 == 0 {
            switch language {
            case .simplifiedChinese: return "\(minutes / 60) 小时窗口"
            case .traditionalChinese: return "\(minutes / 60) 小時視窗"
            case .english: return "\(minutes / 60)-hour window"
            case .japanese: return "\(minutes / 60) 時間の枠"
            case .korean: return "\(minutes / 60)시간 구간"
            case .spanish: return "Ventana de \(minutes / 60) horas"
            }
        }
        return MeterFormatters.quotaTitle(for: window, language: language)
    }

    static func clock(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func reset(_ date: Date?, language: AppLanguage, includeTime: Bool = true) -> String {
        guard let date else { return "—" }
        let calendar = Calendar.current
        let chinese = language == .simplifiedChinese || language == .traditionalChinese
        let day: String
        if calendar.isDateInToday(date), includeTime {
            day = text(.today, language: language)
        } else if chinese {
            day = "\(calendar.component(.month, from: date)) 月 \(calendar.component(.day, from: date)) 日"
        } else {
            day = date.formatted(.dateTime.month(.abbreviated).day().locale(language.locale))
        }
        let value = includeTime ? "\(day) \(clock(date, language: language))" : day
        switch language {
        case .simplifiedChinese: return "\(value) 重置"
        case .traditionalChinese: return "\(value) 重設"
        case .english: return "Resets \(value)"
        case .japanese: return "\(value) にリセット"
        case .korean: return "\(value) 재설정"
        case .spanish: return "Se restablece \(value)"
        }
    }

    static func streak(_ days: Int, language: AppLanguage) -> String {
        if language == .simplifiedChinese { return "连续 \(days) 天" }
        if language == .traditionalChinese { return "連續 \(days) 天" }
        return L10n.streak(days, language: language)
    }

    static func peakTitle(_ language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: "单日峰值"
        case .traditionalChinese: "單日峰值"
        case .english: "Peak daily tokens"
        case .japanese: "1 日の最大 Token 数"
        case .korean: "일일 최대 토큰"
        case .spanish: "Máximo diario de tokens"
        }
    }

    static func heatmapHint(_ language: AppLanguage) -> String {
        if language == .simplifiedChinese { return "移动到日期查看用量" }
        if language == .traditionalChinese { return "移到日期查看用量" }
        return L10n.text(.hoverHeatmap, language: language)
    }

    static func modelCount(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: return "\(count) 个"
        case .traditionalChinese: return "\(count) 個"
        case .japanese: return "\(count) 件"
        case .korean: return "\(count)개"
        case .english, .spanish: return String(count)
        }
    }
}
