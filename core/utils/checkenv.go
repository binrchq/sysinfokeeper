package utils

import (
	"os"
	"os/exec"
)

func CheckCMD(cmd string) error {
	//查询是否有这个命令
	_, err := exec.LookPath(cmd)
	return err
}

func checkProgram(prog string) string {
	_, err := exec.LookPath(prog)
	if err != nil {
		return ""
	}
	return prog
}

func CheckProgram(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

// dirExists checks if a directory exists
func DirExists(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return info.IsDir()
}

// contains checks if a slice contains a given string
func Contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}

// fileExists checks if a file exists
func FileExists(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return !info.IsDir()
}
