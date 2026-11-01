#include <iostream>
#include <fstream>
#include <filesystem>
#include <cstdlib>
#include <cstdio>
#include <vector>
#include <string>
#include <format>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

namespace {

// убрать хвостовые \n, \r
void rtrim(std::string& s) {
    while (!s.empty() && (s.back() == '\n' || s.back() == '\r'))
        s.pop_back();
}

// жива ли оболочка 825UI. [.] в паттерне — чтобы pgrep не совпал
// с собственной обёрткой sh -c, которую порождает popen
bool shellRunning(std::vector<std::string>* lines = nullptr) {
    FILE* p = popen("pgrep -af 'qs -p .*[.]825UI' 2>/dev/null", "r");

    if (!p)
        return false;

    bool found = false;
    char buf[512];

    while (fgets(buf, sizeof(buf), p)) {
        found = true;

        if (lines) {
            std::string line(buf);
            rtrim(line);
            lines->push_back(line);
        }
    }

    pclose(p);
    return found;
}

// ipc-команды имеют смысл только у живой оболочки
bool requireShell() {
    if (shellRunning())
        return true;

    std::cout << "825ctl: оболочка не запущена — попробуй: 825ctl start"
        << std::endl;
    return false;
}

void ipc(const std::string& call) {
    std::string cmd = "qs -p ~/.825UI ipc call main " + call;
    std::system(cmd.c_str());
}

void printHelp() {
    std::cout << std::endl;
    std::cout << "825ctl — пульт оболочки 825UI" << std::endl;
    std::cout << std::endl;
    std::cout << "Оболочка:" << std::endl;
    std::cout << "  start       запустить оболочку; повторный запуск"
        " копию не плодит" << std::endl;
    std::cout << "  restart     перечитать конфиг работающей оболочки"
        << std::endl;
    std::cout << "  stop        остановить оболочку" << std::endl;
    std::cout << "  status      жива ли оболочка, и если да — её процессы"
        << std::endl;
    std::cout << std::endl;
    std::cout << "Панели и колёса устройств (одновременно открыто только"
        << std::endl;
    std::cout << "  одно окно: открытие нового закрывает предыдущее;"
        " кот не считается):" << std::endl;
    std::cout << "  toggle_app <что>   control_panel | app_launcher"
        " | settings | cat" << std::endl;
    std::cout << "                     clipboard | calculator | emoji"
        << std::endl;
    std::cout << "                     clock | camera | recorder"
        " — приложения" << std::endl;
    std::cout << "                     wifi | bluetooth | output"
        " | input — колёса устройств" << std::endl;
    std::cout << std::endl;
    std::cout << "Приложения:" << std::endl;
    std::cout << "  clipboard       буфер обмена: текст и картинки,"
        " закрепы" << std::endl;
    std::cout << "  calculator      калькулятор" << std::endl;
    std::cout << "  emoji           эмодзи с поиском и недавними"
        << std::endl;
    std::cout << "  clock           часы: будильники, секундомер,"
        " таймер" << std::endl;
    std::cout << "  camera          камера: фото и видео"
        " (~/Pictures/825UI)" << std::endl;
    std::cout << "  recorder        диктофон (~/Pictures/825UI)"
        << std::endl;
    std::cout << std::endl;
    std::cout << "Экран:" << std::endl;
    std::cout << "  lock        экран блокировки; пароль — системный,"
        " Enter — отправить" << std::endl;
    std::cout << std::endl;
    std::cout << "Кот:" << std::endl;
    std::cout << "  labudabudabdab <что>   scubes | сcubes | pconway"
        " | cconway" << std::endl;
    std::cout << "  cursor        демон позиции курсора — кот запускает"
        " его сам, руками не трогать" << std::endl;
    std::cout << std::endl;
}

} // namespace

int main(int argc, char* argv[]) {
    #ifndef VERSION_STR
    #define VERSION_STR "dev"
    #endif

	std::setlocale(LC_ALL, "");
    std::cout << std::format("825ctl {}\n", VERSION_STR/*при сборке, симейк ставит эту переменную*/) << std::endl;

    std::vector<std::string> args;

    for (int i = 1; i < argc; ++i) {
        args.push_back(std::string(argv[i]));
    }

    if (argc > 1) {
        if (args[0] == "-h" || args[0] == "--help" || args[0] == "help"){
            printHelp();
        }
        else if (args[0] == "start") {
            // второй инстанс не запускаем: ipc и сервисы встанут в позу
            std::vector<std::string> procs;

            if (shellRunning(&procs)) {
                std::cout << "825ctl: оболочка уже запущена:"
                    << std::endl;

                for (const auto& l : procs)
                    std::cout << "  " << l << std::endl;

                std::cout << std::endl;
            } else {
                std::string command =
                    "qs -p ~/.825UI > /dev/null 2>&1 &";
                int result = std::system(command.c_str());
                std::cout << "825ctl: оболочка запускается"
                    << std::endl;
            }
        }
        else if (args[0] == "restart") {
            if (requireShell()) {
                std::string command = "qs -p ~/.825UI ipc call main forceReload && notify-send -t 10000 -a '825' '825UI reloaded' ':3' -i ~/.825UI/Textures/4.jpg";
                int result = std::system(command.c_str());
            }
        }
        else if (args[0] == "stop") {
            if (!shellRunning()) {
                std::cout << "825ctl: оболочка и так не запущена"
                    << std::endl;
            } else {
                std::string command = "killall -9 qs";
                int result = std::system(command.c_str());
                std::cout << "825ctl: оболочка остановлена"
                    << std::endl;
            }
        }
        else if (args[0] == "status") {
            std::vector<std::string> procs;
            shellRunning(&procs);

            if (procs.empty()) {
                std::cout << "825ctl: оболочка не запущена — попробуй:"
                    " 825ctl start" << std::endl;
            } else {
                std::cout << "825ctl: оболочка работает:" << std::endl;

                for (const auto& l : procs)
                    std::cout << "  " << l << std::endl;

                std::cout << std::endl;
            }
        }
        else if (args[0] == "lock") {
            if (requireShell()) {
                std::string command = "qs -p ~/.825UI ipc call main lock";
                int result = std::system(command.c_str());
            }
        }
        else if (args[0] == "toggle_app") {
            if (argc <= 2) {
                std::cout << "825ctl: укажи, что тоглать — панель"
                    " (control_panel, app_launcher, settings, cat),"
                    " приложение (clipboard, calculator, emoji,"
                    " clock, camera, recorder) или колесо устройств"
                    " (wifi, bluetooth, output, input)" << std::endl;
            }
            else if (args[1] == "control_panel") {
                if (requireShell()) {
                    std::string command = "qs -p ~/.825UI ipc call main toggleControl";
                    int result = std::system(command.c_str());
                }
            }
            else if (args[1] == "app_launcher") {
                if (requireShell()) {
                    std::string command = "qs -p ~/.825UI ipc call main toggleLauncher";
                    int result = std::system(command.c_str());
                }
            }
            else if (args[1] == "settings") {
                if (requireShell()) {
                    std::string command = "qs -p ~/.825UI ipc call main toggleSettings";
                    int result = std::system(command.c_str());
                }
            }
            else if (args[1] == "cat") {
                if (requireShell()) {
                    std::string command = "qs -p ~/.825UI ipc call main toggleCat";
                    int result = std::system(command.c_str());
                }
            }
            else if (args[1] == "clipboard") {
                if (requireShell()) {
                    std::string command = "qs -p ~/.825UI ipc call main toggleClipboard";
                    int result = std::system(command.c_str());
                }
            }
            else if (args[1] == "calculator") {
                if (requireShell()) {
                    std::string command = "qs -p ~/.825UI ipc call main toggleCalculator";
                    int result = std::system(command.c_str());
                }
            }
            else if (args[1] == "emoji") {
                if (requireShell()) {
                    std::string command = "qs -p ~/.825UI ipc call main toggleEmoji";
                    int result = std::system(command.c_str());
                }
            }
            else if (args[1] == "clock") {
                if (requireShell()) {
                    std::string command = "qs -p ~/.825UI ipc call main toggleClock";
                    int result = std::system(command.c_str());
                }
            }
            else if (args[1] == "camera") {
                if (requireShell()) {
                    std::string command = "qs -p ~/.825UI ipc call main toggleCamera";
                    int result = std::system(command.c_str());
                }
            }
            else if (args[1] == "recorder") {
                if (requireShell()) {
                    std::string command = "qs -p ~/.825UI ipc call main toggleRecorder";
                    int result = std::system(command.c_str());
                }
            }
            else if (args[1] == "wifi") {
                if (requireShell()) {
                    std::string command = "qs -p ~/.825UI ipc call main toggleWifiWheel";
                    int result = std::system(command.c_str());
                }
            }
            else if (args[1] == "bluetooth") {
                if (requireShell()) {
                    std::string command = "qs -p ~/.825UI ipc call main toggleBtWheel";
                    int result = std::system(command.c_str());
                }
            }
            else if (args[1] == "output") {
                if (requireShell()) {
                    std::string command = "qs -p ~/.825UI ipc call main toggleSinkWheel";
                    int result = std::system(command.c_str());
                }
            }
            else if (args[1] == "input") {
                if (requireShell()) {
                    std::string command = "qs -p ~/.825UI ipc call main toggleSourceWheel";
                    int result = std::system(command.c_str());
                }
            }
            else {
                std::cout << std::format(
                    "825ctl: \"{}\" не знаю; панели — control_panel,"
                    " app_launcher, settings, cat; приложения —"
                    " clipboard, calculator, emoji, clock, camera,"
                    " recorder; колёса — wifi, bluetooth, output,"
                    " input\n",
                    args[1]) << std::endl;
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
            if (argc <= 2) {
                std::cout << "825ctl: укажи что — scubes, сcubes,"
                    " pconway или cconway" << std::endl;
            }
            else if (args[1] == "scubes") {
                if (requireShell()) {
                    std::string command = "qs -p ~/.825UI ipc call main spawnCube";
                    int result = std::system(command.c_str());
                }
            }
            else if (args[1] == "сcubes") {
                if (requireShell()) {
                    std::string command = "qs -p ~/.825UI ipc call main clearCubes";
                    int result = std::system(command.c_str());
                }
            }
            else if (args[1] == "pconway") {
                if (requireShell()) {
                    std::string command = "qs -p ~/.825UI ipc call main toggleConwayPause";
                    int result = std::system(command.c_str());
                }
            }
            else if (args[1] == "cconway") {
                if (requireShell()) {
                    std::string command = "qs -p ~/.825UI ipc call main clearConway";
                    int result = std::system(command.c_str());
                }
            }
            else {
                std::cout << std::format(
                    "825ctl: \"{}\" не знаю; есть scubes, сcubes,"
                    " pconway, cconway\n",
                    args[1]) << std::endl;
            }
        }
        else {
            std::cout << std::format(
                "825ctl: не знаю команду \"{}\" — список: 825ctl help\n",
                args[0]) << std::endl;
        }
    }

    return 0;
}
