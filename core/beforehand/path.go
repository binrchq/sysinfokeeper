package beforehand

import (
	"os"
	"strings"

	"binrc.com/sysinfokeeper/core/utils"
)

// setPath function to construct a PATH-like string
func SetPath() []string {
	var paths []string
	// Pre-defined directories
	testDirs := []string{"/sbin", "/bin", "/usr/sbin", "/usr/bin", "/usr/local/sbin", "/usr/local/bin", "/usr/X11R6/bin"}

	// Add pre-defined directories if they exist
	for _, dir := range testDirs {
		if utils.DirExists(dir) {
			paths = append(paths, dir)
		}
	}

	// Get current PATH environment variable
	pathEnv := os.Getenv("PATH")
	var envPaths []string
	if pathEnv != "" {
		envPaths = strings.Split(pathEnv, ":")
	}

	// Add directories from the current PATH environment variable
	for _, dir := range envPaths {
		if utils.DirExists(dir) && !utils.Contains(paths, dir) && !strings.Contains(dir, "game") {
			paths = append(paths, dir)
		}
	}

	return paths
}
