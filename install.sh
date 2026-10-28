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

mkdir -p $HOME/.825UI
cp -r QS/. $HOME/.825UI/
mkdir -p $HOME/Pictures/Wallpapers
cp -r Wallpapers/. $HOME/Pictures/Wallpapers/

echo "installed"
