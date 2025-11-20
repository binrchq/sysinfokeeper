package beforehand

import (
	"os"
	"os/exec"
	"os/user"
	"strings"

	"binrc.com/sysinfokeeper/core/utils"
)

var (
	bIrc     bool
	bDisplay bool
	bRoot    bool
	dl       = make(map[string]bool)
	client   = make(map[string]interface{})
	// colors     = make(map[string]int)
	// show       = make(map[string]string)
	rawLogical [3]int
	ppid       int
)

func SetBasics() {
	// Set environment variables for localization
	os.Setenv("LANG", "C")
	os.Setenv("LC_ALL", "C")

	// Check if tty is available
	bIrc = utils.CheckProgram("tty") && exec.Command("tty").Run() != nil

	// Check if a display environment is set
	if os.Getenv("DISPLAY") != "" || os.Getenv("WAYLAND_DISPLAY") != "" || os.Getenv("XDG_CURRENT_DESKTOP") != "" || os.Getenv("DESKTOP_SESSION") != "" {
		bDisplay = true
	}

	// Check if the user is root
	bRoot = os.Geteuid() == 0

	// Set download methods
	dl["dl"] = true
	dl["curl"] = true
	dl["fetch"] = true
	dl["tiny"] = true
	dl["wget"] = true

	// Initialize client settings
	client["console-irc"] = 0
	client["dcop"] = utils.BoolToInt(utils.CheckProgram("dcop"))
	client["qdbus"] = utils.BoolToInt(utils.CheckProgram("qdbus"))
	client["konvi"] = 0
	client["name"] = ""
	client["name-print"] = ""
	client["su-start"] = ""
	client["version"] = ""

	// Get the current user
	currentUser, err := user.Current()
	if err == nil {
		client["whoami"] = currentUser.Username
	} else {
		client["whoami"] = ""
	}

	// Set default colors
	colors["default"] = 2

	// Set default partition sort order
	show["partition-sort"] = "id"

	// Initialize raw logical array
	rawLogical = [3]int{0, 0, 0}

	// Get the parent process ID
	ppid = os.Getppid()

	// Set HOME environment variable if not set
	if os.Getenv("HOME") == "" {
		whoamiOutput, err := exec.Command("whoami").Output()
		if err == nil {
			who := strings.TrimSpace(string(whoamiOutput))
			homeDirs := []string{"/" + who, "/home/" + who, "/usr/home/" + who}
			for _, dir := range homeDirs {
				if utils.DirExists(dir) {
					os.Setenv("HOME", dir)
					break
				}
			}
		}
	}
}
