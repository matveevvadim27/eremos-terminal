# Eremos Terminal

Нативное macOS-приложение для работы с Claude Code: слева список сессий, справа терминал выбранной.
Каждая сессия — своя папка, свой `zsh` и свой `claude`.

Swift + SwiftUI, macOS 14+, терминал — [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm).

## Запуск

Нужны Xcode и [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
make run        # собрать Release и запустить
make install    # собрать и положить в /Applications
make open       # открыть проект в Xcode (⌘R — запуск, ⌘U — тесты)
make test       # юнит-тесты
```

`EremosTerminal.xcodeproj` не хранится в git: его генерирует `make project` из `project.yml`.
Новые файлы добавляй в папки `EremosTerminal/…` — после `make project` они попадут в проект сами.

При первом открытии в Xcode он спросит, доверять ли плагину SwiftTerm («Trust & Enable») — да.
Из командной строки это делает флаг `-skipPackagePluginValidation` в Makefile.

## Как пользоваться

| | |
|---|---|
| ⌘T или «+» | новая сессия: выбрать папку → там откроется `zsh -l` и сразу `claude` |
| ⌘1…⌘9 | переключиться на сессию |
| ⌘W или контекстное меню | закрыть сессию: шелл и `claude` завершаются |
| ⇧⌘↩ | восстановленная сессия: `claude --continue` |
| перетащить папку на иконку в Dock | новая сессия в этой папке |

```bash
open -a "Eremos Terminal" ~/Projects/my-app   # то же из терминала
```

После выхода из `claude` остаёшься в обычном `zsh` в той же папке.

**Перезапуск приложения.** Список сессий хранится в
`~/Library/Application Support/Eremos Terminal/sessions.json`. При запуске для каждой сессии открывается шелл
в её папке, а `claude` сам не стартует: сверху баннер «Продолжить» (`claude --continue`) или «Новый claude».
Если папки больше нет, шелл откроется в домашней, и баннер об этом скажет.

**Шелл завершился** (`exit` или упал): точка в списке красная, история остаётся видна,
в баннере «Перезапустить» и «Закрыть сессию».

Закрытие окна не завершает сессии — окно вернётся по клику на иконку в Dock. Процессы завершаются
при закрытии сессии или выходе из приложения (⌘Q).

## Устройство

```
EremosTerminal/
├── App/
│   ├── EremosTerminalApp.swift   точка входа: окно, меню, создание SessionStore
│   ├── SessionCommands.swift     пункты меню и горячие клавиши
│   └── AppDelegate.swift         открытие папок через Dock / `open -a`
├── Models/
│   ├── Session.swift             данные сессии (id, name, folderPath) + статус процесса
│   └── SessionStore.swift        состояние приложения: список, выбор, живые терминалы
├── Persistence/
│   └── SessionPersistence.swift  sessions.json
├── Terminal/
│   ├── TerminalFactory.swift     создание терминала и запуск zsh, окружение (LANG для кириллицы)
│   ├── TerminalContainerView.swift  мост SwiftUI → AppKit-терминал
│   └── ProcessTree.swift         завершение шелла вместе со всеми дочерними процессами
├── Views/
│   ├── ContentView.swift         NavigationSplitView: сайдбар + деталь
│   ├── SidebarView.swift         список сессий
│   └── SessionDetailView.swift   баннер + терминал, пустое состояние
└── Resources/                    иконка (Assets.xcassets), дополнения к Info.plist
```

Параллели с React для неочевидных мест:

- **`SessionStore` — как стор Zustand/MobX.** `@Observable` сам отслеживает, какие свойства читает каждый view,
  и перерисовывает только их. В корне он создаётся один раз через `@State`, это аналог `useState(() => new Store())`.
  `@Bindable` во view даёт двустороннюю привязку `$store.selectedID`, как `value` + `onChange`.
- **Терминалы не в состоянии SwiftUI.** Это AppKit-объекты с живыми процессами. Они лежат в словаре
  `[UUID: LocalProcessTerminalView]` внутри стора (`@ObservationIgnored`, перерисовок не вызывает),
  создаются один раз и только переставляются. Отсюда мгновенное переключение и сохранность истории:
  ничего не размонтируется.
- **`TerminalContainerView` (`NSViewRepresentable`)** — как компонент с `useRef` на `<div>`, внутри которого
  рисует императивная библиотека. `makeNSView` — монтирование, `updateNSView` — каждый ререндер.
- **Делегат (`TerminalEvents`)** — способ AppKit передавать события: объект с методами вместо пропсов `onExit`.
- **`@MainActor`** — код, который должен выполняться в главном (UI) потоке; компилятор это проверяет.

## Известные ограничения

- **Новая сессия запускает `claude` в папке, которой он ещё не доверяет**: сначала спросит «Do you trust this folder».
  Это поведение Claude Code, не приложения.
- **Статусы Claude** (работает / ждёт ответа) пока не отслеживаются: точка показывает только жив ли шелл.
  Задел — `SessionStatus` в `Session.swift`; следующий этап — hooks Claude Code.
- **Нет переименования и перетаскивания сессий**, настроек шрифта и темы. Цвета следуют светлой/тёмной теме macOS.
- **⌘1…⌘9 только для первых девяти сессий**, как вкладки браузера.
- **Option работает как Meta** (настройка SwiftTerm по умолчанию): ⌥←/⌥→ двигают по словам в zsh,
  но символы, которые набираются через Option, в терминале не наберутся.
- **Подпись ad-hoc.** Приложение собрано без Apple Developer ID: на другом Mac Gatekeeper попросит
  разрешить запуск в «Настройках → Конфиденциальность и безопасность». На своём Mac из `make install` всё работает.
