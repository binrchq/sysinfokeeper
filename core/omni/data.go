package omni

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
	SystemFiles    map[string]string
	DmidecodeCmd   map[string]string
	usb            map[string]string
	windows        map[string]string
)

// // System Arrays
// var (
// 	cpuinfo        []string
// 	dmi            []string
// 	ifs            []string
// 	ifsBsd         []string
// 	paths          []string
// 	psAux          []string
// 	psCmd          []string
// 	sensorsExclude []string
// 	sensorsUse     []string
// 	uname          []string
// )

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
