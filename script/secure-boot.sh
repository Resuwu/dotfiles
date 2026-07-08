#!/bin/bash

# ==============================================================================
# Скрипт автоматической настройки Secure Boot для CachyOS (через sbctl)
# ==============================================================================

# 1. Проверка прав суперпользователя (root)
if [ "$EUID" -ne 0 ]; then
  echo "❌ Ошибка: Пожалуйста, запустите скрипт с правами root (sudo)."
  exit 1
fi

echo "🔄 1. Проверка и установка утилиты sbctl..."
pacman -S --needed --noconfirm sbctl

echo "🔍 2. Проверка статуса Setup Mode в UEFI..."
SETUP_MODE=$(sbctl status | grep "Setup Mode" | awk '{print $3}')

if [ "$SETUP_MODE" != "Enabled" ]; then
  echo "----------------------------------------------------------------------"
  echo "❌ ОШИБКА: Ваш UEFI (BIOS) не находится в режиме настройки (Setup Mode)!"
  echo "----------------------------------------------------------------------"
  echo "Чтобы продолжить, вам необходимо:"
  echo "  1. Перезагрузиться в BIOS/UEFI."
  echo "  2. Найти настройки Secure Boot."
  echo "  3. Выбрать 'Clear Secure Boot Keys' или 'Delete PK' (перейти в Setup Mode)."
  echo "  4. Сохранить настройки, загрузиться в систему и запустить скрипт снова."
  echo "----------------------------------------------------------------------"
  exit 1
fi

echo "🔑 3. Создание собственных ключей Secure Boot..."
sbctl create-keys

echo "💾 4. Запись ключей в материнскую плату..."
# Флаг -m ОЧЕНЬ ВАЖЕН: он добавляет ключи Microsoft. 
# Без них могут не работать видеокарты (NVIDIA/AMD с Option ROM), Dual-Boot с Windows и некоторые контроллеры.
sbctl enroll-keys -m

echo "✍️ 5. Поиск и подпись загрузчиков и ядер CachyOS..."

# Функция для безопасной подписи файла, если он существует
sign_file() {
  if [ -f "$1" ]; then
    echo "  -> Подписываем: $1"
    sbctl sign -s "$1"
  fi
}

# Подпись загрузчика Limine
for efi in /boot/EFI/limine/BOOTX64.EFI \
           /boot/EFI/limine/liminex64.efi \
           /efi/EFI/limine/BOOTX64.EFI \
           /efi/EFI/limine/liminex64.efi \
           /boot/EFI/BOOT/BOOTX64.EFI \
           /efi/EFI/BOOT/BOOTX64.EFI; do
  sign_file "$efi"
done

# Подпись всех установленных ядер Linux и образов initramfs в /boot и /efi
echo "  -> Поиск ядер CachyOS..."
while IFS= read -r -d '' kernel; do
  sign_file "$kernel"
done < <(find /boot /efi -maxdepth 2 \( -name "vmlinuz-*" -o -name "initramfs-*.img" -o -name "*.efi" \) -print0 2>/dev/null)

echo "📊 6. Финальная проверка подписанных файлов:"
sbctl verify

echo "----------------------------------------------------------------------"
echo "✅ Настройка успешно завершена!"
echo "----------------------------------------------------------------------"
echo "Теперь вы можете перезагрузить компьютер в BIOS/UEFI и ВКЛЮЧИТЬ (Enable) Secure Boot."
echo "Благодаря флагу '-s', утилита sbctl автоматически создала хук для pacman."
echo "При последующих обновлениях ядра CachyOS будут подписываться АВТОМАТИЧЕСКИ."
echo "----------------------------------------------------------------------"