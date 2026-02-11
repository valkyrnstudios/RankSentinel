local addonName, _ = ...
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "ruRU")
if not L then return end
-- Translator ZamestoTV
L[addonName] = "Rank Sentinel"
L["Enable"] = _G.ENABLE
L["Whisper"] = _G.WHISPER
L["Debug"] = _G.BINDING_HEADER_DEBUG

L["Notification"] = {
    ["random"] = false,
    ["default"] = {
        ["Prefix"] = {
            ["Self"]    = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7.blp:0|t',
            ["Whisper"] = fmt("{rt7} %s: Обнаружено", addonName)
        },
        ["Base"]   = "%s (%d ранг) использован%s, доступен новый ранг на %d уровне.",
        ["Suffix"] = "Возможно, панели заклинаний устарели.",
        ["By"]     = " игроком %s"
    },
    ["troll"] = {
        ["Prefix"] = {
            ["Self"]    = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8.blp:0|t',
            ["Whisper"] = fmt("{rt8} %s: Эй, приятель,", addonName)
        },
        ["Base"]   = "%s (%d ранг) юзаешь%s, новый на %d лвле, чувак.",
        ["Suffix"] = "Ты чё, пропустил тренировку или макрос запылился?",
        ["By"]     = " у %s"
    },
    ["gogowatch"] = {
        ["Prefix"] = {
            ["Self"]    = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7.blp:0|t Ты',
            ["Whisper"] = fmt("{rt7} %s: Дружеское напоминание! Ты", addonName)
        },
        ["Base"]   = " только что использовал низкий ранг %s (%d ранг)%s.",
        ["Suffix"] = "Проверь свои панели действий или сходи к классовому тренеру — пора обновить способность под свой уровень.",
        ["By"]     = " (цель: %s)"
    },
    ["ogre"] = {
        ["Prefix"] = {
            ["Self"]    = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8.blp:0|t МОЯ ВИДЕТЬ',
            ["Whisper"] = "{rt8} МОЯ ВИДЕТЬ"
        },
        ["Base"]   = "мелкий %s %d сила%s бум, учи сильный бум %d.",
        ["Suffix"] = "БОЛЬШОЙ БУМ!",
        ["By"]     = " от %s"
    },
    ["murloc"] = {
        ["Prefix"] = {
            ["Self"]    = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4.blp:0|t',
            ["Whisper"] = "{rt4} Мммррргллл,"
        },
        ["Base"]   = "нк мррргк %s %d%s урка %d.",
        ["Suffix"] = "Ммм мррргк!",
        ["By"]     = " ммгр %s"
    },
    ["pirate"] = {
        ["Prefix"] = {
            ["Self"]    = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2.blp:0|t',
            ["Whisper"] = "{rt2} Полундра!"
        },
        ["Base"]   = "%s (%d ранг) в деле%s, но на %d уровне сокровища побогаче!",
        ["Suffix"] = "Загляни к мастеру дока за новой красоткой!",
        ["By"]     = " от %s"
    }
}

L["Cache"] = {
    ["Reset"] = "Кэш сброшен: удалено %d записей, забыто %d макс. рангов",
    ["Queue"] = "В очереди: %s, %s"
}

L["Broadcast"] = {
    ["Unrecognized"] = "Неизвестный пакет данных (%s). У тебя или у %s устаревшая версия аддона."
}

L["Cluster"] = {
    ["Lead"]  = "Лидер кластера: %s",
    ["Sync"]  = "Синхронизация данных: %d",
    ["Batch"] = "Синхронизация пакета %d из %d"
}

L["Utilities"] = {
    ["Upgrade"] = "Версия изменена, сброс кэша...",
    ["IgnorePlayer"] = {
        ["Error"]   = "Нужно выбрать цель",
        ["Ignored"]   = "%s добавлен в список игнорирования",
        ["Unignored"] = "%s удален из списка игнорирования"
    },
    ["Outdated"]   = "Версия устарела, функции отключены",
    ["NewVersion"] = "Доступна новая версия! Обновитесь, чтобы включить аддон"
}

L["ChatCommand"] = {
    ["Reset"] = "Настройки сброшены",
    ["Count"] = {
        ["Spells"] = "Отслежено заклинаний: %d",
        ["Ranks"]  = "Сохранено рангов: %d"
    },
    ["Ignore"] = {
        ["Target"] = "Выберите цель, чтобы игнорировать её",
        ["Count"]  = "В игнор-листе: %d чел."
    },
    ["Queue"] = {
        ["Clear"]  = "Очищено уведомлений: %d",
        ["Count"]  = "В очереди сейчас: %d"
    },
    ["Report"] = {
        ["Header"]     = "%sЗа сессию выявлено %d случаев низкого ранга",
        ["Summary"]    = "%s — %s (%d ранг)",
        ["Unsupported"] = "Канал %s не поддерживается"
    },
    ["Flavor"] = {
        ["Set"]        = "Выбран стиль уведомлений: %s",
        ["Available"]  = "Доступные стили:",
        ["Unavailable"] = "Стиль %s больше недоступен, возврат к стандартному"
    }
}

L["Help"] = {
    ["title"]    = "Команды управления",
    ["advanced"] = "Расширенные команды",
    ["enable"]   = "Вкл/выкл сканирование лога боя",
    ["whisper"]  = "Вкл/выкл отправку ЛС игрокам",
    ["reset"]    = "Сброс настроек профиля",
    ["count"]    = "Показать текущую статистику",
    ["debug"]    = "Вкл/выкл режим отладки",
    ["clear"]    = "Очистить локальный кэш способностей",
    ["lead"]     = "Назначить себя лидером группы (в аддоне)",
    ["ignore"]   = "Игнорировать цель: ей не будут приходить уведомления",
    ["queue"]    = "Показать очередь уведомлений",
    ["queue clear"]   = "Очистить очередь уведомлений",
    ["queue process"] = "Принудительно отправить очередь",
    ["sync"]     = "Разослать кэш анонсов союзникам",
    ["report [channel]"] = "Отчёт за сессию в канал [self, say, party, raid, guild]",
    ["flavor"]   = "Список стилей уведомлений",
    ["flavor [option]"] = "Установить выбранный стиль"
}
