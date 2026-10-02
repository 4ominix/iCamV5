// CONFIRMED FROM BINARY: _NSGetExecutablePath import
// CONFIRMED FROM BINARY: "DYLD_INSERT_LIBRARIES" string
// CONFIRMED FROM BINARY: "/usr/lib/TweakInject/VCNextNetworkCompat.dylib" string
// CONFIRMED FROM BINARY: "VCNNetworkDaemon" target executable string
// CONFIRMED FROM BINARY: execl import, no ObjC runtime link (pure C)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <mach-o/dyld.h>

#define COMPAT_DYLIB "/usr/lib/TweakInject/VCNextNetworkCompat.dylib"
#define DAEMON_NAME  "VCNNetworkDaemon"
#define RPATH_FW     "/var/jb/Library/Frameworks"
#define RPATH_LIB    "/var/jb/usr/lib"

int main(int argc, char *argv[]) {
    char self_path[1024];
    uint32_t size = sizeof(self_path);
    if (_NSGetExecutablePath(self_path, &size) != 0) {
        dprintf(STDERR_FILENO, "VCNNetworkDaemonLauncher: failed to get executable path\n");
        return 1;
    }

    char *last_slash = strrchr(self_path, '/');
    if (!last_slash) {
        dprintf(STDERR_FILENO, "VCNNetworkDaemonLauncher: invalid path\n");
        return 1;
    }

    char daemon_path[1024];
    size_t dir_len = last_slash - self_path;
    memcpy(daemon_path, self_path, dir_len);
    snprintf(daemon_path + dir_len, sizeof(daemon_path) - dir_len, "/%s", DAEMON_NAME);

    setenv("DYLD_INSERT_LIBRARIES", COMPAT_DYLIB, 1);

    dprintf(STDOUT_FILENO, "VCNNetworkDaemonLauncher: exec %s\n", daemon_path);
    execl(daemon_path, DAEMON_NAME, NULL);

    dprintf(STDERR_FILENO, "VCNNetworkDaemonLauncher: execl failed\n");
    return 1;
}
