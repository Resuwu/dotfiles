#!/usr/bin/env bash

# Остановка скрипта при возникновении ошибок
set -e

# Цветной вывод
INFO="\033[1;34m[ИНФО]\033[0m"
SUCCESS="\033[1;32m[УСПЕХ]\033[0m"
WARN="\033[1;33m[ВНИМАНИЕ]\033[0m"

echo -e "${INFO} Начинаем полную настройку системы: CachyOS, Java/Kotlin, Сети и Snapper (Limine)..."

# ------------------------------------------------------------------------------
# 1. ОБНОВЛЕНИЕ СИСТЕМЫ И АВТОУСТАНОВКА PARU (AUR-ХЕЛПЕР)
# ------------------------------------------------------------------------------
echo -e "${INFO} Обновление баз данных пакетов и системы..."
sudo pacman -Syu --noconfirm

# Проверяем наличие AUR-хелпера и устанавливаем paru при необходимости
if command -v paru &> /dev/null; then
    AUR=yay
else
    echo -e "${INFO} AUR-хелпер не найден. Установка paru..."
    sudo pacman -S --needed --noconfirm base-devel git
    
    # В CachyOS paru есть в официальных репозиториях, пробуем ставить через pacman
    if sudo pacman -S --needed --noconfirm paru; then
        echo -e "${SUCCESS} paru успешно установлен из репозитория!"
    else
        # Запасной вариант для чистого Arch Linux (сборка из AUR)
        echo -e "${INFO} Собираем paru из исходников AUR..."
        git clone https://aur.archlinux.org/paru.git /tmp/paru
        (cd /tmp/paru && makepkg -si --noconfirm)
        rm -rf /tmp/paru
        echo -e "${SUCCESS} paru успешно собран и установлен!"
    fi
    AUR=paru
fi

echo -e "${SUCCESS} Используемый AUR-хелпер: ${AUR}"

# ------------------------------------------------------------------------------
# 2. БАЗОВЫЕ УТИЛИТЫ, АРХИВАТОРЫ И ШРИФТЫ
# ------------------------------------------------------------------------------
echo -e "${INFO} Установка базовых утилит, архиваторов и шрифтов..."
BASE_PACKAGES=(
    base-devel git curl wget unzip unrar p7zip tar xz zip
    ttf-jetbrains-mono-nerd noto-fonts-emoji ttf-liberation
)
sudo pacman -S --needed --noconfirm "${BASE_PACKAGES[@]}"

# ------------------------------------------------------------------------------
# 3. СОВРЕМЕННЫЙ CLI-СТЕК И ТЕРМИНАЛ KITTY
# ------------------------------------------------------------------------------
echo -e "${INFO} Установка прокачанного CLI-стека, Fish Shell и Kitty..."
CLI_PACKAGES=(
    btop eza bat grep fd fastfetch jq lnav
    fish fzf kitty
)
sudo pacman -S --needed --noconfirm "${CLI_PACKAGES[@]}"

# ------------------------------------------------------------------------------
# 4. ПОВСЕДНЕВНЫЙ СОФТ, ГРАФИКА, ОФИС, БАЗЫ ДАННЫХ И СЕТИ
# ------------------------------------------------------------------------------
echo -e "${INFO} Установка графических приложений, LibreOffice, Krita, Inkscape и FileZilla..."
GUI_PACKAGES=(
    firefox mpv qbittorrent
    dbeaver docker docker-compose flatpak
    openvpn networkmanager-openvpn
    krita inkscape filezilla libreoffice-fresh
)
sudo pacman -S --needed --noconfirm "${GUI_PACKAGES[@]}"

# ------------------------------------------------------------------------------
# 5. НАСТРОЙКА DOCKER
# ------------------------------------------------------------------------------
echo -e "${INFO} Настройка и запуск службы Docker..."
sudo systemctl enable --now docker.service
sudo usermod -aG docker "$USER"
echo -e "${SUCCESS} Служба Docker успешно запущена и настроена."

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
# 7. УСТАНОВКА ЧЕРЕЗ AUR / CACHYOS REPO
# ------------------------------------------------------------------------------
echo -e "${INFO} Установка пакетов из AUR (IDE, Сети, БД, Snapper + Limine)..."
AUR_PACKAGES=(
#    jetbrains-toolbox
    visual-studio-code-bin
    amneziawg-tools-git
    amneziawg-linux
    brrtfetch-git
)
$AUR -S --needed --noconfirm "${AUR_PACKAGES[@]}"

# ------------------------------------------------------------------------------
# 9. НАСТРОЙКА FISH SHELL, ПЛАГИНОВ И СМЕНА ОБОЛОЧКИ ПО УМОЛЧАНИЮ
# ------------------------------------------------------------------------------
echo -e "${INFO} Установка менеджера Fisher и плагинов для Fish Shell..."

# Устанавливаем сам Fisher
fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"

# Устанавливаем плагины: fzf, autopair, sponge, git, bobthefish и sdkman-for-fish
echo -e "${INFO} Установка плагинов для Fish..."
fish -c "fisher install PatrickF1/fzf.fish jorgebucaran/autopair.fish meaningful-ooo/sponge jhillyerd/plugin-git oh-my-fish/theme-bobthefish reitzig/sdkman-for-fish"

# Автоматически делаем Fish оболочкой по умолчанию для текущего пользователя
echo -e "${INFO} Назначаем Fish оболочкой по умолчанию для пользователя $USER..."
sudo chsh -s "$(which fish)" "$USER"
echo -e "${SUCCESS} Fish успешно назначен оболочкой по умолчанию!"

# ------------------------------------------------------------------------------
# 10. УСТАНОВКА JAVA / KOTLIN СТЕКА ЧЕРЕЗ SDKMAN!
# ------------------------------------------------------------------------------
echo -e "${INFO} Установка SDKMAN! и Java/Kotlin зависимостей..."

export SDKMAN_DIR="$HOME/.sdkman"
if [ ! -d "$SDKMAN_DIR" ]; then
    curl -s "https://get.sdkman.io?rcupdate=false" | bash
fi

# shellcheck source=/dev/null
source "$HOME/.sdkman/bin/sdkman-init.sh"

echo -e "${INFO} Установка Amazon Corretto 17, Eclipse Temurin 21, Gradle и Maven..."
yes | sdk install java 17.0.11-amzn || true
yes | sdk install java 21.0.3-tem || true
yes | sdk install gradle || true
yes | sdk install maven || true

# ------------------------------------------------------------------------------
# 11. ЗАВЕРШЕНИЕ
# ------------------------------------------------------------------------------
echo -e "------------------------------------------------------------------------"
echo -e "${SUCCESS} Установка успешно завершена!"
echo -e "${INFO} Важные действия после установки:"
echo -e "  1. Перезагрузите компьютер, чтобы применились права Docker и запустился Fish."
echo -e "  2. Btrfs и Limine: при каждом обновлении (sudo pacman -Syu) снапшот будет создаваться"
echo -e "     автоматически и добавляться в меню Limine (максимум 8 последних состояний)."
echo -e "     Управлять снапшотами визуально можно через приложение 'Btrfs Assistant'."
echo -e "  3. Для управления версиями Java в Fish используйте: sdk use java 17.0.11-amzn"
echo -e "------------------------------------------------------------------------"
