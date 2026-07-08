#!/usr/bin/env bash

# Остановка скрипта при возникновении ошибок
set -e

# Цветной вывод
INFO="\033[1;34m[ИНФО]\033[0m"
SUCCESS="\033[1;32m[УСПЕХ]\033[0m"
WARN="\033[1;33m[ВНИМАНИЕ]\033[0m"

echo -e "${INFO} Начинаем настройку системы: База, Btrfs Снапшоты, Java/Kotlin, Графика, Офис и Сети..."

# ------------------------------------------------------------------------------
# 1. ОБНОВЛЕНИЕ СИСТЕМЫ И ОПРЕДЕЛЕНИЕ AUR-ХЕЛПЕРА
# ------------------------------------------------------------------------------
echo -e "${INFO} Обновление баз данных пакетов и системы..."
sudo pacman -Syu --noconfirm

if command -v paru &> /dev/null; then
    AUR=paru
elif command -v yay &> /dev/null; then
    AUR=yay
else
    echo -e "${WARN} AUR-хелпер (paru/yay) не найден. AUR-пакеты будут пропущены."
    AUR=""
fi

# ------------------------------------------------------------------------------
# 2. БАЗОВЫЕ УТИЛИТЫ И ШРИФТЫ
# ------------------------------------------------------------------------------
echo -e "${INFO} Установка базовых утилит, архиваторов и шрифтов..."
BASE_PACKAGES=(
    base-devel git curl wget unzip unrar p7zip tar xz zip
    ttf-jetbrains-mono-nerd noto-fonts-emoji ttf-liberation
)
sudo pacman -S --needed --noconfirm "${BASE_PACKAGES[@]}"

# ------------------------------------------------------------------------------
# 3. СОВРЕМЕННЫЙ CLI-СТЕК (Включая kcat для Kafka)
# ------------------------------------------------------------------------------
echo -e "${INFO} Установка прокачанного CLI-стека, Fish Shell и kcat..."
CLI_PACKAGES=(
    btop eza bat grep fd cd fastfetch jq lnav
    fish fzf kcat kitty
)
sudo pacman -S --needed --noconfirm "${CLI_PACKAGES[@]}"

# ------------------------------------------------------------------------------
# 4. ПОВСЕДНЕВНЫЙ СОФТ, ГРАФИКА, ОФИС, БАЗЫ ДАННЫХ И СЕТИ
# ------------------------------------------------------------------------------
echo -e "${INFO} Установка графических приложений, LibreOffice, Krita, Inkscape и FileZilla..."
# Добавлены krita, inkscape, filezilla и libreoffice-fresh
GUI_PACKAGES=(
    firefox mpv qbittorrent flameshot
    dbeaver docker docker-compose flatpak
    openvpn networkmanager-openvpn xray
    timeshift redis
    krita inkscape filezilla libreoffice-fresh
)
sudo pacman -S --needed --noconfirm "${GUI_PACKAGES[@]}"

# ------------------------------------------------------------------------------
# 5. НАСТРОЙКА СЛУЖБ (DOCKER И REDIS)
# ------------------------------------------------------------------------------
echo -e "${INFO} Настройка и запуск служб Docker и Redis..."
sudo systemctl enable --now docker.service
sudo systemctl enable --now redis.service
sudo usermod -aG docker "$USER"
echo -e "${SUCCESS} Службы запущены. Redis доступен на порту по умолчанию (6379)."

# ------------------------------------------------------------------------------
# 6. УСТАНОВКА ЧЕРЕЗ FLATPAK (Мессенджеры, заметки, Postman, Spotify)
# ------------------------------------------------------------------------------
echo -e "${INFO} Настройка Flatpak-приложений..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

FLATPAK_APPS=(
    org.telegram.desktop
    com.discordapp.Discord
    md.obsidian.Obsidian
    com.getpostman.Postman
    com.spotify.Client
)

for app in "${FLATPAK_APPS[@]}"; do
    flatpak install -y flathub "$app"
done

# ------------------------------------------------------------------------------
# 7. УСТАНОВКА ЧЕРЕЗ AUR (JetBrains, VS Code, VPN/Proxy, MongoDB Compass, Kafka/Redis)
# ------------------------------------------------------------------------------
if [ -n "$AUR" ]; then
    echo -e "${INFO} Установка пакетов из AUR..."
    # Добавлен mongodb-compass
    AUR_PACKAGES=(
        jetbrains-toolbox
        visual-studio-code-bin
        amneziawg-tools
        amneziawg-go
        nekoray
        timeshift-autosnap
        another-redis-desktop-manager-bin
        offsetexplorer
        mongodb-compass
    )
    $AUR -S --needed --noconfirm "${AUR_PACKAGES[@]}"
else
    echo -e "${WARN} Пропускаем AUR-пакеты."
fi

# ------------------------------------------------------------------------------
# 8. НАСТРОЙКА FISH SHELL, ПЛАГИНОВ И СМЕНА ОБОЛОЧКИ ПО УМОЛЧАНИЮ
# ------------------------------------------------------------------------------
echo -e "${INFO} Установка менеджера Fisher и плагинов для Fish Shell..."

# Устанавливаем сам Fisher
fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"

# Устанавливаем ваши плагины + поддержку SDKMAN для Fish
echo -e "${INFO} Установка плагинов: fzf, autopair, sponge, git, bobthefish и sdkman..."
fish -c "fisher install PatrickF1/fzf.fish jorgebucaran/autopair.fish meaningful-ooo/sponge jhillyerd/plugin-git oh-my-fish/theme-bobthefish reitzig/sdkman-for-fish"

# Автоматически делаем Fish оболочкой по умолчанию для текущего пользователя
echo -e "${INFO} Назначаем Fish оболочкой по умолчанию для пользователя $USER..."
sudo chsh -s "$(which fish)" "$USER"
echo -e "${SUCCESS} Fish успешно назначен оболочкой по умолчанию!"

# ------------------------------------------------------------------------------
# 9. УСТАНОВКА JAVA / KOTLIN СТЕКА ЧЕРЕЗ SDKMAN!
# ------------------------------------------------------------------------------
echo -e "${INFO} Установка SDKMAN! и Java/Kotlin зависимостей..."

export SDKMAN_DIR="$HOME/.sdkman"
if [ ! -d "$SDKMAN_DIR" ]; then
    curl -s "https://get.sdkman.io?rcupdate=false" | bash
fi

# shellcheck source=/dev/null
source "$HOME/.sdkman/bin/sdkman-init.sh"

yes | sdk install java 17.0.11-amzn || true
yes | sdk install java 21.0.3-tem || true
yes | sdk install gradle || true
yes | sdk install maven || true

# ------------------------------------------------------------------------------
# 10. ЗАВЕРШЕНИЕ
# ------------------------------------------------------------------------------
echo -e "------------------------------------------------------------------------"
echo -e "${SUCCESS} Установка успешно завершена!"
echo -e "${INFO} Важные действия после установки:"
echo -e "  1. ВАЖНО ДЛЯ BTRFS: Откройте приложение 'Timeshift' в меню системы,"
echo -e "     выберите режим 'BTRFS' и пройдите мастер первоначальной настройки."
echo -e "     После этого при каждом обновлении системы будет создаваться авто-снапшот!"
echo -e "  2. Базы данных и брокеры сообщений:"
echo -e "     - MongoDB Compass, DBeaver и Another Redis Desktop Manager доступны в меню приложений."
echo -e "     - Сервер Redis уже работает в фоне на порту 6379."
echo -e "  3. Перезагрузите компьютер, чтобы применились права Docker и запустился Fish!"
echo -e "------------------------------------------------------------------------"