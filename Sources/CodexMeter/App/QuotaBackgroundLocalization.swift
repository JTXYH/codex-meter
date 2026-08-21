import Foundation

enum QuotaBackgroundL10n {
    enum Key: CaseIterable {
        case backgrounds
        case backgroundsHint
        case profiles
        case addBackground
        case enableBackground
        case quotaStatusImages
        case sufficient
        case attention
        case critical
        case uploadImage
        case supportedFormats
        case replace
        case recrop
        case cardPreview
        case automaticSwitchHint
        case autoSaved
        case emptyProfiles
        case newBackground
        case renameBackground
        case deleteBackground
        case cropImage
        case cropHint
        case panelIcon
        case defaultIcon
        case customIcon
        case livePreview
        case livePreviewHint
        case dragToPosition
        case zoom
        case rotateLeft
        case reset
        case cancel
        case finishCrop
        case imageError
        case switchProfile
        case previousQuotaStyle
        case nextQuotaStyle
    }

    static func text(_ key: Key, language: AppLanguage) -> String {
        switch key {
        case .backgrounds:
            localized("背景", "背景", "Backgrounds", "背景", "배경", "Fondos", language: language)
        case .backgroundsHint:
            localized(
                "为每个背景配置 3 张额度状态图",
                "為每個背景設定 3 張額度狀態圖",
                "Assign three quota-status images to each background",
                "背景ごとに 3 枚の割り当て状態画像を設定します",
                "배경마다 할당량 상태 이미지 3장을 설정합니다",
                "Asigna tres imágenes de estado de cuota a cada fondo",
                language: language
            )
        case .profiles:
            localized("背景", "背景", "Backgrounds", "背景", "배경", "Fondos", language: language)
        case .addBackground:
            localized("添加背景", "新增背景", "Add background", "背景を追加", "배경 추가", "Añadir fondo", language: language)
        case .enableBackground:
            localized("启用背景", "啟用背景", "Enable background", "背景を有効にする", "배경 사용", "Activar fondo", language: language)
        case .quotaStatusImages:
            localized("额度状态图", "額度狀態圖", "Quota status images", "割り当て状態画像", "할당량 상태 이미지", "Imágenes de estado", language: language)
        case .sufficient:
            localized("额度充足", "額度充足", "Plenty remaining", "十分な残量", "여유", "Cuota suficiente", language: language)
        case .attention:
            localized("额度注意", "額度注意", "Keep an eye on it", "残量に注意", "주의", "Atención", language: language)
        case .critical:
            localized("额度紧张", "額度緊張", "Running low", "残量わずか", "부족", "Cuota baja", language: language)
        case .uploadImage:
            localized("上传图片", "上傳圖片", "Upload image", "画像をアップロード", "이미지 업로드", "Subir imagen", language: language)
        case .supportedFormats:
            localized("支持 JPG、PNG，上传后可裁剪", "支援 JPG、PNG，上傳後可裁切", "JPG and PNG supported. Crop after upload.", "JPG と PNG に対応。アップロード後に切り抜けます。", "JPG와 PNG를 지원하며 업로드 후 자를 수 있습니다.", "Admite JPG y PNG. Recorta después de subir.", language: language)
        case .replace:
            localized("替换", "替換", "Replace", "置き換え", "교체", "Reemplazar", language: language)
        case .recrop:
            localized("重新裁剪", "重新裁切", "Recrop", "再切り抜き", "다시 자르기", "Recortar de nuevo", language: language)
        case .cardPreview:
            localized("卡片预览", "卡片預覽", "Card preview", "カードプレビュー", "카드 미리보기", "Vista previa", language: language)
        case .automaticSwitchHint:
            localized("图片会根据剩余额度自动切换", "圖片會依剩餘額度自動切換", "The image changes automatically with remaining quota", "残りの割り当てに応じて画像が自動で切り替わります", "남은 할당량에 따라 이미지가 자동으로 바뀝니다", "La imagen cambia automáticamente según la cuota restante", language: language)
        case .autoSaved:
            localized("已自动保存", "已自動儲存", "Saved automatically", "自動保存済み", "자동 저장됨", "Guardado automáticamente", language: language)
        case .emptyProfiles:
            localized("添加一个背景组开始配置", "新增背景組以開始設定", "Add a background set to get started", "背景セットを追加して設定を開始します", "배경 세트를 추가해 시작하세요", "Añade un conjunto de fondos para empezar", language: language)
        case .newBackground:
            localized("背景", "背景", "Background", "背景", "배경", "Fondo", language: language)
        case .renameBackground:
            localized("修改背景名称", "修改背景名稱", "Rename background", "背景名を変更", "배경 이름 변경", "Cambiar nombre del fondo", language: language)
        case .deleteBackground:
            localized("删除背景", "刪除背景", "Delete background", "背景を削除", "배경 삭제", "Eliminar fondo", language: language)
        case .cropImage:
            localized("裁剪图片", "裁切圖片", "Crop image", "画像を切り抜く", "이미지 자르기", "Recortar imagen", language: language)
        case .cropHint:
            localized("适配每周额度卡", "配合每週額度卡", "Fit the weekly quota card", "週間割り当てカードに合わせます", "주간 할당량 카드에 맞춥니다", "Ajusta la tarjeta de cuota semanal", language: language)
        case .panelIcon:
            localized("面板图标", "面板圖示", "Panel icon", "パネルアイコン", "패널 아이콘", "Icono del panel", language: language)
        case .defaultIcon:
            localized("默认", "預設", "Default", "デフォルト", "기본", "Predeterminado", language: language)
        case .customIcon:
            localized("自定义", "自訂", "Custom", "カスタム", "사용자 지정", "Personalizado", language: language)
        case .livePreview:
            localized("实时预览", "即時預覽", "Live preview", "ライブプレビュー", "실시간 미리보기", "Vista previa en directo", language: language)
        case .livePreviewHint:
            localized("每周额度卡中的显示效果", "每週額度卡中的顯示效果", "How it will look in the weekly quota card", "週間割り当てカードでの表示", "주간 할당량 카드 표시 모습", "Así se verá en la tarjeta semanal", language: language)
        case .dragToPosition:
            localized(
                "拖动或双指移动，捏合缩放",
                "拖動或雙指移動，捏合縮放",
                "Drag or pan with two fingers; pinch to zoom",
                "ドラッグまたは 2 本指で移動、ピンチでズーム",
                "드래그하거나 두 손가락으로 이동하고 핑치하여 확대/축소",
                "Arrastra o desplaza con dos dedos; pellizca para ampliar",
                language: language
            )
        case .zoom:
            localized("缩放", "縮放", "Zoom", "ズーム", "확대/축소", "Zoom", language: language)
        case .rotateLeft:
            localized("向左旋转", "向左旋轉", "Rotate left", "左に回転", "왼쪽으로 회전", "Girar a la izquierda", language: language)
        case .reset:
            localized("重置", "重設", "Reset", "リセット", "재설정", "Restablecer", language: language)
        case .cancel:
            localized("取消", "取消", "Cancel", "キャンセル", "취소", "Cancelar", language: language)
        case .finishCrop:
            localized("完成裁剪", "完成裁切", "Finish crop", "切り抜きを完了", "자르기 완료", "Terminar recorte", language: language)
        case .imageError:
            localized("无法读取或保存这张图片", "無法讀取或儲存此圖片", "This image could not be read or saved", "この画像を読み込むか保存できませんでした", "이미지를 읽거나 저장할 수 없습니다", "No se pudo leer o guardar esta imagen", language: language)
        case .switchProfile:
            localized("切换背景", "切換背景", "Switch background", "背景を切り替え", "배경 전환", "Cambiar fondo", language: language)
        case .previousQuotaStyle:
            localized("上一个额度样式", "上一個額度樣式", "Previous quota style", "前の割り当てスタイル", "이전 할당량 스타일", "Estilo de cuota anterior", language: language)
        case .nextQuotaStyle:
            localized("下一个额度样式", "下一個額度樣式", "Next quota style", "次の割り当てスタイル", "다음 할당량 스타일", "Siguiente estilo de cuota", language: language)
        }
    }

    static func rangeTitle(_ slot: QuotaBackgroundSlot) -> String {
        let range = slot.percentageRange
        return "\(range.lowerBound)-\(range.upperBound)%"
    }

    private static func localized(
        _ simplifiedChinese: String,
        _ traditionalChinese: String,
        _ english: String,
        _ japanese: String,
        _ korean: String,
        _ spanish: String,
        language: AppLanguage
    ) -> String {
        switch language {
        case .simplifiedChinese: simplifiedChinese
        case .traditionalChinese: traditionalChinese
        case .english: english
        case .japanese: japanese
        case .korean: korean
        case .spanish: spanish
        }
    }
}
