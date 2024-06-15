package utils

import "strings"

func Is64Bit(flags string) bool {
	// 判断系统是否为64位 long mode 长扩展模式
	for _, flag := range strings.Fields(flags) {
		if flag == "lm" {
			return true
		}
	}
	return false
}
