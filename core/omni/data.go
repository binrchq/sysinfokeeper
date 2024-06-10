package omni

// Self data
var (
	fakeDataDir    string
	selfPath       string
	userConfigDir  string
	userConfigFile string
	userDataDir    string
)

// Hashes
var (
	alerts         map[string]string
	buildProp      map[string]string
	client         map[string]interface{}
	colors         map[string]string
	cpuinfoMachine map[string]string
	comps          map[string]string
	disksBsd       map[string]string
	dboot          map[string]string
	devices        map[string]string
	dl             map[string]string
	dmmapper       map[string]string
	force          map[string]string
	loaded         map[string]string
	mapper         map[string]string
	programValues  map[string]string
	psData         map[string]string
	risc           map[string]string
	serviceTool    map[string]string
	show           map[string]string
	sysctl         map[string]string
	systemFiles    map[string]string
	usb            map[string]string
	windows        map[string]string
)

// System Arrays
var (
	cpuinfo        []string
	dmi            []string
	ifs            []string
	ifsBsd         []string
	paths          []string
	psAux          []string
	psCmd          []string
	sensorsExclude []string
	sensorsUse     []string
	uname          []string
)

// Disk/Logical/Partition/RAID arrays
var (
	btrfsRaid      []string
	glabel         []string
	labels         []string
	lsblk          []string
	lvm            []string
	lvmRaid        []string
	mdRaid         []string
	partitions     []string
	procPartitions []string
	rawLogical     []string
	softRaid       []string
	swaps          []string
	uuids          []string
	zfsRaid        []string
)

// Booleans
var (
	bAdmin   bool
	bAndroid bool
	bDisplay bool
	bIrc     bool
	bRoot    bool
)

// System
var (
	bsdType       string = ""
	deviceVm      string = ""
	language      string = ""
	os            string = ""
	pciTool       string = ""
	wanUrl        string
	bitsSys       string
	cpuArch       string
	ppid          int
	cpuSleep      float64 = 0.35
	dlTimeout     int     = 4
	limit         int     = 10
	psCount       int     = 5
	sensorsCpuNu  int     = 0
	weatherSource int     = 100
	weatherUnit   string  = "mi"
)

// Tools
var (
	display    string
	ftpAlt     string
	displayOpt string
	sudoAs     string
)
