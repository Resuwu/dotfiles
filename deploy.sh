#!/usr/bin/env bash

# Остановка при ошибках
set -e

# Цвета для вывода в консоль
INFO="\033[1;34m[ИНФО]\033[0m"
SUCCESS="\033[1;32m[УСПЕХ]\033[0m"
WARN="\033[1;33m[ВНИМАНИЕ]\033[0m"

echo -e "${INFO} Начинаем развертывание конфигураций (Dotfiles)..."

# Определяем абсолютный путь к папке, где лежит этот скрипт (ваш репозиторий)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo -e "${INFO} Директория репозитория: ${DOTFILES_DIR}"

# ------------------------------------------------------------------------------
# 1. НАСТРОЙКА GIT (ИМЯ, ПОЧТА, АЛИАСЫ И ПАРАМЕТРЫ)
# ------------------------------------------------------------------------------
echo -e "\n--- Настройка профиля Git ---"

# Проверяем, заданы ли уже имя и почта
CURRENT_NAME=$(git config --global user.name || echo "")
CURRENT_EMAIL=$(git config --global user.email || echo "")

if [ -n "$CURRENT_NAME" ] && [ -n "$CURRENT_EMAIL" ]; then
    echo -e "${INFO} В Git уже настроены данные: ${CURRENT_NAME} <${CURRENT_EMAIL}>"
    read -p "Хотите изменить их? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        CHANGE_GIT=true
    else
        CHANGE_GIT=false
    fi
else
    CHANGE_GIT=true
fi

if [ "$CHANGE_GIT" = true ]; then
    read -p "Введите ваше имя для Git (например, Ivan Ivanov): " GIT_NAME
    read -p "Введите вашу почту для Git (например, ivan@example.com): " GIT_EMAIL
    
    if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
        git config --global user.name "$GIT_NAME"
        git config --global user.email "$GIT_EMAIL"
        echo -e "${SUCCESS} Git успешно настроен на: $(git config --global user.name) <$(git config --global user.email)>"
    else
        echo -e "${WARN} Имя или почта не были введены. Пропускаем настройку профиля Git."
    fi
fi

# Настроим базовые параметры и шорткаты (алиасы)
echo -e "${INFO} Применение глобальных параметров и алиасов Git..."
git config --global init.defaultBranch main
git config --global core.autocrlf input
git config --global pull.rebase true

# Установка алиасов
git config --global alias.st "status -sb"
git config --global alias.co "checkout"
git config --global alias.br "branch"
git config --global alias.lg "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)'"

echo -e "${SUCCESS} Параметры и алиасы (st, co, br, lg) успешно добавлены в .gitconfig!"

# ------------------------------------------------------------------------------
# 2. СОЗДАНИЕ РЕЗЕРВНОЙ КОПИИ СТАРИХ КОНФИГОВ
# ------------------------------------------------------------------------------
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
echo -e "\n--- Подготовка файловой системы ---"

# Функция для создания бэкапа и символической ссылки
# Использование: link_file <источник_в_репо> <целевой_путь_в_системе>
link_file() {
    local src="$DOTFILES_DIR/$1"
    local dest="$HOME/$2"
    local dest_dir
    dest_dir="$(dirname "$dest")"

    # Создаем целевую директорию, если её нет (например, ~/.config/fish)
    mkdir -p "$dest_dir"

    # Если по целевому пути уже есть файл или директория (и это не наша ссылка) — бэкапим
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        echo -e "${WARN} Найдена существующая конфигурация: $dest"
        mkdir -p "$BACKUP_DIR/$(dirname "$2")"
        mv "$dest" "$BACKUP_DIR/$2"
        echo -e "${INFO} -> Перенесено в резервную копию: $BACKUP_DIR/$2"
    # Если это старая ссылка — просто удаляем её
    elif [ -L "$dest" ]; then
        rm "$dest"
    fi

    # Создаем символическую ссылку
    if [ -e "$src" ]; then
        ln -sf "$src" "$dest"
        echo -e "${SUCCESS} Ссылка создана: $dest -> $src"
    else
        echo -e "${WARN} Файл в репозитории не найден, пропускаем: $src"
    fi
}

# ------------------------------------------------------------------------------
# 3. РАЗВЕРТЫВАНИЕ (СОЗДАНИЕ СИМЛИНКОВ)
# ------------------------------------------------------------------------------
echo -e "\n--- Линковка конфигурационных файлов ---"

# Синтаксис: link_file "путь_от_корня_репо" "путь_от_домашней_папки"

# Оболочка и CLI утилиты
link_file "config/fish/config.fish"  ".config/fish/config.fish"
link_file "config/bat/config"        ".config/bat/config"

# Настройки терминала Kitty
link_file "config/kitty/kitty.conf" ".config/kitty/kitty.conf"

# Графический редактор VS Code
link_file "config/Code/User/settings.json" ".config/Code/User/settings.json"

# Java/Kotlin инструмент сборки
link_file "gradle/gradle.properties" ".gradle/gradle.properties"

# ------------------------------------------------------------------------------
# 4. ЗАВЕРШЕНИЕ
# ------------------------------------------------------------------------------
echo -e "\n------------------------------------------------------------------------"
echo -e "${SUCCESS} Развертывание Dotfiles успешно завершено!"
if [ -d "$BACKUP_DIR" ]; then
    echo -e "${INFO} Старые файлы настроек были сохранены в директорию:"
    echo -e "  $BACKUP_DIR"
fi
echo -e "------------------------------------------------------------------------"