package handlers

import (
	"fmt"
	"os/exec"
	"regexp"
	"strings"
)

// 定义全局变量和常量
var (
	// bLog     = false
	psData = make(map[string][]string)
	psCmd  []string
	// loaded   = make(map[string]bool)
	// client   = make(map[string]int)
	dBg      = make(map[int]bool)
	show     = make(map[string]bool)
	extra    = 0
	selfName = "inxi"
	startLog = func() { fmt.Println("Start logging...") }
	endLog   = func() { fmt.Println("End logging...") }
)

type PsData struct{}

func NewPsData() *PsData {
	return &PsData{}
}

// Set 方法
func (p PsData) Set() {
	if bLog {
		startLog()
	}
	var bBusybox bool
	args := "wwaux"
	path, err := exec.LookPath("ps")
	if err != nil {
		fmt.Println("ps command not found")
		return
	}
	link, err := exec.Command("readlink", path).Output()
	if err == nil && strings.Contains(strings.ToLower(string(link)), "busybox") {
		bBusybox = true
		args = ""
	}
	psOutput, err := exec.Command(path, args).Output()
	if err != nil {
		return
	}
	psLines := strings.Split(string(psOutput), "\n")
	if len(psLines) == 0 {
		return
	}
	header := psLines[0]
	psLines = psLines[1:]
	temp := strings.Fields(header)
	psData["header"] = []string{fmt.Sprintf("%d", len(temp)-1)}
	for i, col := range temp {
		switch col {
		case "PID":
			psData["header"] = append(psData["header"], fmt.Sprintf("%d", i))
		case "%CPU":
			psData["header"] = append(psData["header"], fmt.Sprintf("%d", i))
		case "%MEM":
			psData["header"] = append(psData["header"], fmt.Sprintf("%d", i))
		case "RSS":
			psData["header"] = append(psData["header"], fmt.Sprintf("%d", i))
		}
	}
	colsUse := 2
	if bBusybox {
		colsUse = 7
	}
	pattern := `brave|chrom(e|ium)|falkon|(fire|water)fox|gvfs|konqueror|mariadb|midori|mysql|openvpn|opera|pale|postgre|php|qtwebengine|smtp|vivald`
	for _, line := range psLines {
		if line == "" {
			continue
		}
		if selfName == "inxi" && strings.Contains(line, "/"+selfName) {
			continue
		}
		psCmd = append(psCmd, line)
		split := strings.Fields(line)
		final := len(split) - 1
		if final > len(temp)+colsUse {
			final = len(temp) + colsUse
		}
		if len(split) < len(temp) {
			continue
		}
		match, _ := regexp.MatchString(`^\[(mld|nfsd)\]`, split[len(temp)])
		if match {
			split[len(temp)] = strings.TrimPrefix(split[len(temp)], "[")
			split[len(temp)] = strings.TrimSuffix(split[len(temp)], "]")
		}
		if matched, _ := regexp.MatchString(`^([\[\(]|(\S+\/|)(`+pattern+`))`, split[len(temp)]); !matched {
			psCmd = append(psCmd, strings.Join(split[len(temp):final+1], " "))
		}
	}
	psCmd = uniq(psCmd)
	if bLog {
		endLog()
	}
}

// SetDm 方法
func (p PsData) SetDm() {
	if bLog {
		startLog()
	}
	processItems(&psData["dm-active"], `ly|startx|xinit`)
	if bLog {
		endLog()
	}
}

// SetDeWm 方法
func (p PsData) SetDeWm() {
	if bLog {
		startLog()
	}
	loaded["ps-gui"] = true
	bDeWmComp, bWmComp := false, false
	if show["system"] {
		processItems(&psData["de-ps-detect"], `razor-desktop|razor-session|lxsession|lxqt-session|nscde|tdelauncher|tdeinit_phase1`)
		processItems(&psData["wm-parent"], `xfdesktop|icewm|fluxbox|blackbox`)
		processItems(&psData["wm-main"], `2bwm|9wm|afterstep|aewm|aewm\+\+|amiwm|antiwm|awesome|bspwm|calmwm|catwm|cde|clfswm|ctwm|openbsd-cwm|dawn|dtwm|dusk|dwm|echinus|evilwm|flwm|flwm_topside|fvwm.*-crystal\S*|fvwm1|fvwm2|fvwm3|fvwm95|fvwm|hackedbox|herbstluftwm|i3|instantwm|ion3|jbwm|jwm|larswm|leftwm|lwm|matchbox-window-manager|mcwm|mini|miwm|mlvwm|monsterwm|musca|mvwm|mwm|nawm|notion|openbox|nscde|pekwm|penrose|qvwm|ratpoison|sapphire|sawfish|scrotwm|snapwm|spectrwm|stumpwm|subtle|tinywm|tvtwm|twm|uwm|vtwm|windowlab|[wW]indo[mM]aker|w9wm|wingo|wm2|wmfs|wmfs2|wmii2|wmii|wmx|x9wm|xmonad|yeahwm`)
		bWmComp = true
		bDeWmComp = extra > 1
	}
	if show["graphic"] {
		bDeWmComp, bWmComp = true, true
		processItems(&psData["compositors-pure"], `cairo|compton|dcompmgr|mcompositor|picom|steamcompmgr|surfaceflinger|xcompmgr|unagi`)
	}
	if bDeWmComp {
		processItems(&psData["de-wm-compositors"], `budgie-wm|compiz|deepin-kwin_wayland|deepin-kwin_x11|deepin-wm|enlightenment|gala|gnome-shell|twin|kwin_wayland|kwin_x11|kwinft|kwin|marco|deepin-metacity|metacity|metisse|mir|moksha|muffin|deepin-mutter|mutter|ukwm|xfwm[345]?`)
	}
	if bWmComp {
		processItems(&psData["wm-compositors"], `3dwm|asc|awc|bismuth|cage|cagebreak|cardboard|chameleonwm|clayland|comfc|dwl|dwc|epd-wm|fireplace|feathers|fenestra|glass|gamescope|greenfield|grefson|hikari|hopalong|[Hh]yprland|inaban|japokwm|kiwmi|labwc|laikawm|lipstick|liri|mahogany|marina|maze|maynard|motorcar|newm|nucleus|orbital|orbment|perceptia|phoc|polonium|pywm|qtile|river|rootston|rustland|simulavr|skylight|smithay|sommelier|sway|swayfx|swc|swvkc|tabby|taiwins|tinybox|tinywl|trinkster|velox|vimway|vivarium|wavy|waybox|way-cooler|wayfire|wayhouse|waymonad|westeros|westford|weston|wio\+?|wxrc|xuake`)
	}
	if show["system"] && extra > 2 {
		processItems(&psData["components-active"], `albert|alltray|awesomebar|awn|bar|barpanel|bbdock|bbpager|bemenu|bipolarbar|bmpanel|bmpanel2|budgie-panel|cairo-dock|dde-dock|deskmenu|dmenu(-wayland)?|dockbarx|docker|docky|dzen|dzen2|fbpanel|fspanel|fuzzel|glx-dock|gnome-panel|hpanel|i3bar|i3-status(-rs|-rust)?|icewmtray|jgmenu|kdocker|kicker|krunner|ksmoothdock|latte|lavalauncher|latte-dock|lemonbar|ltpanel|luastatus|lxpanel|lxqt-panel|matchbox-panel|mate-panel|mauncher|mopag|nwg-(bar|dock|launchers|panel)|openbox-menu|ourico|perlpanel|plank|polybar|pypanel|razor(qt)?-panel|rofi|rootbar|sfwbar|simplepanel|sirula|some_sorta_bar|stalonetray|swaybar|taffybar|taskbar|tint2|tofi|trayer|ukui-panel|vala-panel|wapanel|waybar|wbar|wharf|wingpanel|witray|wldash|wmdocker|wmsystemtray|wofi|xfce[45]?-panel|xmobar|yambar|yabar|yofi`)
		psData["tools-test"] = []string{"away", "boinc-screensaver", "budgie-screensaver", "cinnamon-screensaver", "gnome-screensaver", "gsd-screensaver-proxy", "gtklock", "hyprlock", "i3lock", "kscreenlocker", "light-locker", "lockscreen", "lxlock", "mate-screensaver", "nwg-lock", "physlock", "rss-glx", "slock", "swayidle", "swaylock", "ukui-screensaver", "unicode-screensaver", "xautolock", "xfce4-screensaver", "xlock", "xlockmore", "xscreensaver", "xscreensaver-systemd", "xsecurelock", "xss-lock", "xtrlock"}
		processItems(&psData["tools-active"], strings.Join(psData["tools-test"], "|"))
	}
	if dBg[63] {
		fmt.Printf("Debugging ps de-wm: %v\n", psData)
	}
	if bLog {
		endLog()
	}
}

// SetNetwork 方法
func (p PsData) SetNetwork() {
	if bLog {
		startLog()
	}
	processItems(&psData["network-services"], `apache\d?|cC]onn[mM]and?|dhcpd|dhcpleased|fingerd|ftpd|gated|httpd|inetd|ircd|iwd|mld|[mM]odem[mM]nager|named|networkd-dispatcher|[nN]etwork[mM]anager|nfsd|nginx|ntpd|proftpd|routed|smbd|sshd|systemd-networkd|systemd-timesyncd|tftpd|wicd|wpa_supplicant|xinetd|xntpd`)
	if bLog {
		endLog()
	}
}

// SetPower 方法
func (p PsData) SetPower() {
	if bLog {
		startLog()
	}
	processItems(&psData["power-services"], `apmd|csd-power|gnome-power-manager|gsd-power|kpowersave|org\.dracolinux\.power|org_kde_powerdevil|mate-power-manager|power-profiles-daemon|powersaved|tdepowersave|thermald|tlp|upowerd|ukui-power-manager|xfce4-power-manager`)
	if bLog {
		endLog()
	}
}

// processItems 函数
func processItems(items *[]string, pattern string) {
	re := regexp.MustCompile(`^(\/\S+?\/(c?lisp|perl|python|[a-z]{0,3}sh)\s+)?(|\S*?\/)` + pattern + `(:|\s|$)`)
	for _, cmd := range psCmd {
		if re.MatchString(cmd) {
			matches := re.FindStringSubmatch(cmd)
			if len(matches) > 4 {
				*items = append(*items, matches[4])
			}
		}
	}
	*items = uniq(*items)
}

// 去重函数
func uniq(slice []string) []string {
	keys := make(map[string]bool)
	list := []string{}
	for _, entry := range slice {
		if _, value := keys[entry]; !value {
			keys[entry] = true
			list = append(list, entry)
		}
	}
	return list
}
