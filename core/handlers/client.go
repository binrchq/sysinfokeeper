package handlers

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

var (
	bLog = false
	// bIrc   = false
	use    = make(map[string]int)
	client = make(map[string]int)
	loaded = make(map[string]bool)
	// bLog          bool
	ppid string
	// psCmd         []string
	// client        = make(map[string]interface{})
	start, end                string
	bDisplay, bIrc, useFilter bool
)

type Client struct {
}

func NewClient() *Client {
	return &Client{}
}

// sub set {
// 	eval $start if $b_log;
// 	# $b_irc = 1; # for testing, like cli konvi start which shows as tty
// 	if (!$b_irc){
// 		# we'll run ShellData::set() for -I, but only then
// 	}
// 	else {
// 		$use{'filter'} = 1;
// 		PsData::set() if !$loaded{'ps-data'};
// 		get_client_name();
// 		if ($client{'konvi'} == 1 || $client{'konvi'} == 3){
// 			set_konvi_data();
// 		}
// 	}
// 	eval $end if $b_log;
// }

func (c *Client) Set() {
	// if bLog {
	// 	startLogging()
	// }
	// b_irc = 1; // for testing, like cli konvi start which shows as tty
	if !bIrc {
		// we'll run ShellData::set() for -I, but only then
	} else {
		use["filter"] = 1
		if !loaded["ps-data"] {
			NewPsData().Set()
		}
		getClientName()
		if client["konvi"] == 1 || client["konvi"] == 3 {
			setKonviData()
		}
	}
	// if bLog {
	// 	endLogging()
	// }
}

func logData(tag, message string) {
	if bLog {
		log.Printf("[%s] %s\n", tag, message)
	}
}

func grabber(command string) []string {
	out, err := exec.Command("sh", "-c", command).Output()
	if err != nil {
		log.Fatal(err)
	}
	return strings.Split(string(out), "\n")
}

func getClientName() {
	if bLog {
		eval(start)
	}
	clientName := ""

	if ppid != "" && fileExists(fmt.Sprintf("/proc/%s/exe", ppid)) {
		clientName = strings.ToLower(readLink(fmt.Sprintf("/proc/%s/exe", ppid)))
		clientName = filepath.Base(clientName)

		if matched, _ := regexp.MatchString(`^(bash|csh|dash|fish|sh|python.*|perl.*|zsh)$`, clientName); matched {
			pppid := strings.TrimSpace(grabber(fmt.Sprintf("ps -wwp %s -o ppid", ppid))[1])
			clientName = regexp.MustCompile(`[0-9\.]+$`).ReplaceAllString(clientName, "")
			if pppid != "" && fileExists(fmt.Sprintf("/proc/%s/exe", pppid)) {
				clientName = strings.ToLower(readLink(fmt.Sprintf("/proc/%s/exe", pppid)))
				clientName = filepath.Base(clientName)
				client["native"] = 0
			}
		}
		client["name"] = clientName
		getClientVersion()
	} else {
		if !checkModernKonvi() {
			clientName = strings.TrimSpace(grabber(fmt.Sprintf("ps -wwp %s", ppid))[1])
			if clientName != "" {
				data := strings.Fields(clientName)
				if isBSD() {
					clientName = strings.ToLower(data[4])
				} else {
					clientName = strings.ToLower(data[len(data)-1])
				}
				clientName = regexp.MustCompile(`.*\|-(|)`).ReplaceAllString(clientName, "")
				clientName = regexp.MustCompile(`[0-9\.]+$`).ReplaceAllString(clientName, "")
				client["name"] = clientName
				client["native"] = 1
				getClientVersion()
			} else {
				client["name"] = fmt.Sprintf("PPID='%s' - Empty?", ppid)
			}
		}
	}
	if bLog {
		string := fmt.Sprintf("Client: %s :: version: %s :: konvi: %v :: PPID: %s", client["name"], client["version"], client["konvi"], ppid)
		logData("data", string)
	}
	if bLog {
		eval(end)
	}
}

func getClientVersion() {
	if bLog {
		eval(start)
	}
	// Example implementation, replace with actual ProgramData implementation
	app := []string{"value1", "value2", "value3", "value4", "value5", "value6", "value7"}
	if len(app) > 0 {
		string := client["name"].(string)
		if matched, _ := regexp.MatchString(`^gribble|limnoria|supybot$`, string); matched {
			string = "supybot"
		}
		client["version"] = getVersion(string, app...)
		client["name-print"] = app[3]
		client["console-irc"] = app[4]
	}
	if matched, _ := regexp.MatchString(`^(bash|csh|fish|dash|sh|zsh)$`, client["name"].(string)); matched {
		client["name-print"] = "shell wrapper"
		client["console-irc"] = 1
	} else if client["name"] == "bitchx" {
		data := grabber(fmt.Sprintf("%s -v", client["name"]))
		string := awk(data, "Version")
		if string != "" {
			string = regexp.MustCompile(`[()]|bitchx-`).ReplaceAllString(string, "")
			data = strings.Fields(strings.ToLower(string))
			if data[1] == "version" {
				client["version"] = data[2]
			} else {
				client["version"] = data[1]
			}
		}
	} else if client["name"] == "hexchat" {
		if fileExists("~/.config/hexchat/hexchat.conf") {
			data := reader("~/.config/hexchat/hexchat.conf", "strip")
			client["version"] = awk(data, "version", 2, `\s*=\s*`)
		} else if fileExists("~/.config/hexchat/xchat.conf") {
			data := reader("~/.config/hexchat/xchat.conf", "strip")
			client["version"] = awk(data, "version", 2, `\s*=\s*`)
		}
		if client["version"] == "" {
			data := grabber(fmt.Sprintf("%s --version", client["name"]))
			client["version"] = awk(data, "hexchat", 2, `\s+`)
		}
		client["name-print"] = "HexChat"
	} else if client["name"] == "konversation" {
		if !client["native"].(bool) {
			client["konvi"] = 2
		} else {
			client["konvi"] = 1
		}
	} else if matched, _ := regexp.MatchString(`quassel`, client["name"].(string)); matched {
		data := grabber(fmt.Sprintf("%s -v", client["name"]))
		for _, line := range data {
			if strings.HasPrefix(line, "Quassel IRC:") {
				client["version"] = strings.Fields(line)[2]
				break
			} else if matched, _ := regexp.MatchString(`quassel\s[v]?[0-9]`, line); matched {
				client["version"] = strings.Fields(line)[1]
				break
			}
		}
		if client["version"] == "" {
			client["version"] = "(pre v0.4.1)?"
		}
	} else if matched, _ := regexp.MatchString(`^(perl.*|ksirc|dsirc)$`, client["name"].(string)); matched {
		cmdline := getCmdline()
		for _, cmd := range *cmdline {
			if matched, _ := regexp.MatchString(`dsirc`, cmd); matched {
				client["name"] = "ksirc"
				client["name-print"], client["version"] = getFull("ksirc")
			}
		}
		client["console-irc"] = 1
		perlPythonClient()
	} else if matched, _ := regexp.MatchString(`python`, client["name"].(string)); matched {
		perlPythonClient()
	} else {
		whitelist := `alacritty|altyo|\bate\b|black-screen|conhost|doas|evilvte|foot|germinal|guake|havoc|hyper|kate|kitty|kmscon|konsole|login|macwise|minicom|putty|rxvt|sakura|securecrt|shellinabox|^st$|sudo|term|tilda|tilix|tmux|tym|wayst|xiki|yaft|yakuake|\bzoc\b|ansible|chef|run-parts|slurm|sshd`
		if matched, _ := regexp.MatchString(whitelist, client["name"].(string)); matched {
			if matched, _ := regexp.MatchString(whitelist, client["name"].(string)); matched {
				setShellData()
			} else {
				client["name-print"] = client["name"]
			}
			bIrc = false
			useFilter = false
		} else {
			client["name-print"] = "Unknown Client: " + client["name"].(string)
		}
	}
	if bLog {
		string := fmt.Sprintf("namep: %s name: %s version: %s", client["name-print"], client["name"], client["version"])
		logData("data", string)
	}
	if bLog {
		eval(end)
	}
}

func getCmdline() *[]string {
	if bLog {
		eval(start)
	}
	cmdline := []string{}
	i := 0
	filePath := fmt.Sprintf("/proc/%s/cmdline", ppid)
	if !fileExists(filePath) {
		return &cmdline
	}
	file, err := os.Open(filePath)
	if err != nil {
		log.Printf("Open %s failed: %s", filePath, err)
		return &cmdline
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		for _, line := range strings.Split(scanner.Text(), "\x00") {
			if strings.HasPrefix(line, "-") {
				cmdline[i] += " " + line
			} else {
				cmdline = append(cmdline, line)
				i++
			}
		}
	}
	if bLog {
		logData("cmdline", fmt.Sprintf("cmdline: %v", cmdline))
		eval(end)
	}
	return &cmdline
}

func perlPythonClient() {
	if bLog {
		eval(start)
	}
	cmdline := getCmdline()
	for _, cmd := range *cmdline {
		cmd = strings.ToLower(cmd)
		if matched, _ := regexp.MatchString(`irssi`, cmd); matched {
			client["name"] = "irssi"
			break
		} else if matched, _ := regexp.MatchString(`weechat`, cmd); matched {
			client["name"] = "weechat"
			break
		} else if matched, _ := regexp.MatchString(`irc`, cmd); matched {
			client["name"] = "ircII"
			break
		} else if matched, _ := regexp.MatchString(`quassel`, cmd); matched {
			client["name"] = "quassel"
			break
		} else if matched, _ := regexp.MatchString(`pocoirc`, cmd); matched {
			client["name"] = "pocoirc"
			break
		} else if matched, _ := regexp.MatchString(`pyxis`, cmd); matched {
			client["name"] = "pyxis"
			break
		} else if matched, _ := regexp.MatchString(`eggdrop`, cmd); matched {
			client["name"] = "eggdrop"
			break
		}
	}
	if client["name"] != nil && client["name"] != "" {
		getClientVersion()
	} else {
		client["console-irc"] = 1
	}
	if bLog {
		eval(end)
	}
}

func checkModernKonvi() bool {
	if bLog {
		eval(start)
	}
	return false // Example implementation, replace with actual check logic
}

func setShellData() {
	// Example implementation, replace with actual logic
}

// Additional helper functions
func fileExists(path string) bool {
	_, err := os.Stat(path)
	return !os.IsNotExist(err)
}

func readLink(path string) string {
	link, err := os.Readlink(path)
	if err != nil {
		log.Fatalf("Error reading link: %v", err)
	}
	return link
}

func getVersion(app string, args ...string) string {
	// Implement the logic to get the version
	return "1.0.0"
}

func awk(data []string, pattern string, fields ...int) string {
	// Implement awk-like functionality
	return ""
}

func reader(path string, flag string) []string {
	// Implement file reader functionality
	return []string{}
}

func getFull(name string) (string, string) {
	// Implement logic to return full name and version
	return "", ""
}

func eval(code string) {
	// Implement logic to evaluate the code
}
