mkdir -p build
cd build
cmake ..
cmake --build .
# демон курсора держит бинарник — гасим, чтобы cp не словил Text file busy
pkill -f "825ctl cursor" 2>/dev/null || true
sudo cp 825ctl /usr/bin/
cd ..
rm compile_commands.json
ln -s build/compile_commands.json compile_commands.json

# шелл следит за конфигом и на лету перечитывает файлы: посреди cp он
# ловит полу записанный qml и падает с "is not a type" — гасим до копирования,
# после установки запускаем заново (825ctl restart)
pkill -f "qs -p $HOME/.825UI" 2>/dev/null || true

# настройки пользователя (тема и т.д.) живут в установленном конфиге —
# не перетираем их копией из репозитория
if [ -f "$HOME/.825UI/settings.json" ]; then
    cp "$HOME/.825UI/settings.json" /tmp/825ui-settings.json
fi

mkdir -p $HOME/.825UI
cp -r QS/. $HOME/.825UI/

if [ -f /tmp/825ui-settings.json ]; then
    cp /tmp/825ui-settings.json "$HOME/.825UI/settings.json"
    rm /tmp/825ui-settings.json
fi
mkdir -p $HOME/Pictures/Wallpapers
cp -r Wallpapers/. $HOME/Pictures/Wallpapers/

echo "installed"
