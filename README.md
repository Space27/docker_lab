# Docker: докеризация приложения

* Дисциплина: Сети и Телекоммуникации
* Тема: Docker: докеризация приложения
* Группа: 2300
* Студент: Локосов Даниил

## Описание проекта

В качестве проекта, использующего базу данных, выбран [личный проект](https://github.com/Space27/JavaBackendSpring),
написанный на `Java` с использованием фреймворка `Spring`. Он представляет собою два сервиса: Telegram бот и сервис,
отслеживающий изменения по ссылкам. То есть bot зависит от scrapper, а scrapper независим.  
scrapper в качестве СУБД использует `PostgreSQL`.  
Сервисы общаются по HTTP, а также по `Kafka`, поэтому есть опциональная зависимость от `Kafka`. Также у сервисов
отслеживаются метрики, поэтому есть опциональная зависимость от `Prometheus` и `Grafana`.

## Подготовка сервисов к докеризации

Необходимо обернуть сервисы bot и scrapper в docker-образы таким образом, чтобы они начинали работу непосредственно при
старте контейнера и чтобы у них сохранилась возможность общаться как между собой, так и между БД, очередью сообщений.  
Для решения проблемы общения модифицированы конфигурационные файлы сервисов путём добавления нового профиля *docker*,
который изменяет хосты с `localhost` на `host.docker.internal`, который является тем же хостом, но доступным из
контейнера.  
Конфигурации сервисов наполнены переменными окружения для возможности настройки Telegram-токена бота, использования
очереди, режима retry, способа доступа к БД, а также параметры БД.

## Докеризация приложения

Для каждого из сервисов написан отдельный Dockerfile: [bot.Dockerfile](bot.Dockerfile)
и [scrapper.Dockerfile](scrapper.Dockerfile).

### Особенности Dockerfile'ов:

* Применена *multi-staged* сборка, применение которой позволило уменьшить размер образов с 300Мб до 150Мб. Она состоит из
  2-х этапов:
    * извлечение всех нужных файлов и зависимости через образ `eclipse-temurin:21-jdk-alpine`
    * копирование нужных для запуска файлов и запуск приложения через легковесный образ `alpine`
* Использование легковесного `alpine` образа в качестве основного
* Работа в контейнере ведется от непривилегированного пользователя, что увеличивает безопасность
* Образы объявляют значения переменных окружения по умолчанию
* Объявлены порты, на которых работают образы
* Образ `scrapper` дополнительно несет файлы миграции и конфигурации `Prometheus` для возможности скачки данных файлов, имея
  только образ

### Сборка приложения

Для сборки применен `docker compose`, который можно кратко описать следующим образом:

* `bot` зависит от `scrapper`
* `scrapper` зависит от БД и миграций
* миграции зависят от БД, поэтому перезапускаются до успеха (`restart: on-failure`), поскольку они могут начаться до
  полного запуска БД
* files выгружает файлы, необходимые для запуска миграций и отслеживания метрик

Таким образом, для полного запуска приложения необходим лишь один [compose.yml](compose.yml) файл.  
Также стоит отметить, что для миграции БД используется система `liquibase`, которая позволяет запуск внутри `Spring`, но
это является плохой практикой, поэтому миграции вынесены отдельно от самого приложения, но запускаются автоматически при
корректном запуске compose-файла через docker-образ liquibase.

### Выкатка образов

Для публикации образов в `Github Packages` для возможности установки собранных образов прописан `Github Workflow`,
который позволил автоматически собирать образы при запуске `Build` приложений.  
Опубликованные образы см. [здесь](https://github.com/Space27?tab=packages&repo_name=JavaBackendSpring).

## Запуск приложения

Полное описание
см. [здесь](https://github.com/Space27/JavaBackendSpring/tree/master#%D0%B7%D0%B0%D0%BF%D1%83%D1%81%D0%BA-%D0%BF%D1%80%D0%BE%D0%B5%D0%BA%D1%82%D0%B0)

1. Установить [compose.yml](compose.yml)
2. `docker compose run -d --rm files` для установки файлов миграций
3. `docker compose up -d scrapper` для запуска scrapper с миграциями и БД. Если есть telegram-token для проверки, то
   можно ввести его для переменных окружения bot и запустить `docker compose up -d bot`
4. Для проверки работоспособности перейти на [localhost:8080/swagger-ui](http://localhost:8080/swagger-ui/index.html)
5. Завершить приложение `docker compose down`

## Приложение

* Dockerfile's:
    * [bot.Dockerfile](bot.Dockerfile)
    * [scrapper.Dockerfile](scrapper.Dockerfile)
* [compose.yml](compose.yml)
* [Исходники проекта](https://github.com/Space27/JavaBackendSpring)
