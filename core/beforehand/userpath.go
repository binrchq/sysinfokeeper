package beforehand

import (
	"fmt"
	"os"
	"os/user"
	"path/filepath"
	"strings"

	"bitrec.ai/systemkeeper/core/utils"
)

var (
	// selfName      = "inxi"
	selfPath      string
	// userConfigDir string
	userDataDir   string
	// fakeDataDir   string
	logFile       string
)

func SetUserPaths() {
	// Initialize variables
	var bConf, bData bool

	// Get the path of the executable
	selfPath = os.Args[0]
	selfPath = strings.TrimSuffix(selfPath, filepath.Base(selfPath))

	// Get current user
	usr, err := user.Current()
	if err != nil {
		fmt.Println("Error getting current user:", err)
		return
	}

	homeDir := usr.HomeDir

	// Set user config directory
	if xdgConfigHome := os.Getenv("XDG_CONFIG_HOME"); xdgConfigHome != "" {
		userConfigDir = xdgConfigHome
		bConf = true
	} else if utils.DirExists(filepath.Join(homeDir, ".config")) {
		userConfigDir = filepath.Join(homeDir, ".config")
		bConf = true
	} else {
		userConfigDir = filepath.Join(homeDir, "."+selfName)
	}

	// Set user data directory
	if xdgDataHome := os.Getenv("XDG_DATA_HOME"); xdgDataHome != "" {
		userDataDir = filepath.Join(xdgDataHome, selfName)
		bData = true
	} else if utils.DirExists(filepath.Join(homeDir, ".local/share")) {
		userDataDir = filepath.Join(homeDir, ".local/share", selfName)
		bData = true
	} else {
		userDataDir = filepath.Join(homeDir, "."+selfName)
	}

	// Create user data directory if it doesn't exist
	if !utils.DirExists(userDataDir) {
		err := os.MkdirAll(userDataDir, os.ModePerm)
		if err != nil {
			fmt.Println("Error creating user data directory:", err) 
			return
		}
	}

	// Handle old config migration if necessary
	if bConf && utils.FileExists(filepath.Join(homeDir, "."+selfName, selfName+".conf")) {
		// Placeholder for moving old config to new location
		fmt.Printf("WOULD: Move %s.conf from %s/.%s to %s\n", selfName, homeDir, selfName, userConfigDir)
	}

	// Handle old data migration if necessary
	if bData && utils.DirExists(filepath.Join(homeDir, "."+selfName)) {
		// Placeholder for moving old data to new location and removing old directory
		fmt.Printf("WOULD: Move data dir %s/.%s to %s\n", homeDir, selfName, userDataDir)
	}

	fakeDataDir = filepath.Join(homeDir, "bin/scripts/inxi/data")
	logFile = filepath.Join(userDataDir, selfName+".log")

	// Print debug information
	// fmt.Printf("scd: %s sdd: %s\n", userConfigDir, userDataDir)
}
