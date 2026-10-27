#include <iostream>
#include <fstream>
#include <filesystem>
#include <cstdlib>
#include <vector>
#include <format>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

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
            std::string command = "qs -p ~/.825UI ipc call main forceReload && notify-send -t 10000 -a '825' 'Reloaded' ':3' -i ~/.825UI/Textures/4.jpg";
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
        else if (args[0] == "cursor") {
            // демон позиции курсора для кота: строки "X Y" в stdout, ~60 Гц.
            // Hyprland IPC отвечает на "cursorpos" (без перевода строки)
            // и закрывает соединение — на каждый тик новое соединение.
            const char* sig = std::getenv("HYPRLAND_INSTANCE_SIGNATURE");
            if (!sig) return 1;

            std::string path = std::string("/run/user/1000/hypr/") + sig + "/.socket.sock";
            if (const char* xdg = std::getenv("XDG_RUNTIME_DIR"))
                path = std::string(xdg) + "/hypr/" + sig + "/.socket.sock";

            while (true) {
                int fd = socket(AF_UNIX, SOCK_STREAM, 0);
                if (fd >= 0) {
                    sockaddr_un addr {};
                    addr.sun_family = AF_UNIX;
                    strncpy(addr.sun_path, path.c_str(), sizeof(addr.sun_path) - 1);

                    if (connect(fd, (sockaddr*)&addr, sizeof(addr)) == 0) {
                        if (write(fd, "cursorpos", 9) > 0) {
                            char buf[128];
                            ssize_t r = read(fd, buf, sizeof(buf) - 1);
                            if (r > 0) {
                                buf[r] = 0;
                                for (char* p = buf; *p; ++p)
                                    if (*p == ',') *p = ' ';
                                std::cout << buf << "\n";
                                std::cout.flush();
                            }
                        }
                    }
                    close(fd);
                }
                usleep(33000);
            }
        }
        else if (args[0] == "labudabudabdab") {
            if (argc > 2) {
                if (args[1] == "scubes") {
                    std::string command = "qs -p ~/.825UI ipc call main spawnCube";
                    int result = std::system(command.c_str());
                }
                else if (args[1] == "сcubes") {
                    std::string command = "qs -p ~/.825UI ipc call main clearCubes";
                    int result = std::system(command.c_str());
                }
                else if (args[1] == "pconway") {
                    std::string command = "qs -p ~/.825UI ipc call main toggleConwayPause";
                    int result = std::system(command.c_str());
                }
                else if (args[1] == "cconway") {
                    std::string command = "qs -p ~/.825UI ipc call main clearConway";
                    int result = std::system(command.c_str());
                }
            }
        }
    }

    return 0;
}
