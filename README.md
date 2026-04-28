# Perl Log Report

CLI-утилита на Perl для импорта логов в SQLite и генерации HTML-отчёта.

Проект демонстрирует:

- работу с Perl-модулями;
- парсинг текстовых логов регулярными выражениями;
- работу с SQL через DBI;
- batch insert и транзакции;
- защиту от повторной загрузки через hash строки;
- индексы в базе данных;
- обработку ошибок парсинга;
- генерацию HTML-отчёта через Template Toolkit;
- базовые тесты.

## Формат лога

```text
2026-04-28 12:30:15 INFO user_id=15 action=login status=success
2026-04-28 12:31:02 ERROR user_id=18 action=upload status=failed message="file too large"
```

## Структура проекта

```text
perl-log-report/
  bin/log_report.pl
  lib/LogParser.pm
  lib/ReportStorage.pm
  lib/HtmlReport.pm
  templates/report.html.tt
  data/sample.log
  t/parser.t
  cpanfile
  README.md
```

## Установка зависимостей

Через cpanm:

```bash
cpanm --installdeps .
```

Или вручную:

```bash
cpan DBI DBD::SQLite Template Digest::SHA Getopt::Long Test::More
```

## Запуск

Импорт логов в SQLite:

```bash
perl bin/log_report.pl import --input data/sample.log --db data/events.db
```

Вывод статистики в консоль:

```bash
perl bin/log_report.pl stats --db data/events.db
```

Генерация HTML-отчёта:

```bash
perl bin/log_report.pl report --db data/events.db --output reports/report.html
```

После этого откройте файл:

```bash
open reports/report.html
```

На Linux:

```bash
xdg-open reports/report.html
```

## Тесты

```bash
prove -l t
```

