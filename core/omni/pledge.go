package omni

import (
	"fmt"
	"strings"
	"syscall"
	"unsafe"

	"github.com/rs/zerolog/log"
)

const SYS_PLEDGE = 108

var (
	bPledge bool
	pledges []string
)

func init() {
	// Check if running on OpenBSD (assuming you are running on OpenBSD)
	if err := pledgeAvailable(); err == nil {
		bPledge = true

		// Define the pledges
		pledges = []string{"cpath", "dns", "exec", "getpw", "inet", "proc", "prot_exec", "rpath", "wpath"}

		// Perform the pledge
		err = pledge(strings.Join(pledges, " "), "")
		if err != nil {
			
			log.Warn().Err(err).Msg("pledge failed")
			fmt.Printf("pledge failed: %v\n", err)
		} 
	} else {
		fmt.Println("pledge is not available")
	}
}

// pledgeAvailable checks if pledge is available on the system
func pledgeAvailable() error {
	err := pledge("", "")
	if err != nil && err.Error() == "operation not supported" {
		return fmt.Errorf("pledge not supported")
	}
	return nil
}

// pledge makes a direct system call to pledge
func pledge(promises, execpromises string) error {
	_, _, errno := syscall.Syscall(SYS_PLEDGE, uintptr(unsafe.Pointer(syscall.StringBytePtr(promises))), uintptr(unsafe.Pointer(syscall.StringBytePtr(execpromises))), 0)
	if errno != 0 {
		return errno
	}
	return nil
}
