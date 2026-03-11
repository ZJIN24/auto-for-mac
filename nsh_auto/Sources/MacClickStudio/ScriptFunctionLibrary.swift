import Foundation

struct ScriptFunctionDoc: Identifiable, Hashable {
    let category: String
    let name: String
    let pythonLikeSignature: String
    let javaScriptSignature: String
    let summary: String
    let pythonLikeExample: String
    let javaScriptExample: String
    let pythonLikeSnippet: String
    let javaScriptSnippet: String
    let keywords: [String]

    var id: String { name }

    init(
        category: String,
        name: String,
        pythonLikeSignature: String,
        javaScriptSignature: String,
        summary: String,
        pythonLikeExample: String,
        javaScriptExample: String,
        pythonLikeSnippet: String? = nil,
        javaScriptSnippet: String? = nil,
        keywords: [String]
    ) {
        self.category = category
        self.name = name
        self.pythonLikeSignature = pythonLikeSignature
        self.javaScriptSignature = javaScriptSignature
        self.summary = summary
        self.pythonLikeExample = pythonLikeExample
        self.javaScriptExample = javaScriptExample
        self.pythonLikeSnippet = pythonLikeSnippet ?? pythonLikeExample
        self.javaScriptSnippet = javaScriptSnippet ?? javaScriptExample
        self.keywords = keywords
    }

    func signature(for language: ScriptLanguage) -> String {
        switch language {
        case .pythonLike:
            pythonLikeSignature
        case .javaScript:
            javaScriptSignature
        }
    }

    func example(for language: ScriptLanguage) -> String {
        switch language {
        case .pythonLike:
            pythonLikeExample
        case .javaScript:
            javaScriptExample
        }
    }

    func snippet(for language: ScriptLanguage) -> String {
        switch language {
        case .pythonLike:
            pythonLikeSnippet
        case .javaScript:
            javaScriptSnippet
        }
    }

    func matches(_ query: String) -> Bool {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { return true }
        let haystack = [
            category,
            name,
            pythonLikeSignature,
            javaScriptSignature,
            summary,
            pythonLikeExample,
            javaScriptExample
        ]
        .appending(contentsOf: keywords)
        .joined(separator: " ")
        .lowercased()
        return haystack.contains(value)
    }
}

enum ScriptLanguage: String, Codable, CaseIterable, Identifiable {
    case pythonLike
    case javaScript

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pythonLike:
            return "Python 3"
        case .javaScript:
            return "JavaScript"
        }
    }

    var defaultFileExtension: String {
        switch self {
        case .pythonLike:
            return "py"
        case .javaScript:
            return "js"
        }
    }

    var editorHint: String {
        switch self {
        case .pythonLike:
            return "Python 3 模式直接调用本机 python3：支持标准 Python 语法、标准库 import，以及 click、long_press、drag、wait_color、find_image、ocr_text、click_relative 等函数。"
        case .javaScript:
            return "JavaScript 模式保留完整 helper：click、longPress、drag、waitColor、findImage、findColor、ocr_text、current_window、clickRelative 等函数都可以直接用。"
        }
    }
}

enum ScriptFunctionLibrary {
    static let docs: [ScriptFunctionDoc] = [
        ScriptFunctionDoc(
            category: "日志",
            name: "log",
            pythonLikeSignature: "log(message, ...items)",
            javaScriptSignature: "log(message, ...items)",
            summary: "输出日志到运行面板，适合调试当前脚本状态。",
            pythonLikeExample: "log('开始执行脚本')",
            javaScriptExample: "log('开始执行脚本');",
            keywords: ["print", "输出", "日志", "调试"]
        ),
        ScriptFunctionDoc(
            category: "等待",
            name: "sleep_ms",
            pythonLikeSignature: "sleep_ms(milliseconds)",
            javaScriptSignature: "sleep_ms(milliseconds)",
            summary: "阻塞等待指定毫秒，适合点击后留一点界面响应时间。",
            pythonLikeExample: "sleep_ms(500)",
            javaScriptExample: "sleep_ms(500);",
            keywords: ["sleep", "暂停", "等待", "延时"]
        ),
        ScriptFunctionDoc(
            category: "点击",
            name: "click",
            pythonLikeSignature: "click(x, y)",
            javaScriptSignature: "click(x, y)",
            summary: "点击绝对屏幕坐标；如果开启 PID 定向投递，会优先投递到锁定窗口进程。",
            pythonLikeExample: "click(640, 360)",
            javaScriptExample: "click(640, 360);",
            keywords: ["tap", "鼠标", "绝对坐标", "点击"]
        ),
        ScriptFunctionDoc(
            category: "窗口",
            name: "current_window",
            pythonLikeSignature: "current_window()",
            javaScriptSignature: "current_window()",
            summary: "读取当前锁定窗口的信息，返回 windowID / pid / x / y / width / height。",
            pythonLikeExample: "win = current_window()\nif win:\n    log('当前窗口', win['pid'], win['x'], win['y'])",
            javaScriptExample: "const win = current_window();\nif (win) {\n  log('当前窗口', win.pid, win.x, win.y);\n}",
            pythonLikeSnippet: "win = current_window()",
            javaScriptSnippet: "const win = current_window();",
            keywords: ["锁定窗口", "当前窗口", "pid", "句柄", "handle"]
        ),
        ScriptFunctionDoc(
            category: "窗口",
            name: "current_window_rect",
            pythonLikeSignature: "current_window_rect()",
            javaScriptSignature: "current_window_rect()",
            summary: "返回当前锁定窗口的屏幕区域，可直接给找图或找色函数使用。",
            pythonLikeExample: "window_area = current_window_rect()\nmatch = find_image('T1', window_area, 0.92)",
            javaScriptExample: "const windowArea = current_window_rect();\nconst match = find_image('T1', windowArea, 0.92);",
            pythonLikeSnippet: "window_area = current_window_rect()",
            javaScriptSnippet: "const windowArea = current_window_rect();",
            keywords: ["窗口区域", "搜索范围", "窗口矩形"]
        ),
        ScriptFunctionDoc(
            category: "点击",
            name: "click_relative",
            pythonLikeSignature: "click_relative(x, y)",
            javaScriptSignature: "click_relative(x, y)",
            summary: "基于当前锁定窗口左上角做相对点击，更适合窗口位置会变化的场景。",
            pythonLikeExample: "click_relative(120, 48)",
            javaScriptExample: "click_relative(120, 48);",
            keywords: ["相对点击", "窗口坐标", "单窗口", "锁定窗口"]
        ),
        ScriptFunctionDoc(
            category: "点击",
            name: "long_press",
            pythonLikeSignature: "long_press(x, y, milliseconds=700)",
            javaScriptSignature: "longPress(x, y, milliseconds=700)",
            summary: "长按绝对坐标，可用于蓄力、菜单按住、拖动前按下等场景。",
            pythonLikeExample: "long_press(640, 360, 900)",
            javaScriptExample: "longPress(640, 360, 900);",
            keywords: ["长按", "按住", "按压", "mouse hold", "longPress"]
        ),
        ScriptFunctionDoc(
            category: "点击",
            name: "long_press_relative",
            pythonLikeSignature: "long_press_relative(x, y, milliseconds=700)",
            javaScriptSignature: "longPressRelative(x, y, milliseconds=700)",
            summary: "对当前锁定窗口做相对长按，适合固定窗口内的技能键、拖动起手点。",
            pythonLikeExample: "long_press_relative(160, 84, 800)",
            javaScriptExample: "longPressRelative(160, 84, 800);",
            keywords: ["窗口长按", "相对长按", "单窗口", "longPressRelative"]
        ),
        ScriptFunctionDoc(
            category: "点击",
            name: "drag",
            pythonLikeSignature: "drag(start_x, start_y, end_x, end_y, milliseconds=280)",
            javaScriptSignature: "drag(startX, startY, endX, endY, milliseconds=280)",
            summary: "执行绝对坐标拖动，适合滑块、滚动条、地图拖拽。",
            pythonLikeExample: "drag(240, 420, 640, 420, 260)",
            javaScriptExample: "drag(240, 420, 640, 420, 260);",
            keywords: ["拖动", "拖拽", "滑动", "drag", "drag_to", "绝对坐标"]
        ),
        ScriptFunctionDoc(
            category: "点击",
            name: "drag_relative",
            pythonLikeSignature: "drag_relative(start_x, start_y, end_x, end_y, milliseconds=280)",
            javaScriptSignature: "dragRelative(startX, startY, endX, endY, milliseconds=280)",
            summary: "对当前锁定窗口做相对拖动，最适合单窗口脚本。",
            pythonLikeExample: "drag_relative(80, 320, 420, 320, 260)",
            javaScriptExample: "dragRelative(80, 320, 420, 320, 260);",
            keywords: ["窗口拖动", "相对拖动", "单窗口", "滑块", "dragRelative"]
        ),
        ScriptFunctionDoc(
            category: "颜色",
            name: "get_color",
            pythonLikeSignature: "get_color(x, y)",
            javaScriptSignature: "get_color(x, y)",
            summary: "读取指定屏幕坐标的颜色，返回十六进制字符串。",
            pythonLikeExample: "hex_color = get_color(100, 200)",
            javaScriptExample: "const hexColor = get_color(100, 200);",
            keywords: ["颜色", "取色", "hex", "RGB"]
        ),
        ScriptFunctionDoc(
            category: "颜色",
            name: "get_color_relative",
            pythonLikeSignature: "get_color_relative(x, y)",
            javaScriptSignature: "get_color_relative(x, y)",
            summary: "读取当前锁定窗口内的相对坐标颜色。",
            pythonLikeExample: "hp_color = get_color_relative(88, 32)",
            javaScriptExample: "const hpColor = get_color_relative(88, 32);",
            keywords: ["窗口取色", "相对颜色", "比色"]
        ),
        ScriptFunctionDoc(
            category: "颜色",
            name: "wait_color",
            pythonLikeSignature: "wait_color(x, y, hex, tolerance=8, timeout_ms=3000, interval_ms=120)",
            javaScriptSignature: "wait_color(x, y, hex, tolerance=8, timeout_ms=3000, interval_ms=120)",
            summary: "等待某个点出现目标颜色；常用于按钮高亮、状态灯、血条等检测。",
            pythonLikeExample: "if wait_color(100, 200, '#FFCC00', 12, 2000):\n    click(100, 200)",
            javaScriptExample: "if (wait_color(100, 200, '#FFCC00', 12, 2000)) {\n  click(100, 200);\n}",
            pythonLikeSnippet: "if wait_color(100, 200, '#FFCC00', 12, 2000):\n    click(100, 200)",
            javaScriptSnippet: "if (wait_color(100, 200, '#FFCC00', 12, 2000)) {\n  click(100, 200);\n}",
            keywords: ["等待颜色", "比色", "容差", "轮询"]
        ),
        ScriptFunctionDoc(
            category: "找图",
            name: "find_image",
            pythonLikeSignature: "find_image(template_name, rect=None, threshold=0.94)",
            javaScriptSignature: "find_image(templateName, rect=null, threshold=0.94)",
            summary: "在区域内找模板，返回 x / y / score / left / top / width / height。",
            pythonLikeExample: "match = find_image('T1', rect(0, 0, 800, 600), 0.92)\nif match:\n    click(match['x'], match['y'])",
            javaScriptExample: "const match = find_image('T1', rect(0, 0, 800, 600), 0.92);\nif (match) {\n  click(match.x, match.y);\n}",
            pythonLikeSnippet: "match = find_image('T1', rect(0, 0, 800, 600), 0.92)",
            javaScriptSnippet: "const match = find_image('T1', rect(0, 0, 800, 600), 0.92);",
            keywords: ["模板", "相似度", "图像识别", "找图"]
        ),
        ScriptFunctionDoc(
            category: "找图",
            name: "find_image_in_window",
            pythonLikeSignature: "find_image_in_window(template_name, threshold=0.94)",
            javaScriptSignature: "find_image_in_window(templateName, threshold=0.94)",
            summary: "只在当前锁定窗口范围内找图，减少误识别。",
            pythonLikeExample: "match = find_image_in_window('T1', 0.93)\nif match:\n    click(match['x'], match['y'])",
            javaScriptExample: "const match = find_image_in_window('T1', 0.93);\nif (match) {\n  click(match.x, match.y);\n}",
            pythonLikeSnippet: "match = find_image_in_window('T1', 0.93)",
            javaScriptSnippet: "const match = find_image_in_window('T1', 0.93);",
            keywords: ["窗口内找图", "模板", "单窗口"]
        ),
        ScriptFunctionDoc(
            category: "找图",
            name: "click_template",
            pythonLikeSignature: "click_template(template_name, rect=None, threshold=0.94)",
            javaScriptSignature: "click_template(templateName, rect=null, threshold=0.94)",
            summary: "找到模板后直接点击命中中心点，适合按钮类操作。",
            pythonLikeExample: "click_template('T1', current_window_rect(), 0.92)",
            javaScriptExample: "click_template('T1', current_window_rect(), 0.92);",
            keywords: ["模板点击", "直接调用", "找图后点击"]
        ),
        ScriptFunctionDoc(
            category: "找色",
            name: "find_color",
            pythonLikeSignature: "find_color(hex, rect=None, tolerance=12)",
            javaScriptSignature: "find_color(hex, rect=null, tolerance=12)",
            summary: "在区域里查找颜色，返回首个命中的坐标。",
            pythonLikeExample: "match = find_color('#FFFFFF', rect(0, 0, 300, 120), 8)\nif match:\n    click(match['x'], match['y'])",
            javaScriptExample: "const match = find_color('#FFFFFF', rect(0, 0, 300, 120), 8);\nif (match) {\n  click(match.x, match.y);\n}",
            pythonLikeSnippet: "match = find_color('#FFFFFF', rect(0, 0, 300, 120), 8)",
            javaScriptSnippet: "const match = find_color('#FFFFFF', rect(0, 0, 300, 120), 8);",
            keywords: ["找色", "颜色识别", "区域"]
        ),
        ScriptFunctionDoc(
            category: "找色",
            name: "find_color_in_window",
            pythonLikeSignature: "find_color_in_window(hex, tolerance=12)",
            javaScriptSignature: "find_color_in_window(hex, tolerance=12)",
            summary: "只在当前锁定窗口范围内找色。",
            pythonLikeExample: "match = find_color_in_window('#33CC66', 10)\nif match:\n    click(match['x'], match['y'])",
            javaScriptExample: "const match = find_color_in_window('#33CC66', 10);\nif (match) {\n  click(match.x, match.y);\n}",
            pythonLikeSnippet: "match = find_color_in_window('#33CC66', 10)",
            javaScriptSnippet: "const match = find_color_in_window('#33CC66', 10);",
            keywords: ["窗口找色", "单窗口", "比色"]
        ),
        ScriptFunctionDoc(
            category: "找色",
            name: "click_color",
            pythonLikeSignature: "click_color(hex, rect=None, tolerance=12)",
            javaScriptSignature: "click_color(hex, rect=null, tolerance=12)",
            summary: "找到颜色后直接点击。",
            pythonLikeExample: "click_color('#33CC66', current_window_rect(), 10)",
            javaScriptExample: "click_color('#33CC66', current_window_rect(), 10);",
            keywords: ["找色点击", "直接调用", "颜色命中"]
        ),
        ScriptFunctionDoc(
            category: "颜色",
            name: "wait_color_relative",
            pythonLikeSignature: "wait_color_relative(x, y, hex, tolerance=8, timeout_ms=3000, interval_ms=120)",
            javaScriptSignature: "wait_color_relative(x, y, hex, tolerance=8, timeout_ms=3000, interval_ms=120)",
            summary: "基于当前锁定窗口的相对坐标等待颜色，更适合单窗口脚本。",
            pythonLikeExample: "if wait_color_relative(100, 80, '#33CC66', 10, 1500):\\n    click_relative(100, 80)",
            javaScriptExample: "if (wait_color_relative(100, 80, '#33CC66', 10, 1500)) {\\n  click_relative(100, 80);\\n}",
            pythonLikeSnippet: "if wait_color_relative(100, 80, '#33CC66', 10, 1500):\\n    click_relative(100, 80)",
            javaScriptSnippet: "if (wait_color_relative(100, 80, '#33CC66', 10, 1500)) {\\n  click_relative(100, 80);\\n}",
            keywords: ["窗口等待颜色", "相对比色", "单窗口"]
        ),
        ScriptFunctionDoc(
            category: "找图",
            name: "click_template_in_window",
            pythonLikeSignature: "click_template_in_window(template_name, threshold=0.94)",
            javaScriptSignature: "click_template_in_window(templateName, threshold=0.94)",
            summary: "只在当前锁定窗口内找模板并点击。",
            pythonLikeExample: "click_template_in_window('T1', 0.92)",
            javaScriptExample: "click_template_in_window('T1', 0.92);",
            keywords: ["窗口找图点击", "模板点击", "单窗口"]
        ),
        ScriptFunctionDoc(
            category: "找色",
            name: "click_color_in_window",
            pythonLikeSignature: "click_color_in_window(hex, tolerance=12)",
            javaScriptSignature: "click_color_in_window(hex, tolerance=12)",
            summary: "只在当前锁定窗口内找色并点击。",
            pythonLikeExample: "click_color_in_window('#33CC66', 10)",
            javaScriptExample: "click_color_in_window('#33CC66', 10);",
            keywords: ["窗口找色点击", "颜色点击", "单窗口"]
        ),
        ScriptFunctionDoc(
            category: "OCR",
            name: "ocr_window",
            pythonLikeSignature: "ocr_window()",
            javaScriptSignature: "ocr_window()",
            summary: "对当前锁定窗口做整窗 OCR。",
            pythonLikeExample: "text = ocr_window()\\nif text:\\n    log(text)",
            javaScriptExample: "const text = ocr_window();\\nif (text) {\\n  log(text);\\n}",
            pythonLikeSnippet: "text = ocr_window()",
            javaScriptSnippet: "const text = ocr_window();",
            keywords: ["整窗 OCR", "窗口识字", "文本识别"]
        ),
        ScriptFunctionDoc(
            category: "OCR",
            name: "ocr_text",
            pythonLikeSignature: "ocr_text(x, y, width, height)",
            javaScriptSignature: "ocr_text(x, y, width, height)",
            summary: "对指定区域做 OCR，返回文本。",
            pythonLikeExample: "text = ocr_text(0, 0, 320, 120)\nif text:\n    log('OCR =>', text)",
            javaScriptExample: "const text = ocr_text(0, 0, 320, 120);\nif (text) {\n  log('OCR =>', text);\n}",
            pythonLikeSnippet: "text = ocr_text(0, 0, 320, 120)",
            javaScriptSnippet: "const text = ocr_text(0, 0, 320, 120);",
            keywords: ["ocr", "文字识别", "文本", "识字"]
        ),
        ScriptFunctionDoc(
            category: "窗口",
            name: "window_bounds",
            pythonLikeSignature: "window_bounds(owner_name, title='')",
            javaScriptSignature: "window_bounds(ownerName, title = '')",
            summary: "按应用名和标题获取窗口位置，适合多开时精确定位指定窗口。",
            pythonLikeExample: "window_info = window_bounds('Notes')\nif window_info:\n    area = rect(window_info['x'], window_info['y'], window_info['width'], window_info['height'])",
            javaScriptExample: "const windowInfo = window_bounds('Notes');\nif (windowInfo) {\n  const area = rect(windowInfo.x, windowInfo.y, windowInfo.width, windowInfo.height);\n}",
            pythonLikeSnippet: "window_info = window_bounds('Notes')",
            javaScriptSnippet: "const windowInfo = window_bounds('Notes');",
            keywords: ["窗口", "句柄", "owner", "title", "bounds"]
        ),
        ScriptFunctionDoc(
            category: "辅助",
            name: "rect",
            pythonLikeSignature: "rect(x, y, width, height)",
            javaScriptSignature: "rect(x, y, width, height)",
            summary: "创建搜索区域对象，给找图、找色、窗口区域复用。",
            pythonLikeExample: "search_area = rect(0, 0, 800, 600)",
            javaScriptExample: "const searchArea = rect(0, 0, 800, 600);",
            keywords: ["区域", "矩形", "搜索区域", "bbox"]
        ),
        ScriptFunctionDoc(
            category: "辅助",
            name: "point",
            pythonLikeSignature: "point(x, y)",
            javaScriptSignature: "point(x, y)",
            summary: "创建点对象，便于组织坐标变量。",
            pythonLikeExample: "target_point = point(320, 240)",
            javaScriptExample: "const targetPoint = point(320, 240);",
            keywords: ["点位", "坐标", "point"]
        ),
        ScriptFunctionDoc(
            category: "辅助",
            name: "len",
            pythonLikeSignature: "len(value)",
            javaScriptSignature: "len(value)",
            summary: "读取数组或字符串长度，写 Python 脚本更顺手。",
            pythonLikeExample: "if len(text) > 0:\n    log('有文本')",
            javaScriptExample: "if (len(text) > 0) {\n  log('有文本');\n}",
            pythonLikeSnippet: "len(value)",
            javaScriptSnippet: "len(value);",
            keywords: ["长度", "数组", "字符串"]
        ),
        ScriptFunctionDoc(
            category: "示例",
            name: "窗口内找图点击示例",
            pythonLikeSignature: "example_window_template()",
            javaScriptSignature: "exampleWindowTemplate()",
            summary: "围绕当前锁定窗口做点击，非常贴近单窗口挂机脚本的写法。",
            pythonLikeExample: "def main():\n    area = current_window_rect()\n    if not area:\n        log('请先锁定窗口')\n        return\n\n    if wait_color(100, 100, '#FFCC00', 12, 2000):\n        match = find_image('T1', area, 0.92)\n        if match:\n            click(match['x'], match['y'])\n\nmain()",
            javaScriptExample: "function main() {\n  const area = current_window_rect();\n  if (!area) {\n    log('请先锁定窗口');\n    return;\n  }\n\n  if (wait_color(100, 100, '#FFCC00', 12, 2000)) {\n    const match = find_image('T1', area, 0.92);\n    if (match) {\n      click(match.x, match.y);\n    }\n  }\n}\n\nmain();",
            keywords: ["示例", "窗口内找图", "单窗口", "模板点击"]
        ),
        ScriptFunctionDoc(
            category: "示例",
            name: "轮询巡检示例",
            pythonLikeSignature: "example_loop()",
            javaScriptSignature: "exampleLoop()",
            summary: "循环检查颜色、OCR 和窗口状态，适合挂机、监控、办公自动化。",
            pythonLikeExample: "def main():\n    for i in range(0, 10):\n        if wait_color(120, 180, '#00FF00', 10, 500):\n            click_relative(120, 180)\n\n        text = ocr_text(0, 0, 220, 80)\n        if text:\n            log('OCR =>', text)\n\n        sleep_ms(300)\n\nmain()",
            javaScriptExample: "function main() {\n  for (let i = 0; i < 10; i += 1) {\n    if (wait_color(120, 180, '#00FF00', 10, 500)) {\n      click_relative(120, 180);\n    }\n\n    const text = ocr_text(0, 0, 220, 80);\n    if (text) {\n      log('OCR =>', text);\n    }\n\n    sleep_ms(300);\n  }\n}\n\nmain();",
            keywords: ["示例", "循环", "挂机", "巡检", "OCR"]
        )
    ]
}

private extension Array where Element == String {
    func appending(contentsOf newElements: [String]) -> [String] {
        self + newElements
    }
}
