import Foundation

enum SettingsCopy {
    /// Simplified Chinese, Traditional Chinese, English, Japanese, Korean, Spanish.
    private static let copy: [String: [String]] = [
        "general": ["通用", "通用", "General", "一般", "일반", "General"],
        "menu": ["菜单栏", "選單列", "Menu bar", "メニューバー", "메뉴 막대", "Barra de menús"],
        "layout": ["面板布局", "面板配置", "Panel layout", "パネル構成", "패널 구성", "Diseño del panel"],
        "fonts": ["文字大小", "文字大小", "Text size", "文字サイズ", "글자 크기", "Tamaño del texto"],
        "refresh": ["更新频率", "更新頻率", "Refresh interval", "更新頻度", "새로고침 주기", "Frecuencia"],
        "data": ["本机数据", "本機資料", "Local data", "ローカルデータ", "로컬 데이터", "Datos locales"],
        "updates": ["关于与更新", "關於與更新", "About & updates", "情報とアップデート", "정보 및 업데이트", "Información"],
        "menuHint": ["余量始终在视线里，大小由你决定。", "餘量隨時可見，大小由你決定。", "Keep your remaining quota in view, at the size you prefer.", "残りの利用枠を好みのサイズで表示します。", "남은 한도를 원하는 크기로 표시합니다.", "Consulta la cuota restante al tamaño que prefieras."],
        "layoutHint": ["选择需要的模块，调整阅读顺序。", "選擇需要的模組，調整閱讀順序。", "Choose your modules and their reading order.", "表示する項目と順序を選びます。", "표시할 모듈과 순서를 선택합니다.", "Elige los módulos y su orden."],
        "fontsHint": ["调整数值、标题与说明的大小。", "調整數值、標題與說明的大小。", "Adjust values, headings and descriptions.", "数値、見出し、説明のサイズを調整します。", "수치, 제목, 설명의 크기를 조절합니다.", "Ajusta valores, títulos y descripciones."],
        "refreshHint": ["设置账号数据的自动更新间隔。", "設定帳號資料的自動更新間隔。", "Set how often account data refreshes.", "アカウント情報の自動更新間隔を設定します。", "계정 데이터의 자동 갱신 간격을 설정합니다.", "Configura la actualización de los datos de la cuenta."],
        "dataHint": ["查看占用，按时间清理本机记录。", "查看佔用，按時間清理本機紀錄。", "Review storage and clean local records by age.", "保存容量を確認し、古い記録を削除します。", "저장 공간을 확인하고 오래된 기록을 정리합니다.", "Consulta el espacio y elimina registros antiguos."],
        "panelTheme": ["面板主题", "面板主題", "Panel theme", "パネルテーマ", "패널 테마", "Tema del panel"],
        "viewPanel": ["查看主面板 →", "查看主面板 →", "View panel →", "パネルを表示 →", "패널 보기 →", "Ver panel →"],
        "quiet": ["A · 轻量面板", "A · 輕量面板", "A · Quiet panel", "A · シンプル", "A · 간결한 패널", "A · Panel ligero"],
        "instrument": ["B · 数据面板", "B · 資料面板", "B · Data panel", "B · データ", "B · 데이터 패널", "B · Panel de datos"],
        "quietDetail": ["圆环读数 · 独立卡片", "圓環讀數 · 獨立卡片", "Ring readings · Separate cards", "リング表示 · 独立カード", "원형 표시 · 개별 카드", "Lectura circular · Tarjetas"],
        "instrumentDetail": ["横向刻度 · 紧凑布局", "橫向刻度 · 緊湊配置", "Linear meters · Compact layout", "横型メーター · コンパクト", "가로 눈금 · 간결한 구성", "Medidores · Diseño compacto"],
        "startup": ["启动方式", "啟動方式", "Startup", "起動方法", "시작 방식", "Inicio"],
        "manual": ["手动启动", "手動啟動", "Manual", "手動", "수동 시작", "Manual"],
        "manualDetail": ["需要时打开", "需要時開啟", "Open when needed", "必要なときに起動", "필요할 때 실행", "Abrir cuando lo necesites"],
        "login": ["登录后启动", "登入後啟動", "At login", "ログイン時", "로그인 시", "Al iniciar sesión"],
        "loginDetail": ["随这台 Mac 启动", "隨這台 Mac 啟動", "Start with this Mac", "この Mac と起動", "이 Mac과 함께 실행", "Iniciar con este Mac"],
        "codex": ["跟随 Codex", "跟隨 Codex", "With Codex", "Codex と連動", "Codex와 함께", "Con Codex"],
        "codexDetail": ["与 Codex 同时启停", "與 Codex 同時啟停", "Start and stop together", "Codex と同時に起動・終了", "함께 시작하고 종료", "Iniciar y cerrar juntos"],
        "appearanceDetail": ["选择舒适的阅读方式。", "選擇舒適的閱讀方式。", "Choose a comfortable appearance.", "見やすい外観を選びます。", "편안한 화면 모드를 선택합니다.", "Elige una apariencia cómoda."],
        "languageDetail": ["界面使用的语言。", "介面使用的語言。", "The language used in the app.", "アプリの表示言語です。", "앱에서 사용할 언어입니다.", "El idioma de la interfaz."],
        "startupNote": ["Codex 打开时启动，退出时关闭。若系统要求授权，请在「登录项」中允许后台运行。", "Codex 開啟時啟動，結束時關閉。若系統要求授權，請在「登入項目」允許背景執行。", "Starts and stops with Codex. If macOS requests permission, allow background activity in Login Items.", "Codex と同時に起動・終了します。許可を求められたら「ログイン項目」でバックグラウンド実行を許可してください。", "Codex와 함께 시작하고 종료합니다. 권한이 필요하면 로그인 항목에서 백그라운드 실행을 허용하세요.", "Se inicia y cierra con Codex. Si macOS lo solicita, permite la ejecución en segundo plano en Ítems de inicio."],
        "approval": ["需要允许后台运行", "需要允許背景執行", "Allow background activity", "バックグラウンド実行を許可", "백그라운드 실행 허용 필요", "Permite la actividad en segundo plano"],
        "startupError": ["启动方式未能更改", "啟動方式未能變更", "Could not change startup mode", "起動方法を変更できません", "시작 방식을 변경하지 못했습니다", "No se pudo cambiar el inicio"],
        "iconSize": ["图标大小", "圖示大小", "Icon size", "アイコンサイズ", "아이콘 크기", "Tamaño del icono"],
        "menuPreview": ["菜单栏预览", "選單列預覽", "Menu bar preview", "メニューバーのプレビュー", "메뉴 막대 미리 보기", "Vista de la barra de menús"],
        "menuFile": ["文件", "檔案", "File", "ファイル", "파일", "Archivo"],
        "menuEdit": ["编辑", "編輯", "Edit", "編集", "편집", "Edición"],
        "appearanceAuto": ["自动", "自動", "Auto", "自動", "자동", "Auto"],
        "iconSizeDetail": ["调整圆环大小，数值保持系统字号。", "調整圓環大小，數值維持系統字級。", "Resize the ring; numbers keep the system text size.", "リングのサイズを変更します。数値はシステムの文字サイズを使います。", "원형 크기를 조절하며 수치는 시스템 글자 크기를 유지합니다.", "Ajusta el anillo; las cifras mantienen el tamaño del sistema."],
        "menuNote": ["显示账号当前剩余额度。圆环和数字会随官方额度更新。", "顯示帳號目前剩餘額度。圓環和數字會隨官方額度更新。", "Shows your account’s remaining quota. The ring and number follow official quota updates.", "アカウントの残り利用枠を表示します。リングと数値は公式の更新に連動します。", "계정의 남은 한도를 표시합니다. 원형과 수치는 공식 한도에 따라 갱신됩니다.", "Muestra la cuota restante. El anillo y las cifras siguen los datos oficiales."],
        "quota": ["官方额度", "官方額度", "Official quota", "公式の利用枠", "공식 한도", "Cuota oficial"],
        "today": ["今日明细", "今日明細", "Today’s details", "今日の詳細", "오늘 상세", "Detalle de hoy"],
        "overview": ["活跃度概览", "活躍度概覽", "Activity overview", "利用状況", "활동 개요", "Actividad"],
        "history": ["用量统计", "用量統計", "Usage history", "使用量の統計", "사용량 통계", "Historial de uso"],
        "heatmap": ["120 天热力图", "120 天熱力圖", "120-day heatmap", "120 日間のヒートマップ", "120일 히트맵", "Mapa de 120 días"],
        "summary": ["账号摘要", "帳號摘要", "Account summary", "アカウント概要", "계정 요약", "Resumen de cuenta"],
        "credits": ["Credits 余额", "Credits 餘額", "Credits balance", "Credits 残高", "Credits 잔액", "Saldo de Credits"],
        "quotaDetail": ["5 小时与周额度", "5 小時與週額度", "5-hour and weekly limits", "5 時間と週間の利用枠", "5시간 및 주간 한도", "Límites de 5 horas y semanales"],
        "todayDetail": ["输入、输出、缓存与使用模型", "輸入、輸出、快取與使用模型", "Input, output, cache and models", "入力、出力、キャッシュ、モデル", "입력, 출력, 캐시 및 모델", "Entrada, salida, caché y modelos"],
        "overviewDetail": ["昨日、近 7 天与本月 Token", "昨日、近 7 天與本月 Token", "Yesterday, last 7 days and this month", "昨日、過去 7 日間、今月のトークン", "어제, 최근 7일, 이번 달 토큰", "Ayer, últimos 7 días y este mes"],
        "historyDetail": ["按日、周、月、年查看用量和模型", "按日、週、月、年查看用量和模型", "Usage and models by day, week, month or year", "日・週・月・年別の使用量とモデル", "일, 주, 월, 연도별 사용량과 모델", "Uso y modelos por día, semana, mes o año"],
        "heatmapDetail": ["近 120 天的使用分布", "近 120 天的使用分布", "Usage over the last 120 days", "過去 120 日間の利用分布", "최근 120일 사용 분포", "Uso de los últimos 120 días"],
        "summaryDetail": ["累计用量、峰值与使用纪录", "累計用量、峰值與使用紀錄", "Totals, peaks and activity records", "累計、ピーク、利用記録", "누적 사용량, 최고치 및 기록", "Totales, picos y registros"],
        "resetCredits": ["充值卡", "充值卡", "Reset cards", "リセットカード", "초기화 카드", "Tarjetas de reinicio"],
        "resetCreditsDetail": ["可用数量与逐张到期时间", "可用數量與每張到期時間", "Available count and expiry of each card", "利用可能枚数と各カードの有効期限", "사용 가능한 수량과 각 카드의 만료 시간", "Cantidad disponible y caducidad de cada tarjeta"],
        "creditsDetail": ["账号额外 Credits", "帳號額外 Credits", "Additional account Credits", "アカウントの追加 Credits", "계정 추가 Credits", "Credits adicionales"],
        "reorderHint": ["拖动模块，或使用上下箭头调整顺序。", "拖動模組，或使用上下箭頭調整順序。", "Drag modules or use the arrows to reorder them.", "ドラッグまたは上下矢印で並べ替えます。", "모듈을 끌거나 화살표로 순서를 변경합니다.", "Arrastra los módulos o usa las flechas para ordenarlos."],
        "defaultPeriod": ["默认周期", "預設週期", "Default period", "表示単位", "기본 기간", "Período"],
        "displayRange": ["显示范围", "顯示範圍", "Display range", "表示範囲", "표시 범위", "Intervalo"],
        "scopeDetail": ["额度卡片可以单独设置。", "額度卡片可以單獨設定。", "The quota card can use separate sizes.", "利用枠カードは個別に設定できます。", "한도 카드는 별도로 설정할 수 있습니다.", "La tarjeta de cuota se puede ajustar por separado."],
        "fontDetail": ["说明", "說明", "Details", "説明", "설명", "Detalles"],
        "currentQuota": ["当前额度", "目前額度", "Current quota", "現在の利用枠", "현재 한도", "Cuota actual"],
        "yesterdayUsage": ["昨日用量", "昨日用量", "Yesterday’s usage", "昨日の使用量", "어제 사용량", "Uso de ayer"],
        "fontQuotaDetail": ["剩余额度 · 2 小时 18 分后重置", "剩餘額度 · 2 小時 18 分後重設", "Remaining quota · Resets in 2h 18m", "残り利用枠 · 2 時間 18 分後にリセット", "남은 한도 · 2시간 18분 후 재설정", "Cuota restante · Se restablece en 2 h 18 min"],
        "fontDateDetail": ["2026 年 10 月 14 日 · Token", "2026 年 10 月 14 日 · Token", "14 Oct 2026 · Tokens", "2026 年 10 月 14 日 · トークン", "2026년 10월 14일 · 토큰", "14 oct 2026 · Tokens"],
        "fontApply": ["应用到所有内容卡片", "套用到所有內容卡片", "Apply to all content cards", "すべてのカードに適用", "모든 콘텐츠 카드에 적용", "Aplicar a todas las tarjetas"],
        "refreshTitle": ["自动更新", "自動更新", "Automatic refresh", "自動更新", "자동 새로고침", "Actualización automática"],
        "refreshDetail": ["获取账号额度及历史用量。", "取得帳號額度及歷史用量。", "Fetch account quota and usage history.", "アカウントの利用枠と使用履歴を取得します。", "계정 한도와 사용 기록을 가져옵니다.", "Obtiene la cuota y el historial de la cuenta."],
        "refreshCustom": ["间隔分钟数", "間隔分鐘數", "Interval in minutes", "間隔（分）", "간격(분)", "Intervalo en minutos"],
        "refreshCustomDetail": ["可以设置为 1–1440 分钟。", "可以設定為 1–1440 分鐘。", "Choose from 1 to 1,440 minutes.", "1～1440 分に設定できます。", "1~1440분으로 설정할 수 있습니다.", "Elige entre 1 y 1440 minutos."],
        "minuteUnit": ["分钟", "分鐘", "min", "分", "분", "min"],
        "refreshManual": ["需要时，也可以在主面板手动刷新。", "需要時，也可以在主面板手動更新。", "You can also refresh manually from the panel.", "必要なときはパネルから手動で更新できます。", "필요할 때 패널에서 직접 새로고침할 수도 있습니다.", "También puedes actualizar desde el panel."],
        "localSize": ["本机数据占用", "本機資料佔用", "Local storage", "ローカル保存容量", "로컬 저장 공간", "Almacenamiento local"],
        "localRecords": ["本机统计记录", "本機統計紀錄", "Local usage records", "ローカルの統計記録", "로컬 통계 기록", "Registros locales de uso"],
        "savedRecords": ["已保存的记录", "已儲存的紀錄", "Saved records", "保存済みの記録", "저장된 기록", "Registros guardados"],
        "refreshAction": ["刷新", "更新", "Refresh", "更新", "새로고침", "Actualizar"],
        "cleanup": ["清理本机记录", "清理本機紀錄", "Clean local records", "ローカル記録の削除", "로컬 기록 정리", "Limpiar registros locales"],
        "cleanupDetail": ["选择要清理的时间范围。", "選擇要清理的時間範圍。", "Choose the age of records to remove.", "削除する記録の期間を選びます。", "정리할 기록의 기간을 선택합니다.", "Elige la antigüedad de los registros."],
        "cleanupPreserve": ["只清理本机实时统计与旧历史缓存。账号历史、设置和 Codex 会话均保留。", "只清理本機即時統計與舊歷史快取。帳號歷史、設定和 Codex 會話均保留。", "Only local live statistics and legacy caches are cleared. Account history, settings and Codex conversations are kept.", "ローカル統計と古いキャッシュのみ削除します。アカウント履歴、設定、Codex の会話は残ります。", "로컬 실시간 통계와 이전 캐시만 정리합니다. 계정 기록, 설정, Codex 대화는 유지됩니다.", "Solo se borran las estadísticas locales y cachés antiguos. Se conservan el historial de la cuenta, los ajustes y las conversaciones."],
        "cleanupAction": ["清理记录…", "清理紀錄…", "Clean records…", "記録を削除…", "기록 정리…", "Limpiar registros…"],
        "cleanupAll": ["全部本机统计", "全部本機統計", "All local statistics", "すべてのローカル統計", "모든 로컬 통계", "Todas las estadísticas locales"],
        "cleanupCustom": ["自定义保留天数", "自訂保留天數", "Custom retention", "保持日数を指定", "보관 일수 지정", "Conservación personalizada"],
        "cleanupDaysHint": ["保留最近这段时间的记录。", "保留最近這段時間的紀錄。", "Keep records from this recent period.", "この期間の新しい記録を残します。", "최근 이 기간의 기록을 유지합니다.", "Conserva los registros de este período."],
        "dayUnit": ["天", "天", "days", "日", "일", "días"],
        "cleanupConfirmTitle": ["清理本机统计记录？", "清理本機統計紀錄？", "Clear local usage records?", "ローカル統計を削除しますか？", "로컬 통계 기록을 정리할까요?", "¿Limpiar los registros locales?"],
        "cleanupPreserveShort": ["保留账号历史、设置和 Codex 会话。", "保留帳號歷史、設定和 Codex 會話。", "Account history, settings and Codex conversations are kept.", "アカウント履歴、設定、Codex の会話は残ります。", "계정 기록, 설정 및 Codex 대화는 유지됩니다.", "Se conservan el historial de la cuenta, los ajustes y las conversaciones."],
        "cleanupConfirm": ["确认清理", "確認清理", "Confirm cleanup", "削除する", "정리 확인", "Confirmar limpieza"],
        "cleanupAllDetail": ["将清理已保存的全部本机统计。", "將清理已儲存的全部本機統計。", "All saved local usage statistics will be removed.", "保存済みのローカル統計をすべて削除します。", "저장된 모든 로컬 사용 통계를 삭제합니다.", "Se eliminarán todas las estadísticas locales guardadas."],
        "storageLoading": ["正在读取存储信息…", "正在讀取儲存資訊…", "Reading storage information…", "保存情報を読み込み中…", "저장 정보를 읽는 중…", "Leyendo el almacenamiento…"],
        "storageLoadingDetail": ["正在查看本机统计记录占用。", "正在查看本機統計紀錄佔用。", "Checking the size of local records.", "ローカル記録の容量を確認しています。", "로컬 기록의 크기를 확인하고 있습니다.", "Comprobando el tamaño de los registros."],
        "storageEmpty": ["暂无本机统计记录", "暫無本機統計紀錄", "No local records yet", "ローカルの記録はありません", "로컬 기록이 없습니다", "Sin registros locales"],
        "storageEmptyDetail": ["开始使用 Codex 后，可在这里查看本机存储占用。", "開始使用 Codex 後，可在這裡查看本機儲存佔用。", "Local storage use appears here after you start using Codex.", "Codex を使うと、ここに保存容量が表示されます。", "Codex를 사용하면 여기에 저장 공간이 표시됩니다.", "El espacio usado aparecerá al empezar a usar Codex."],
        "storageError": ["暂时无法读取本机数据", "暫時無法讀取本機資料", "Could not read local data", "ローカルデータを読み込めません", "로컬 데이터를 읽지 못했습니다", "No se pudieron leer los datos"],
        "storageErrorDetail": ["请稍后重试。账号历史不会受影响。", "請稍後重試。帳號歷史不會受影響。", "Try again later. Account history is unaffected.", "後でもう一度お試しください。アカウント履歴には影響しません。", "나중에 다시 시도하세요. 계정 기록에는 영향이 없습니다.", "Inténtalo más tarde. El historial de la cuenta no cambia."],
        "retry": ["重试", "重試", "Retry", "再試行", "다시 시도", "Reintentar"],
        "appDescription": ["在菜单栏查看 Codex 额度与用量", "在選單列查看 Codex 額度與用量", "Codex quota and usage in your menu bar", "メニューバーで Codex の利用枠と使用量を確認", "메뉴 막대에서 Codex 한도와 사용량 확인", "Cuota y uso de Codex en la barra de menús"],
        "appUpdates": ["应用更新", "應用程式更新", "App updates", "アプリの更新", "앱 업데이트", "Actualizaciones"],
        "updateConnecting": ["正在连接更新服务。", "正在連線更新服務。", "Connecting to the update service.", "更新サービスに接続しています。", "업데이트 서비스에 연결 중입니다.", "Conectando con el servicio de actualizaciones."],
        "updateLatestDetail": ["目前没有可用更新。", "目前沒有可用更新。", "There are no updates available.", "利用可能な更新はありません。", "사용 가능한 업데이트가 없습니다.", "No hay actualizaciones disponibles."],
        "updateAvailable": ["有新版本可用", "有新版本可用", "A new version is available", "新しいバージョンがあります", "새 버전을 사용할 수 있습니다", "Hay una nueva versión"],
        "updateAvailableDetail": ["可在更新窗口查看版本详情。", "可在更新視窗查看版本詳情。", "View version details in the update window.", "更新ウィンドウで詳細を確認できます。", "업데이트 창에서 버전 정보를 확인하세요.", "Consulta los detalles en la ventana de actualización."],
        "updateRetryDetail": ["请检查网络连接后重试。", "請檢查網路連線後重試。", "Check your connection and try again.", "接続を確認して再試行してください。", "연결을 확인한 뒤 다시 시도하세요.", "Comprueba la conexión e inténtalo de nuevo."],
        "updateRetry": ["重新检查", "重新檢查", "Check again", "再確認", "다시 확인", "Comprobar de nuevo"],
        "updateDownload": ["下载更新", "下載更新", "Download update", "更新をダウンロード", "업데이트 다운로드", "Descargar actualización"],
        "developmentVersion": ["当前为开发版本", "目前為開發版本", "Development build", "開発版です", "개발 버전", "Versión de desarrollo"],
        "projectHome": ["项目主页", "專案首頁", "Project website", "プロジェクトページ", "프로젝트 홈페이지", "Página del proyecto"],
        "reportIssue": ["反馈问题", "回報問題", "Report an issue", "問題を報告", "문제 신고", "Informar de un problema"],
        "close": ["关闭", "關閉", "Close", "閉じる", "닫기", "Cerrar"],
        "moveUp": ["上移", "上移", "Move up", "上へ", "위로", "Subir"],
        "moveDown": ["下移", "下移", "Move down", "下へ", "아래로", "Bajar"]
    ]

    static func text(_ key: String, language: AppLanguage) -> String {
        guard let values = copy[key] else { return key }
        let index: Int = switch language {
        case .simplifiedChinese: 0
        case .traditionalChinese: 1
        case .english: 2
        case .japanese: 3
        case .korean: 4
        case .spanish: 5
        }
        return values[index]
    }

    static func cleanupAge(_ days: Int, language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: "\(days) 天前的记录"
        case .traditionalChinese: "\(days) 天前的紀錄"
        case .english: "Records older than \(days) days"
        case .japanese: "\(days) 日より前の記録"
        case .korean: "\(days)일 이전 기록"
        case .spanish: "Registros de hace más de \(days) días"
        }
    }

    static func cleanupAgeDetail(_ days: Int, language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: "将清理 \(days) 天前的本机统计。"
        case .traditionalChinese: "將清理 \(days) 天前的本機統計。"
        case .english: "Local statistics older than \(days) days will be removed."
        case .japanese: "\(days) 日より前のローカル統計を削除します。"
        case .korean: "\(days)일 이전의 로컬 통계를 삭제합니다."
        case .spanish: "Se borrarán las estadísticas locales de hace más de \(days) días."
        }
    }

    static func refreshEvery(_ minutes: Int, language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: "每 \(minutes) 分钟更新"
        case .traditionalChinese: "每 \(minutes) 分鐘更新"
        case .english: "Refresh every \(minutes) min"
        case .japanese: "\(minutes) 分ごとに更新"
        case .korean: "\(minutes)분마다 갱신"
        case .spanish: "Actualizar cada \(minutes) min"
        }
    }

    static func sectionKey(_ section: DashboardSection) -> String {
        switch section {
        case .quota: "quota"
        case .tokenActivity: "today"
        case .activityOverview: "overview"
        case .monthlyUsage: "history"
        case .usageHeatmap: "heatmap"
        case .usageSummary: "summary"
        case .creditsBalance: "credits"
        case .resetCredits: "resetCredits"
        }
    }

    static func period(_ period: UsagePeriod, language: AppLanguage) -> String {
        let values: [String]
        switch language {
        case .simplifiedChinese: values = ["日", "周", "月", "年"]
        case .traditionalChinese: values = ["日", "週", "月", "年"]
        case .english: values = ["Day", "Week", "Month", "Year"]
        case .japanese: values = ["日", "週", "月", "年"]
        case .korean: values = ["일", "주", "월", "년"]
        case .spanish: values = ["Día", "Semana", "Mes", "Año"]
        }
        let index: Int = switch period { case .hour, .day: 0; case .week: 1; case .month: 2; case .year: 3 }
        return values[index]
    }

    static func range(_ count: Int, period: UsagePeriod, language: AppLanguage) -> String {
        if language == .simplifiedChinese || language == .traditionalChinese {
            if count == 0 { return "全部" }
            let unit: String = switch period {
            case .hour: language == .simplifiedChinese ? "小时" : "小時"
            case .day: "天"
            case .week: language == .simplifiedChinese ? "周" : "週"
            case .month: language == .simplifiedChinese ? "个月" : "個月"
            case .year: "年"
            }
            return "最近 \(count) \(unit)"
        }
        return UsageStatisticsL10n.range(count, period: period, language: language)
    }
}
