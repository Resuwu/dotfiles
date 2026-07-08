# Отключение стандартного приветствия Fish
set -g fish_greeting

# Автозапуск fastfetch при открытии новой интерактивной сессии
if status is-interactive
    fastfetch
end

# --- Настройка темы bobthefish ---
set -g theme_color_scheme dark
set -g theme_display_git yes
set -g theme_display_docker_machine yes
set -g theme_display_java yes  # Показывать текущую версию Java из SDKMAN!
set -g theme_nerd_fonts yes    # Использовать установленные Nerd Fonts

# --- Алиасы (замена классических команд на современные) ---
alias ls="eza --icons --group-directories-first"
alias ll="eza -lh --icons --grid --group-directories-first"
alias la="eza -lah --icons --group-directories-first"
alias cat="bat --style=plain"
alias top="btop"