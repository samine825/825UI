# Шесть новых приложений в каноническом дизайне 825UI

## Контекст

В шеле есть дизайн-система (SPanel/SFrame/STile/SText/VIcon/Glyphs/Infex-цифры, токены Settings, инверсия заливкой) и канонические паттерны приложений (панель = полноэкранный прозрачный PanelWindow + Exclusive-фокус + клик-вне-закрывает; контент в MouseFollow-контейнере с хедером-баром и SPanel; табы как в SettingsMenu; списки-карточки как история уведомлений; персист через FileView+JsonAdapter; звука/камеры/буфера в проекте нет). Проверено на системе: **QtMultimedia установлен, вебкамера есть** (/dev/video0,1), **NotoColorEmoji есть**, wl-clipboard (wl-copy/wl-paste) и pw-play/paplay есть. Пользователь выбрал: запуск через 825ctl + плитки в ControlPanel; камера и диктофон — полные через QtMultimedia; буфер — текст+изображения, persist, последние 100 + закреплённые; звук — бипы + баннер со Стоп/Отложить.

## Общие решения

- **Регистрация**: каждый новый экран — PanelWindow по образцу ControlPanel.qml (full-screen transparent, `WlrKeyboardFocus.Exclusive`, `exclusiveZone: -1`, `visible: false`, `show()/hide()`, фоновая MouseArea «клик мимо — hide», Esc закрывает). Все входят в `showOnly()` (взаимное исключение) и получают `toggle<Name>()` в IpcHandler «main» + ветку в `main.cpp` `toggle_app`: `clipboard | calculator | emoji | clock | camera | recorder`, help обновить.
- **Каркас панели** (общий для всех): MouseFollow-контейнер (у каждого свой размер), хедер-бар `SFrame` + заголовок (как dateBar в ControlPanel), контентная `SPanel` `shadow: "outside"`. Размеры: калькулятор ~440×700, эмодзи ~720×640, буфер ~720×640, часы ~720×560, камера ~640×580, диктофон ~560×500. Всё в токенах Settings (line, barHeight, textXs..textLg, anim*).
- **Новые иконки в Glyphs.qml** (24×24, рукописные stroke-пути в стиле iconBluetooth/iconMic): iconClipboard, iconCalculator, iconEmoji, iconClock, iconCamera, iconPin, iconTrash, iconPlus, iconStop, iconRecord, iconStopwatch, iconTimer, iconBackspace, iconCheck.
- **Персист**: `~/.825UI/state/` — `clipboard.json` + папка `clipboard/` для картинок-блобов, `alarms.json`, `emoji.json` (recents). Паттерн — Settings.qml (FileView+JsonAdapter). В тестах HOME подменяется песочницей.
- **Звук**: сгенерированные WAV в `QS/Sounds/` (timer-beep ~0.6с, alarm-loop ~2с двойной бип), проигрывание SoundEffect (QtMultimedia), зацикливание баннером через Timer до «Стоп» (максимум 60с → авто-стоп).
- **Баннер будильника/таймера** `QS/AlarmBanner.qml`: всегда живой прозрачный PanelWindow (Overlay, пустая mask в покое — паттерн LockScreen), визуал попапа: контур NotifContour (padX = 0.5·tipMult·line, кончики на height/2), двойная обводка c2(3line)+c1(1line), приезд — каноническая тройка: y OutCubic 600 + rotation 180 OutSine 600 + контент InCubic 1500. Кнопки STile: Стоп / Отложить 5 мин (только у будильника). Очередь сообщений (будильник не глушит таймер — показ по очереди).
- **Плитки в ControlPanel**: один ряд из 6 STile (буфер, калькулятор, эмодзи, часы, камера, диктофон) в сетке виджетов; высота контейнера растёт на клетку+зазор; `onActivated: shell.showOnly("<app>")`.

## Приложения

### 1. Калькулятор (Calculator.qml + Calc.js)
- `Calc.js` — чистый JS без eval: токенизатор + shunting-yard (приоритет ×÷ перед +−, унарный минус, скобки, проценты-постфикс, decimals). Экспортирует tokenize/evaluate/validate — покрывается юнит-тестами.
- UI: строка выражения (малый текст, скролл к концу) + строка результата (textLg, появляется живым предпросчётом), кнопки SPanel-тайлами 4×5: [C, ⌫(VIcon), %, ÷] [7 8 9 ×] [4 5 6 −] [1 2 3 +] [±, 0, ., =]. Активное нажатие — краткая заливка c1 (state Pressed → animFast). Клавиатура: цифры/операторы/Enter/Backspace/Esc.
- Ошибки (деление на 0, мусор) — выражение трясётся (паттерн shake из LockScreen) и не заменяется.

### 2. Эмодзи (EmojiPicker.qml + EmojiData.js)
- `EmojiData.js`: ~700–800 эмодзи, 9 категорий (Смайлы, Жесты, Люди, Животные, Еда, Активность, Путешествия, Объекты, Символы), каждая запись {ch, name, keywords[]} на английском.
- UI: строка поиска (канонический TextInput из LockScreen: c1 текст, cursorDelegate Item{}, clip) + таб-бар категорий (канонический таб из SettingsMenu: гранёный контур, активный индикатор c1 с анимацией x, WheelHandler листает категории) + сетка эмодзи (Flickable+Flow, плитка подсвечивается заливкой c1 на ховере). Клик → `wl-copy <эмодзи>` (Process) → панель закрывается. Recents: первые 24 в первой категории «Частые», персист в emoji.json.
- Отсутствие результатов — «empty state» текстом по центру.

### 3. Часы (ClockApp.qml + TimeMath.js)
- Табы каноническим таб-баром: Clock | Alarm | Stopwatch | Timer + WheelHandler.
- **Clock**: большие Infex-цифры HH:mm + :ss меньшего размера (как в баре, seconds всегда), дата снизу (Process `date '+%A, %d %B'` — паттерн ControlPanel).
- **Alarm**: список карточек (паттерн истории уведомлений: SPanel-карточка, появление ростом из нуля animBase, удаление схлопыванием, ✕ VIcon); создание/редакт: время (числовые поля-тайлеры со стрелками), подпись, дни недели (7 мини-тайлов Пн..Вс), вкл/выкл переключателем-тайлом; всё в alarms.json. Проверка каждую секунду (Timer): срабатывание → баннер + зацикленный alarm-beep до «Стоп»; «Отложить» = +5 мин. Повтор по дням — TimeMath.nextOccurrence (чистая функция, покрыта тестами).
- **Stopwatch**: Infex mm:ss:cc (центыесекунды — Infex поддерживает цифры и ":"), кнопки STile Пуск/Пауза/Сброс + круги (список карточек: номер, круг, общее).
- **Timer**: большие Infex mm:ss + полоса прогресса с канонической инверсией (как SystemStats) под цифрами; пресеты-тайлы 1/3/5/10/15/30 мин + тайлер минут; Пуск/Пауза/Сброс; конец → баннер (Стоп) + тройной timer-beep.

### 4. Буфер обмена (ClipboardPanel.qml)
- **Мониторинг**: Timer 1.5с → Process `wl-paste --list-types` (паттерн SystemStats: Process+Timer+StdioCollector, re-arm guard). Новый контент: текст → `wl-paste` (до ~100КБ, больше — обрезка с меткой), image/png|jpeg → `wl-paste -t <тип> > файл` в state/clipboard/. Дедуп: подряд идущие одинаковые не добавляются, повторное копирование старого поднимает его наверх.
- **UI**: строка поиска + секция «Закреплённые» (если есть) + список карточек (канонический паттерн): текст — до 2 строк ellipsis, картинка — миниатюра с размером; время; кнопки: булавка (pin/unpin), ✕ (удалить, вместе с блобом). Клик по карточке → `wl-copy` текста или `wl-copy -t image/png < файл` → карточка подсвечивается как текущая. «Clear all» в шапке (канон, очищает незакреплённые). Закреплённые не вытесняются; лимит 100 на незакреплённые (вытеснение снизу, блобы удаляются).
- Хедер-«кнопка добавить» не нужна: всё ловится автоматически.

### 5. Камера (CameraApp.qml)
- QtMultimedia: `CaptureSession { camera: Camera { cameraDevice: из MediaDevices.videoInputs }, videoOutput }` + превью VideoOutput в SPanel (fillInset-рамка), выбор устройства если >1 (кнопка-тайл с переключением).
- Фото: `ImageCapture.captureToFile()` → `~/Pictures/825UI/Photo_YYYYMMDD_HHMMSS.jpg`; видео: `MediaRecorder` (webm) → `~/Pictures/825UI/Video_*.webm`, таймер длительности, кнопка Стоп. Миниатюра последнего снимка + счётчик файлов. Если камеры нет / занята — empty-state текстом (проверяется в Xvfb).
- Отмена выбора: панель закрыта → camera.active = false (греет батарею только в открытом виде).

### 6. Диктофон (RecorderApp.qml)
- `CaptureSession { AudioInput, MediaRecorder }` → `~/Pictures/825UI/Rec_*.m4a` (если кодек недоступен в gstreamer — проверю тестом и откачусь на `pw-record` (Process) → wav, оба пути зашиты с автодетектом).
- UI: большая кнопка-тайл записи (iconRecord, пульсирующее кольцо во время записи — анимированный stroke, не VU-метр), таймер длительности (Infex mm:ss), список записей (карточки: имя, длительность, дата): воспроизведение (MediaPlayer с честной полосой-инверсией; fallback pw-play), пауза, ✕ удалить (файл + запись).

## Тесты (обязательный этап на каждое приложение)

1. **check.sh** после каждого файла — конфиг грузится, ноль ERROR.
2. **apptests.sh** (новый, в корне): временный shell.qml-пробник (как visualtest.sh) в Xvfb с `HOME=/tmp/825testhome` (изоляция состояния), запускает чистые JS-модули и печатает строки `TEST OK/FAIL`: ~30 кейсов Calc.js (приоритеты, скобки, унарный минус, проценты, ошибки), кейсы TimeMath.js (будильник на «завтра», день недели, отложенное), поиск эмодзи, jq-free парсинг — grep считает FAIL.
3. **visualtest-пробники на каждый экран**: инстанс панели + show() + grabToImage → PNG, читаю глазами: калькулятор (пустой/с выражением/результат/ошибка), эмодзи (категории/поиск/пустой результат), часы (все 4 таба/баннер), буфер (засеянный json: текст+картинки+закреплённые/поиск/пустой), камера/диктофон (graceful-состояния). Баннер: отдельный пробник с принудительным показом.
4. **IPC end-to-end**: в Xvfb поднимаю репозиторный конфиг (`qs -p <repo>/QS` — путь ≠ установленного ~/.825UI, живая сессия не задевается) и дёргаю `qs -p <repo>/QS ipc call main toggleCalculator` и т.д. — панели открываются/закрываются, showOnly-эксклюзивность работает. 825ctl не трогаю вживую (только сборка + `825ctl help/status` без вызова тоглов).
5. Коммиты: по одному на приложение + общий (интеграция/иконки/ControlPanel/main.cpp), формат сообщений как прежде.

## Файлы

**Новые**: QS/Apps/{Calculator.qml, Calc.js, EmojiPicker.qml, EmojiData.js, ClockApp.qml, TimeMath.js, ClipboardPanel.qml, CameraApp.qml, RecorderApp.qml}, QS/AlarmBanner.qml, QS/Sounds/{alarm-beep.wav, timer-beep.wav}, apptests.sh, paneltest.sh.
**Меняются**: QS/Components/Glyphs.qml (+14 иконок), QS/shell.qml (инстансы, showOnly, IpcHandler, баннер), QS/Apps/ControlPanel.qml (ряд плиток + высота), main.cpp (toggle_app + help), install.sh не меняется (подхватит всё сам).

## Ограничения

- Консольная работа: install.sh ставишь сам; IPC с реальными эффектами — только против репозиторного инстанса в Xvfb, живую сессию не трогаю.
- Кнопки/тексты приложений — на английском (консистентно с Notifications/System/Bar табами).
- Камера/диктофон в Xvfb проверяются на graceful-деградацию и логику; финальную картинку с железом подтверждаешь ты после install.sh.