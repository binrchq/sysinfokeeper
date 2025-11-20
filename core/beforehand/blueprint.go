package beforehand

import (
	"bufio"
	"fmt"
	"os"
	"regexp"
	"strings"

	"binrc.com/sysinfokeeper/core/utils"
)

var (
	selfName      = "myprogram" //本身配置文件
	userConfigDir = "/path/to/user/config"
	line1         = "----"
	line3         = "===="
	systemFiles   = make(map[string]string)

	use    = make(map[string]int)
	force  = make(map[string]int)
	show   = make(map[string]string)
	colors = make(map[string]int)
	sep    = make(map[string]string)
	// size                       = make(map[string]int)
	cpuSleep                   float64
	dlTimeout                  int
	fakeDataDir                string
	filterString               string
	language                   string
	limit                      int
	outputType                 string
	psCount                    int
	sensorsCPU                 int
	sensorsExclude, sensorsUse []string
	wanURL                     string
	weatherSource, weatherUnit int
)

type Blueprint struct {
}

func NewBlueprint() *Blueprint {
	return &Blueprint{}
}

func (b *Blueprint) Set(show bool) bool {
	var (
		bFiles      bool
		key, val    string
		configFiles = []string{
			fmt.Sprintf("/etc/%s.conf", selfName),
			fmt.Sprintf("/etc/%s.d/%s.conf", selfName, selfName),
			fmt.Sprintf("/etc/%s.conf.d/%s.conf", selfName, selfName),
			fmt.Sprintf("/usr/etc/%s.conf", selfName),
			fmt.Sprintf("/usr/etc/%s.conf.d/%s.conf", selfName),
			fmt.Sprintf("/usr/local/etc/%s.conf", selfName),
			fmt.Sprintf("/usr/local/etc/%s.conf.d/%s.conf", selfName),
			fmt.Sprintf("%s/%s.conf", userConfigDir, selfName),
		}
	)

	for _, configFile := range configFiles {
		if _, err := os.Stat(configFile); os.IsNotExist(err) {
			continue
		}
		file, err := os.Open(configFile)
		if err != nil {
			continue
		}
		defer file.Close()

		var bConfigs bool
		bFiles = true
		if show {
			fmt.Printf("%sConfiguration file: %s\n", line1, configFile)
		}
		scanner := bufio.NewScanner(file)
		for scanner.Scan() {
			line := scanner.Text()
			line = strings.Split(line, "#")[0]
			line = strings.TrimSpace(line)
			line = strings.ReplaceAll(line, "'", "")
			line = strings.ReplaceAll(line, "\"", "")
			if len(line) == 0 {
				continue
			}
			parts := strings.SplitN(line, "=", 2)
			if len(parts) < 2 {
				continue
			}
			key = strings.TrimSpace(parts[0])
			val = strings.TrimSpace(parts[1])
			val = strings.ReplaceAll(val, "true", "1")
			val = strings.ReplaceAll(val, "false", "0")
			if !show {
				b.ProcessItem(key, val)
			} else {
				if !bConfigs {
					fmt.Println(line3)
				}
				fmt.Printf("%s=%s\n", key, val)
				bConfigs = true
			}
		}
		if err := scanner.Err(); err != nil {
			continue
		}
		if show && !bConfigs {
			fmt.Println("No configuration items found in file.")
		}
	}

	return bFiles
}

func (b *Blueprint) ProcessItem(key, val string) {
	valInt, isInt := utils.ToInt(val)
	valFloat, isFloat := utils.ToFloat(val)

	switch key {
	case "ALLOW_UPDATE", "B_ALLOW_UPDATE":
		if isInt {
			use["update"] = valInt
		}
	case "ALLOW_WEATHER", "B_ALLOW_WEATHER":
		if isInt {
			use["weather"] = valInt
		}
	case "CPU_SLEEP":
		if isFloat {
			cpuSleep = valFloat
		}
	case "DL_TIMEOUT":
		if isInt {
			dlTimeout = valInt
		}
	case "DOWNLOADER":
		if match, _ := regexp.MatchString(`^(curl|fetch|ftp|perl|wget)$`, val); match {
			// Handle the downloader selection
			// For example, reset the map and set the desired downloader
			use["downloader"] = valInt
		}
	case "FAKE_DATA_DIR":
		fakeDataDir = val
	case "FILTER_STRING":
		filterString = val
	case "LANGUAGE":
		if match, _ := regexp.MatchString(`^(en)$`, val); match {
			language = val
		}
	case "LIMIT":
		if isInt {
			limit = valInt
		}
	case "OUTPUT_TYPE":
		if match, _ := regexp.MatchString(`^(json|screen|xml)$`, val); match {
			outputType = val
		}
	case "NO_DIG":
		if isInt {
			force["no-dig"] = valInt
		}
	case "NO_DOAS":
		if isInt {
			force["no-doas"] = valInt
		}
	case "NO_HTML_WAN":
		if isInt {
			force["no-html-wan"] = valInt
		}
	case "NO_SUDO":
		if isInt {
			force["no-sudo"] = valInt
		}
	case "PARTITION_SORT":
		if match, _ := regexp.MatchString(`^(dev-base|fs|id|label|percent-used|size|uuid|used)$`, val); match {
			show["partition-sort"] = val
		}
	case "PS_COUNT":
		if isInt {
			psCount = valInt
		}
	case "SENSORS_CPU_NO":
		if isInt {
			sensorsCPU = valInt
		}
	case "SENSORS_EXCLUDE":
		if val != "" {
			sensorsExclude = strings.Split(val, ",")
		}
	case "SENSORS_USE":
		if val != "" {
			sensorsUse = strings.Split(val, ",")
		}
	case "SHOW_HOST", "B_SHOW_HOST":
		if isInt {
			show["host"] = val
			if valInt == 0 {
				force["no-host"] = 1
			}
		}
	case "USB_SYS":
		if isInt {
			force["usb-sys"] = valInt
		}
	case "WAN_IP_URL":
		if match, _ := regexp.MatchString(`^(ht|f)tp[s]?://`, val); match {
			wanURL = val
			force["no-dig"] = 1
		}
	case "WEATHER_SOURCE":
		if isInt {
			weatherSource = valInt
		}
	case "WEATHER_UNIT":
		valLower := strings.ToLower(val)
		if match, _ := regexp.MatchString(`^(c|f|cf|fc|i|m|im|mi)$`, valLower); match {
			unitMap := map[string]string{"c": "m", "f": "i", "cf": "mi", "fc": "im"}
			if newVal, ok := unitMap[valLower]; ok {
				weatherUnit, _ = utils.ToInt(newVal)
			}
		}
	case "CONSOLE_COLOR_SCHEME":
		if isInt {
			colors["console"] = valInt
		}
	case "GLOBAL_COLOR_SCHEME":
		if isInt {
			colors["global"] = valInt
		}
	case "IRC_COLOR_SCHEME":
		if isInt {
			colors["irc-gui"] = valInt
		}
	case "IRC_CONS_COLOR_SCHEME":
		if isInt {
			colors["irc-console"] = valInt
		}
	case "IRC_X_TERM_COLOR_SCHEME":
		if isInt {
			colors["irc-virt-term"] = valInt
		}
	case "VIRT_TERM_COLOR_SCHEME":
		if isInt {
			colors["virt-term"] = valInt
		}
	case "SEP1_IRC":
		sep["s1-irc"] = val
	case "SEP1_CONSOLE":
		sep["s1-console"] = val
	case "SEP2_IRC":
		sep["s2-irc"] = val
	case "SEP2_CONSOLE":
		sep["s2-console"] = val
	case "COLS_MAX_CONSOLE":
		if isInt {
			size["console"] = valInt
		}
	case "COLS_MAX_IRC":
		if isInt {
			size["irc"] = valInt
		}
	case "COLS_MAX_NO_DISPLAY":
		if isInt {
			size["no-display"] = valInt
		}
	case "INDENT":
		if isInt {
			size["indent"] = valInt
		}
	case "INDENTS":
		if isInt {
			filterString = val
		}
	case "LINES_MAX":
		if match, _ := regexp.MatchString(`^-?\d+$`, val); match {
			if valInt >= -1 {
				switch valInt {
				case 0:
					size["max-lines"] = size["term-lines"]
				case -1:
					use["output-block"] = 1
				default:
					size["max-lines"] = valInt
				}
			}
		}
	case "MAX_WRAP", "WRAP_MAX", "INDENT_MIN":
		if isInt {
			size["max-wrap"] = valInt
		}
	}
}
