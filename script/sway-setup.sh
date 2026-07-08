#!/usr/bin/env bash

# Включаем строгий режим: остановка при любой ошибке
set -e

REPO_URL="https://github.com/Resuwu/sway-dotfiles.git"
CLONE_DIR="$HOME/.local/share/sway-dotfiles"
BACKUP_DIR="$HOME/.config/config-backup-$(date +'%Y%m%d_%H%M%S')"

echo "======================================================="
echo "  Установка сетапа Sway (Resuwu)"
echo "======================================================="

# 1. Проверка прав пользователя
if [ "$(id -u)" = "0" ]; then
    echo "❌ Ошибка: Не запускайте скрипт от имени root (через sudo)."
    echo "Скрипт сам запросит пароль, когда это потребуется пакетному менеджеру."
    exit 1
fi

# 2. Проверка наличия AUR-хелпера (yay или paru)
echo "🔍 Проверка AUR-хелпера..."
if command -v yay &> /dev/null; then
    AUR_HELPER="yay"
elif command -v paru &> /dev/null; then
    AUR_HELPER="paru"
else
    echo "⚠️ Не найден yay или paru. Устанавливаем yay..."
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm
    cd -
    AUR_HELPER="yay"
fi

# 3. Точный список пакетов (включая PipeWire, Firefox и компоненты сетапа)
echo "📦 Установка компонентов сетапа..."
PACKAGES=(
    # Основной Wayland/Sway стек
    sway
    waybar
    swaybg
    rofi-wayland          # Wayland-версия rofi (критично для Sway)
    swaylock-effects-git  # Эффекты размытия для экрана блокировки (sway-effects)
    mako                  # Демон уведомлений
    
    # Терминал, браузер и темы
    kitty
    firefox               # Браузер для применения темы
    qt5-styleplugins      # qtstyleplugins для применения тем к Qt-приложениям
    
    # Аудио и музыка (PipeWire)
    pipewire
    pipewire-pulse
    pipewire-alsa
    wireplumber           # Важно: управляет аудио-сессиями и нужен для Waybar
    
    # Системные утилиты и апплеты
    light                 # Управление яркостью
    network-manager-applet# nm-applet (иконка сети в трее)
    sway-contrib          # Пакет, содержащий утилиту grimshot для скриншотов
    wl-clipboard          # Буфер обмена Wayland
    imv                   # Нативный Wayland просмотрщик изображений
    
    # Шрифты для корректного отображения иконок и смайлов
    ttf-jetbrains-mono-nerd
    ttf-nerd-fonts-symbols-mono
    noto-fonts
    noto-fonts-cjk
    ttf-twemoji
)

echo "Запускаем установку через $AUR_HELPER..."
$AUR_HELPER -S --needed --noconfirm "${PACKAGES[@]}"

# 4. Настройка прав для утилиты light (управление яркостью без sudo)
echo "☀️ Добавление пользователя $USER в группу video для работы light..."
sudo usermod -aG video "$USER" || true

# 5. Создание резервных копий текущих конфигов
echo "📁 Создание бэкапа ваших текущих конфигураций в $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"

CONFIG_DIRS=("sway" "waybar" "rofi" "mako" "kitty" "mpd" "ncmpcpp")

for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "$HOME/.config/$dir" ]; then
        echo "  -> Бэкап ~/.config/$dir..."
        mv "$HOME/.config/$dir" "$BACKUP_DIR/$dir"
    fi
done

# 6. Клонирование репозитория
echo "🌐 Клонирование репозитория с дотфайлами..."
if [ -d "$CLONE_DIR" ]; then
    echo "  -> Обновление существующего репозитория в $CLONE_DIR..."
    cd "$CLONE_DIR" && git pull
else
    git clone "$REPO_URL" "$CLONE_DIR"
fi

# 7. Установка конфигурационных файлов в ~/.config
echo "⚙️ Копирование новых конфигураций в ~/.config..."
mkdir -p "$HOME/.config"

if [ -d "$CLONE_DIR/.config" ]; then
    cp -r "$CLONE_DIR/.config/." "$HOME/.config/"
else
    find "$CLONE_DIR" -mindepth 1 -maxdepth 1 ! -name ".git" ! -name "README.md" ! -name "LICENSE" ! -name ".themes" -exec cp -r {} "$HOME/.config/" \;
fi

# 8. Установка GTK-тем в домашнюю директорию (~/.themes)
echo "🎨 Установка GTK-тем оформления..."
if [ -d "$CLONE_DIR/.themes" ]; then
    if [ -d "$HOME/.themes" ]; then
        echo "  -> Бэкап существующей папки ~/.themes..."
        mv "$HOME/.themes" "$BACKUP_DIR/.themes"
    fi
    cp -r "$CLONE_DIR/.themes" "$HOME/"
    echo "  -> Темы оформления успешно скопированы в ~/.themes!"
else
    echo "⚠️ Папка .themes не найдена в репозитории. Пропускаем..."
fi

# 9. Установка темы и автоматическая настройка about:config для Firefox
echo "🦊 Установка темы Catppuccin и настройка Firefox..."
if [ -d "$CLONE_DIR/chrome.catppuccin" ]; then
    # Если Firefox еще ни разу не запускался, создаем профиль в фоновом режиме
    if [ ! -d "$HOME/.mozilla/firefox" ]; then
        echo "  -> Firefox еще не запускался. Создаем профиль по умолчанию..."
        firefox --headless > /dev/null 2>&1 &
        FF_PID=$!
        sleep 3
        kill -9 $FF_PID 2>/dev/null || true
    fi

    # Находим профиль (берем первый попавшийся *.default-release или *.default)
    FF_PROFILE=$(find "$HOME/.mozilla/firefox" -maxdepth 1 -type d \( -name "*.default-release" -o -name "*.default" \) | head -n 1)

    if [ -n "$FF_PROFILE" ]; then
        echo "  -> Найден профиль: $FF_PROFILE"
        
        # Бэкап старой папки chrome, если она была
        if [ -d "$FF_PROFILE/chrome" ]; then
            echo "  -> Бэкап старой темы Firefox..."
            mv "$FF_PROFILE/chrome" "$BACKUP_DIR/firefox-chrome-backup"
        fi

        # Копируем новую тему
        cp -r "$CLONE_DIR/chrome.catppuccin" "$FF_PROFILE/chrome"
        echo "  -> Папка chrome успешно установлена!"

        # Автоматическая настройка user.js для включения CSS
        FF_USER_JS="$FF_PROFILE/user.js"
        echo "  -> Включение поддержки кастомных тем в user.js..."
        
        # Удаляем старую запись об этом параметре, если она уже была в файле
        if [ -f "$FF_USER_JS" ]; then
            sed -i '/toolkit\.legacyUserProfileCustomizations\.stylesheets/d' "$FF_USER_JS"
        fi
        
        # Добавляем параметр, включающий кастомный CSS
        echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$FF_USER_JS"
        echo "  -> Настройки Firefox успешно применены!"
    else
        echo "⚠️ Не удалось найти папку профиля Firefox. Установите тему вручную."
    fi
else
    echo "⚠️ Папка chrome.catppuccin не найдена в скачанном репозитории. Пропускаем..."
fi

# 10. Выдача прав на выполнение скриптам
echo "🔧 Настройка прав доступа для исполняемых файлов..."
find "$HOME/.config/sway" "$HOME/.config/waybar" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

echo "======================================================="
echo "✅ Установка успешно завершена!"
echo "======================================================="
echo "📌 Бэкап ваших старых конфигов и тем: $BACKUP_DIR"
echo "📌 ВАЖНО: Чтобы заработала регулировка яркости (утилита light), нужно перезайти в систему (чтобы применились права группы video)."
echo "📌 ТЕМА FIREFOX: Полностью установлена и активирована автоматически!"
echo "📌 GTK-ТЕМЫ: Скопированы в ~/.themes. Они автоматически применятся к приложениям при следующем входе."
echo "📌 Теперь завершите сеанс и выберите сессию Sway при входе."