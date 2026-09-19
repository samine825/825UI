#include <iostream>
#include <fstream>
#include <filesystem>
#include <cstdlib>
#include <vector>
#include <format>

int main(int argc, char* argv[]) {
    #ifndef VERSION_STR
    #define VERSION_STR "dev (unversioned build)"
    #endif

	std::setlocale(LC_ALL, "");
    std::cout << std::format("825ctl {}\n", VERSION_STR/*при сборке, симейк ставит эту переменную*/) << std::endl;
    
    std::vector<std::string> args;

    for (int i = 1; i < argc; ++i) {
        args.push_back(std::string(argv[i]));
    }
    if (argc > 1) {
        if (args[0] == "-h" || args[0] == "--help" || args[0] == "help"){
            std::cout << "help"
            "menu" << std::endl;
        }
        else if (args[0] == "start") {
            std::string command = "qs -p ~/.825UI > /dev/null 2>&1 &";
            int result = std::system(command.c_str());
        }
        else if (args[0] == "restart") {
            std::string command = "qs -p ~/.825UI ipc call main forceReload && notify-send -t 10000 -a '825' 'Reloaded' ':3' -i ~/Pictures/photo_2026-04-11_22-51-18.jpg";
            int result = std::system(command.c_str());
        }
        else if (args[0] == "stop") {
            std::string command = "killall -9 qs";
            int result = std::system(command.c_str());
        }
        else if (args[0] == "toggle_app") {
            if (argc > 2) {
                if (args[1] == "control_panel") {
                    std::string command = "qs -p ~/.825UI ipc call main toggleControl";
                    int result = std::system(command.c_str());
                }
                else if (args[1] == "app_launcher") {
                    std::string command = "qs -p ~/.825UI ipc call main toggleLauncher";
                    int result = std::system(command.c_str());
                }
                else if (args[1] == "settings") {
                    std::string command = "qs -p ~/.825UI ipc call main toggleSettings";
                    int result = std::system(command.c_str());
                }
            }
        }
        else if (args[0] == "labudabudabdab") {
            if (argc > 2) {
                if (args[1] == "sc") {
                    std::string command = "qs -p ~/.825UI ipc call main spawnCube";
                    int result = std::system(command.c_str());
                }
                else if (args[1] == "cc") {
                    std::string command = "qs -p ~/.825UI ipc call main clearCubes";
                    int result = std::system(command.c_str());
                }
            }
        }
    }

    return 0;
}
