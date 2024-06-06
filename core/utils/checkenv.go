package utils

import "os/exec"

func CheckCMD(cmd string) error {
	//查询是否有这个命令
	_, err := exec.LookPath(cmd)
	return err
}


