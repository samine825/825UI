mkdir -p build
cd build
rm emb_qs.h
cmake ..
cmake --build .
sudo cp 825ctl /usr/bin/
cd ..
rm compile_commands.json
ln -s build/compile_commands.json compile_commands.json

mkdir -p $HOME/.825UI
cp -r QS/. $HOME/.825UI/
mkdir -p $HOME/Pictures/Wallpapers
cp -r Wallpapers/. $HOME/Pictures/Wallpapers/

echo "installed"