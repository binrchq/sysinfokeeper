package packages

import (
	"bytes"
	"fmt"
	"net"
	"os/exec"
	"strings"

	"bitrec.ai/systemkeeper/core/model"
)

type Nic struct{}

func NewNic() *Nic {
	return &Nic{}
}

func (c *Nic) Get() (*model.NicModel, error) {
	interfaces, err := net.Interfaces()
	if err != nil {
		return nil, err
	}

	var nicInfos []model.NicInfo

	for _, iface := range interfaces {
		nicType := "unknown"
		maxSpeed := "unknown"

		if (iface.Flags & net.FlagLoopback) != 0 {
			continue
		}
		// Determine if the interface is virtual or physical
		if _, err := exec.Command("test", "-e", fmt.Sprintf("/sys/class/net/%s/device", iface.Name)).Output(); err == nil {
			nicType = "physical"
		} else {
			nicType = "virtual"
		}
		// Get the IP addresses
		var ipv4Addresses, ipv6Addresses []string
		addrs, err := iface.Addrs()
		if err != nil {
			return nil, err
		}
		for _, addr := range addrs {
			ipNet, ok := addr.(*net.IPNet)
			if ok {
				if ipNet.IP.To4() != nil {
					ipv4Addresses = append(ipv4Addresses, ipNet.IP.String())
				} else if ipNet.IP.To16() != nil {
					ipv6Addresses = append(ipv6Addresses, ipNet.IP.String())
				}
			}
		}

		// Fetching NIC status
		status := getInterfaceStatus(iface.Name)

		var vendor, models string
		// Example brand and model fetching (this requires custom logic based on the system)
		if nicType == "physical" {
			vendor, models, maxSpeed, _ = getVendorModelAndSpeed(iface.Name)
		}
		// if err != nil {
		// 	return nil, err
		// }

		// Add NIC info to the list
		nicInfos = append(nicInfos, model.NicInfo{
			Name:          iface.Name,
			Type:          nicType,
			MacAddress:    iface.HardwareAddr.String(),
			MaxRatedSpeed: maxSpeed,
			IPv4Addresses: ipv4Addresses,
			IPv6Addresses: ipv6Addresses,
			Vendor:        vendor,
			Model:         models,
			Status:        status,
		})
	}

	// Creating the NicModel and assigning the fetched NIC information
	nicModel := model.NewNic()
	nicModel.NicInfos = nicInfos

	// Return the populated NicModel
	return nicModel, nil
}

func getInterfaceStatus(ifaceName string) string {
	cmd := exec.Command("ethtool", ifaceName)
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		return "Unknown"
	}

	output := out.String()
	if strings.Contains(output, "Link detected: yes") {
		return "up"
	} else if strings.Contains(output, "Link detected: no") {
		return "down"
	}

	return "Unknown"
}
func getVendorModelAndSpeed(iface string) (string, string, string, error) {
	cmd := exec.Command("lshw", "-class", "network")
	output, err := cmd.Output()
	if err != nil {
		return "", "", "", err
	}

	blocks := strings.Split(string(output), "*-network")
	for _, block := range blocks {
		if strings.Contains(block, fmt.Sprintf("logical name: %s", iface)) {
			lines := strings.Split(block, "\n")
			var vendor, model, maxSpeed string

			for _, line := range lines {
				line = strings.TrimSpace(line)
				if strings.HasPrefix(line, "vendor:") {
					vendor = strings.TrimPrefix(line, "vendor: ")
				} else if strings.HasPrefix(line, "product:") {
					model = strings.TrimPrefix(line, "product: ")
				} else if strings.HasPrefix(line, "capacity:") {
					maxSpeed = strings.TrimPrefix(line, "capacity: ")
				}
			}
			return vendor, model, maxSpeed, nil
		}
	}

	return "unknown", "unknown", "unknown", fmt.Errorf("interface %s not found in lshw output", iface)
}
