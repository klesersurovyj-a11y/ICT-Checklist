# ICT Checklist — iOS

Чек-лист ICT-цикла, журнал сделок, Risk Ladder, статистика и календарь.
SwiftUI, iOS 17+, SwiftData, без сторонних зависимостей.

## IPA

Файл `ICT-Checklist.ipa` собирается автоматически на GitHub Actions при каждом
пуше в `main` и лежит в разделе **Releases** под тегом `ipa-latest`:

- https://github.com/klesersurovyj-a11y/ICT-Checklist-v2/releases/tag/ipa-latest

Рядом — `ICT-Checklist.ipa.sha256`. Сборка **неподписанная**: перед установкой
на iPhone её нужно подписать своим Apple ID, например через Sideloadly или
AltStore (бесплатный Apple ID подойдёт), либо собрать и запустить проект
из Xcode на Mac. Без подписи iOS файл не установит.

Пересобрать вручную: вкладка **Actions** → **Build IPA** → **Run workflow**.

## Сборка

Откройте `ICT Checklist.xcodeproj` в Xcode, выберите схему `ICT Checklist` и
запустите на симуляторе или устройстве.

Что нужно для полной работы на устройстве:

- **Хранение** — база лежит только на этом устройстве: облака и синхронизации нет.
  Резервную копию можно выгрузить в JSON из настроек.
- **Виджеты** — расширение `ICT ChecklistWidgetExtension` ставится вместе с
  приложением.
