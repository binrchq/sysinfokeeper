package omni

// Debuggers
var (
	debugger   = map[string]int{"level": 0}
	dbg        []string
	fake       = make(map[string]string)
	t0         []string
	bHires     bool
	bLog       bool
	bLogColors bool
	bLogFull   bool
	end        string
	start      string
	fhL        string // log file handle
	logFile    string // log file
	t1         int    = 0
	t2         int    = 0
	t3         int    = 0
)

// Client
func init() {
	// Example usage
	bHires = true
	bLog = false
	bLogColors = true
	bLogFull = false
	end = "endLog"
	start = "startLog"
	fhL = "fileHandle"
	logFile = "log.txt"
	t1 = 1
	t2 = 2
	t3 = 3

	// Initializing and using the debugger map
	debugger["sys"] = 1
	client["test-konvi"] = 0
}
