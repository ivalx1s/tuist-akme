# AcmeApp

Multi-platform (iOS/macOS) приложение на базе [Tuist](https://tuist.io) с модульной архитектурой и composition-root паттерном.

## Быстрый старт

```bash
# Клонируем и генерим проект
git clone <repo-url>
cd tuist-akme
make
```

Всё. `make` сам:
1. Установит Homebrew (если нет)
2. Установит Tuist (если нет)
3. Спросит Team ID и Bundle Suffix (можно скипнуть)
4. Подтянет зависимости (`tuist install`)
5. Сгенерит и откроет Xcode workspace

## Структура проекта

```
├── Apps/                          # Хост-приложения
│   ├── iOSApp/                    # iOS приложение
│   │   └── Extensions/            # App extensions (виджеты и т.д.)
│   └── macOSApp/                  # macOS приложение
├── Modules/                       # Модули
│   ├── CompositionRoots/          # Точки сборки (wiring)
│   ├── Features/                  # Фичи
│   ├── Core/                      # Инфраструктура
│   ├── Shared/                    # Общие компоненты
│   └── Utility/                   # Утилиты
├── Tuist/                         # Project-specific Tuist helpers
├── TuistPlugins/ProjectInfraPlugin/  # Core DSL (ProjectFactory, Capability, etc.)
├── Scripts/                       # Python-скрипты автоматизации
├── Docs/                          # Документация (RFC)
├── .env.shared                    # Repo-tracked конфиг
└── .env                           # Локальный конфиг (gitignored)
```

## Команды

| Команда | Описание |
|---------|----------|
| `make` | Генерит workspace (дефолт) |
| `make bootstrap` | Полная инициализация с нуля |
| `make module layer=feature name=Auth` | Создать новый модуль |
| `make clean` | Почистить всё |
| `make check-graph` | Проверить архитектурные правила |

## Модули

Каждый feature-модуль состоит из 4 таргетов:

| Таргет | Назначение |
|--------|------------|
| `AuthInterface` | Протоколы, публичные типы. **Без внешних зависимостей!** |
| `Auth` | Реализация |
| `AuthTesting` | Моки, фейки для тестов других модулей |
| `AuthTests` | Unit-тесты |

### Создание модуля

```bash
make module layer=feature name=Payment
```

Создаст `Modules/Features/Payment/` со структурой:
```
Payment/
├── Project.swift
├── Interface/
├── Sources/
├── Testing/
└── Tests/
```

### Зависимости между модулями

```swift
// В Project.swift модуля
let project = ProjectFactory.makeFeature(
    module: .feature(.payment, scope: .common),
    dependencies: [
        .interface(.feature(.auth)),      // Зависимость на интерфейс
        .interface(.core(.networking)),   // Можно на core модули
        .external(dependency: .algorithms), // Внешние (из allow-list)
    ]
)
```

**Правила:**
- Interface-таргеты НЕ могут иметь внешних зависимостей
- Impl может зависеть только от Interface других модулей
- Внешние зависимости должны быть в allow-list (`Tuist/ProjectDescriptionHelpers/ExternalDependency.swift`)

## Composition Roots

Composition root — единственное место где можно напрямую линковать Impl-таргеты:

```swift
// Modules/CompositionRoots/AppCompositionRoot/Project.swift
let project = ProjectFactory.makeCompositionRoot(
    module: .app,
    dependencies: [
        .module(.feature(.auth)),    // Линкует Auth + AuthInterface
        .module(.feature(.payment)),
        .module(.core(.networking)),
    ]
)
```

Приложение зависит только от composition root:

```swift
// Apps/iOSApp/Project.swift
let project = ProjectFactory.makeHostApp(
    projectName: projectName,
    bundleId: AppIdentifiers.iOSApp.bundleId,
    compositionRoot: .app,  // ← вот тут
    ...
)
```

## Конфигурация

### Repo-tracked (`.env.shared`)

```bash
WORKSPACE_NAME=AcmeApp
CORE_ROOT=com.acme.akmeapp           # Корень для bundle ID
SHARED_ROOT=com.acme.akmeapp.shared  # Для cross-platform capabilities
IOS_APP_NAME=AcmeApp
IOS_MIN_VERSION=16.0
```

### Локальная (`.env`, gitignored)

```bash
DEVELOPMENT_TEAM_ID=XXXXXXXXXX       # Твой Apple Team ID
BUNDLE_ID_SUFFIX=.ivan               # Чтоб не конфликтовать с другими
```

Bundle suffix вставляется после `com.acme`:
- Было: `com.acme.akmeapp.app.ios`
- Стало: `com.acme.ivan.akmeapp.app.ios`

Это позволяет wildcard App ID `com.acme.*` матчить всех разработчиков.

## Capabilities (Entitlements)

DSL для описания capabilities в манифестах:

```swift
capabilities: [
    .appGroups(),                              // group.<bundleId>
    .keychainSharing(),                        // По умолчанию от host bundle ID
    .iCloudCloudKitContainer(container: .shared), // Шаринг iOS↔macOS
    .healthKit([.backgroundDelivery]),
    .associatedDomains(["applinks:example.com"]),
]
```

Уровни шаринга:
- `.default` — от host bundle ID (app + extensions)
- `.shared` — от `SHARED_ROOT` (iOS + macOS)
- `.custom(id:)` — явный идентификатор

## Внешние зависимости

Добавление новой зависимости:

1. Добавить в `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/...", from: "1.0.0"),
]
```

2. Добавить в allow-list (`Tuist/ProjectDescriptionHelpers/ExternalDependency.swift`):
```swift
public enum ExternalDependency: String, CaseIterable, Sendable, ExternalDependencyDescriptor {
    case myLib = "MyLib"

    public var allowedLayers: Set<ModuleLayer> {
        switch self {
        case .myLib: return [.feature, .core]  // Где можно использовать
        }
    }
}
```

3. Перегенерить: `make`

## Тестирование

```bash
# Запустить тесты модуля
xcodebuild -workspace AcmeApp.xcworkspace \
  -scheme Auth \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

Используем **Swift Testing** (не XCTest).

## Документация

- `Docs/RFC-0001-Identifiers.md` — Спецификация bundle ID и capability identifiers
- `CLAUDE.md` — Инструкции для AI-ассистентов

## Tools

| Тулза | Назначение | Установка |
|-------|------------|-----------|
| [Tuist](https://tuist.io) | Генерация Xcode проектов | `curl -Ls https://install.tuist.io \| bash` |
| Python 3 | Скрипты автоматизации | Встроен в macOS |
