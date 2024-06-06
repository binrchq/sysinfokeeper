package constants

import (
	"log"
	"os"
	"path"
	"strings"

	"bitrec.ai/dialmainer/core/utils"
)

var (
	RT_TABLES_FPATH = "/etc/iproute2/rt_tables"

	INTERFACE_DIR = "/dev/shm/smallnode/interface/"

	NETCONFIG_CONFIG_DIR    = "/etc/sysconfig/network-scripts/"
	NET_ADDRESS_GLOB_PATH   = "/sys/class/net/*/address"
	PPPD_LOG_PATH           = "/var/log/ppp/%s.log"
	PPPD_UP_LOG_PATH        = "/var/log/brc-ppp-up.log"
	PPPD_DOWN_LOG_PATH      = "/var/log/brc-ppp-down.log"
	PPPD_PID_PATH           = "/var/run/pppoe-adsl-%s.pid"
	PPPD_PID_KEEP_GLOB_PATH = "/var/run/pppoe-adsl-*.pid.keep"
	PPPD_BIN_PATH           = "/usr/sbin/pppd"
	CONTROL_BIN_PATH        string
	NAT_CHECKER_BIN_PATH    string
	PPPD_KEEPER_BIN_PATH    string
	PPPD_KEEPER_PID_PATH    string
	PPPD_KEEPER_LOG_PATH    string
	ROUTE_FPATH             = "/proc/net/route"

	HOSTNAME string
)

func init() {
	root := os.Getenv("SN_AGENT_DEV_DATA_ROOT")
	if root != "" {
		log.Println("Using SN_AGENT_DEV_DATA_ROOT for root directory")
		RT_TABLES_FPATH = path.Join(root, RT_TABLES_FPATH)
		INTERFACE_DIR = path.Join(root, INTERFACE_DIR)
		NETCONFIG_CONFIG_DIR = path.Join(root, NETCONFIG_CONFIG_DIR)
		NET_ADDRESS_GLOB_PATH = path.Join(root, NET_ADDRESS_GLOB_PATH)
		PPPD_LOG_PATH = path.Join(root, PPPD_LOG_PATH)
		PPPD_PID_PATH = path.Join(root, PPPD_PID_PATH)
		ROUTE_FPATH = path.Join(root, ROUTE_FPATH)
		BASE_DIR = path.Join(root, BASE_DIR)
		PPPD_UP_LOG_PATH = path.Join(root, PPPD_UP_LOG_PATH)
		PPPD_DOWN_LOG_PATH = path.Join(root, PPPD_DOWN_LOG_PATH)
	}
	CONTROL_BIN_PATH = path.Join(BASE_DIR, "smallnode_control")
	NAT_CHECKER_BIN_PATH = path.Join(BASE_DIR, "snode_nat_checker")
	PPPD_KEEPER_BIN_PATH = path.Join(BASE_DIR, "pppd_keeper")
	PPPD_KEEPER_PID_PATH = path.Join(BASE_DIR, "pppd_keeper.pid")
	PPPD_KEEPER_LOG_PATH = path.Join(BASE_DIR, "pppd_keeper.log")
	HOSTNAME = getHostname()
}

func getHostname() string {
	hostname, _ := os.Hostname()
	data, err := os.ReadFile(HOSTNAME_FPATH)
	if err != nil {
		log.Println("Error reading hostname", err.Error())
		return hostname
	}
	strSplit := strings.SplitN(string(data), "=", 2)
	if len(strSplit) < 2 {
		log.Println("hostname.conf format error")
		return hostname
	}
	return strings.TrimSpace(strSplit[1])
}

// 是否为供应商
func IsSupplierHost() bool {
	l := []string{"localhost", "localhost.localdomain"}
	return utils.ContainsAny(l, HOSTNAME)
}

func readServerTypeConfig(fpath string) string {
	data, err := utils.ReadFirstLine(fpath)
	if err != nil {
		log.Fatalf("read sertypes.conf err: %s\n", err.Error())
	}
	split := strings.Split(string(data), "=")
	if len(split) != 2 {
		log.Fatalf("sertypes.conf format error")
	}
	return split[1]
}

type serType struct {
	data string
	list []string
}

func NewSerType(data string) *serType {
	return &serType{
		data: data,
		list: strings.Split(data, ","),
	}
}

// 小节点类型:
// smallnode_ip 固定ip
// smallnode_pub_ip 固定ip外部
// smallnode_mip 固定多ip
// smallnode_pub_mip 固定多ip外部
// smallnode_pppoe 小节点拨号
// smallnode_lan_pppoe 小节点内网拨号
// smallnode_pub_pppoe 小节点外部拨号
// smallnode_pub_lan_pppoe 小节点外部内网拨号
