package utils

import (
	"bytes"
	"encoding/csv"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"regexp"
	"sort"
	"strings"

	"github.com/TylerBrock/colorjson"
	"github.com/bitly/go-simplejson"
	"github.com/fatih/color"
	"github.com/pelletier/go-toml/v2"
	"github.com/pterm/pterm"
	"github.com/rs/zerolog/log"
	"gopkg.in/yaml.v3"
)

const (
	DateTimeFormat = "2006-01-02 15:04:05"
)

func SuccessOutput(result interface{}, override string, outputFormat string, failflag ...string) {
	errLabel := false
	if len(failflag) > 0 {
		errLabel = true
	}
	var jsonBytes []byte
	var err error
	switch outputFormat {
	case "csv":
		jsonBytes, err = jsonToCSV(result)
		if err != nil {
			log.Warn().Err(err).Msg("failed to csv output")
			jsonBytes, _ = json.Marshal(result)
			errLabel = true
		}
	case "json":
		jsonBytes, err = json.MarshalIndent(result, "", "\t")
		if err != nil {
			log.Warn().Err(err).Msg("failed to json unmarshal output")
			jsonBytes, _ = json.Marshal(result)
			errLabel = true
		}
	case "json-line":
		jsonBytes, err = json.Marshal(result)
		if err != nil {
			log.Warn().Err(err).Msg("failed to  json-line unmarshal output")
			jsonBytes, _ = json.Marshal(result)
			errLabel = true
		}
	case "toml":
		jsonBytes, err = toml.Marshal(result)
		if err != nil {
			log.Warn().Err(err).Msg("failed to toml unmarshal output")
			jsonBytes, _ = json.Marshal(result)
			errLabel = true
		}
	case "yaml":
		jsonBytes, err = yaml.Marshal(result)
		if err != nil {
			log.Warn().Err(err).Msg("failed to yaml unmarshal output")
			jsonBytes, _ = json.Marshal(result)
			errLabel = true
		}
	case "table":
		tableData, err := nodesToPtables(result)
		if err != nil {
			log.Warn().Err(err).Msg("failed to table output")
			jsonBytes, _ = json.Marshal(result)
			errLabel = true
		} else {
			tr := pterm.DefaultTable.WithHasHeader().WithData(tableData)
			if len(tableData) == 2 {
				tableData = transposeTableData(tableData)
				tr = pterm.DefaultTable.WithData(tableData).WithSeparator(" > ")
			}
			err = tr.Render()
			if err != nil {
				log.Warn().Err(err).Msg("failed to table output")
				errLabel = true
			} else {
				os.Exit(0)
				return
			}
		}
	default:
		jsonBytes, err = json.Marshal(result)
		if err == nil {
			js, err := simplejson.NewJson(jsonBytes)
			if err == nil {
				// 检查是否存在 "data" 键
				dataJS, ok := js.CheckGet("data")
				if ok {
					var parsedData ParsedData
					// 尝试解析 JSON 数据
					err := processJSON(dataJS, &parsedData)
					if err == nil {
						// 成功输出处理后的数据
						jsonData, err := json.Marshal(parsedData)
						if err != nil {
							log.Error().Err(err).Msg("Failed to marshal data to JSON")
							return
						}
						interfaceData := string(jsonData)
						SuccessOutput(interfaceData, "", "table")
					}
				}
				jsonBytes = []byte(js.Get("message").MustString())
				var parsedData ParsedData
				// 尝试解析 JSON 数据
				err := processJSON(js, &parsedData)
				if err == nil {
					// 成功输出处理后的数据
					jsonData, err := json.Marshal(parsedData)
					if err != nil {
						log.Error().Err(err).Msg("Failed to marshal data to JSON")
						return
					}
					interfaceData := string(jsonData)
					SuccessOutput(interfaceData, "", "table")
				}
			}
		}
	}

	//nolint
	if errLabel {
		fmt.Println(color.RedString(string(jsonBytes)))
		os.Exit(2)
	}
	fmt.Println(string(colorOutput(jsonBytes)))
	os.Exit(0)
}

func SuccessOutputl(message string, override string, outputFormat string) {
	type successOutput struct {
		Code    string `json:"code"`
		Message string `json:"message"`
	}
	SuccessOutput(successOutput{"0", message}, override, outputFormat)
}

func ErrorOutputl(errResult error, override string, outputFormat string) {
	type errOutput struct {
		Code    string `json:"code"`
		Message string `json:"message"`
	}
	SuccessOutput(errOutput{"-1", errResult.Error()}, override, outputFormat, "error")
}

// 处理 JSON 数据并填充 ParsedData
func processJSON(js *simplejson.Json, parsedData *ParsedData) error {
	// 判断是对象还是数组
	if arr, err := js.Array(); err == nil {
		// 数组
		if len(arr) > 0 {
			firstElem := js.GetIndex(0)
			keys := extractAndSortKeys(firstElem)
			parsedData.Title = keys

			for i := 0; i < len(arr); i++ {
				itemJS := js.GetIndex(i)
				values := make([]string, len(keys))
				for j, key := range keys {
					val := itemJS.Get(key)
					values[j] = fmt.Sprintf("%v", val.Interface())
				}
				parsedData.Items = append(parsedData.Items, values)
			}
		}
	} else {
		// 对象
		keys := extractAndSortKeys(js)
		parsedData.Title = keys

		values := make([]string, len(keys))
		for i, key := range keys {
			val := js.Get(key)
			values[i] = fmt.Sprintf("%v", val.Interface())
		}
		parsedData.Items = append(parsedData.Items, values)
	}

	return nil
}

// 提取键作为表头并排序
func extractAndSortKeys(js *simplejson.Json) []string {
	obj, err := js.Map()
	if err != nil {
		return nil
	}

	keys := make([]string, 0, len(obj))
	for k := range obj {
		keys = append(keys, k)
	}

	sort.SliceStable(keys, func(i, j int) bool {
		switch {
		case keys[i] == "id":
			return true
		case keys[j] == "id":
			return false
		case keys[i] == "message":
			return false
		case keys[j] == "message":
			return true
		default:
			return keys[i] < keys[j] // 按字母顺序排序
		}
	})

	return keys
}

func isFormatted(jsonBytes []byte) bool {
	// 检查是否有缩进和换行符
	return bytes.Contains(jsonBytes, []byte("\n")) && bytes.Contains(jsonBytes, []byte(" "))
}

func colorOutput(jsonBytes []byte) []byte {
	// 创建一个新的颜色格式化器
	f := colorjson.NewFormatter()
	if isFormatted(jsonBytes) {
		// 如果已经格式化展开，则保持格式化
		f.Indent = 3
	}
	// 尝试格式化带颜色的JSON
	var obj interface{}
	if err := json.Unmarshal(jsonBytes, &obj); err != nil {
		return jsonBytes
	}

	colorizedJSON, err := f.Marshal(obj)
	if err != nil {
		return jsonBytes
	}
	return colorizedJSON
}

type ParsedData struct {
	Title []string   `json:"title"`
	Items [][]string `json:"items"`
}

func jsonToCSV(result interface{}) ([]byte, error) {
	jsonString, ok := result.(string)
	if !ok {
		return []byte{}, errors.New("failed output to convert interface{} to string")
	}
	var parsedData ParsedData
	err := json.Unmarshal([]byte(jsonString), &parsedData)
	if err != nil {
		log.Warn().Msg("Failed Output to Unmarshal")
		return []byte{}, errors.New("failed output to Unmarshal")
	}
	// Create a buffer to collect the CSV data
	var buffer bytes.Buffer

	// Create a CSV writer that writes to the buffer
	writer := csv.NewWriter(&buffer)

	// Write the title (header) row
	if err := writer.Write(parsedData.Title); err != nil {
		return []byte{}, fmt.Errorf("failed to write title: %w", err)
	}

	// Write the data rows
	for _, item := range parsedData.Items {
		if err := writer.Write(item); err != nil {
			return []byte{}, fmt.Errorf("failed to write item: %w", err)
		}
	}

	writer.Flush()

	if err := writer.Error(); err != nil {
		return []byte{}, fmt.Errorf("error flushing writer: %w", err)
	}

	// Return the CSV data as a string
	return buffer.Bytes(), nil
}

func transposeTableData(data pterm.TableData) pterm.TableData {
	// Get the number of columns
	numCols := len(data[0])
	// Create a new table data structure with n*2 dimensions
	transposedData := make(pterm.TableData, numCols)
	for i := range transposedData {
		transposedData[i] = make([]string, 2)
	}

	// Fill the transposed data by swapping rows and columns
	for i := 0; i < 2; i++ {
		for j := 0; j < numCols; j++ {
			if i == 0 {
				transposedData[j][i] = color.BlueString(data[i][j])
			} else {
				if data[i][j] == "-" {
					transposedData[j][i] = "·"
				} else {
					transposedData[j][i] = data[i][j]
				}
			}
		}
	}

	return transposedData
}

func nodesToPtables(result interface{}) (pterm.TableData, error) {
	jsonString, ok := result.(string)
	if !ok {
		return [][]string{}, errors.New("failed output to convert interface{} to string")
	}

	var parsedData ParsedData
	err := json.Unmarshal([]byte(jsonString), &parsedData)
	if err != nil {
		return [][]string{}, errors.New("failed output to Unmarshal")
	}
	// Create a buffer to collect the CSV data
	titleInterfaces := make([]interface{}, len(parsedData.Title))
	for i, t := range parsedData.Title {
		titleInterfaces[i] = t
	}
	tableData := pterm.TableData{parsedData.Title}
	for _, item := range parsedData.Items {
		row := make([]string, len(item))
		for i, field := range item {
			if fmt.Sprintf("%v", field) == "" {
				row[i] = "-"
			} else {
				row[i] = highlightField(fmt.Sprintf("%v", field))
			}
		}
		tableData = append(tableData, row)
	}

	return tableData, nil
}

// StyleFunc is a function type that returns a string with ANSI escape codes.
type StyleFunc func(a ...interface{}) string

// Style wraps around StyleFunc to satisfy pterm.Style interface.
type Style struct {
	StyleFunc
}

// Sprint returns the styled string using the wrapped function.
func (s Style) Sprint(a ...interface{}) string {
	return s.StyleFunc(a...)
}

func highlightField(field string) string {
	// Define exact match color rules using a map
	exactMatchColorRules := map[string]Style{
		"ERROR":       {pterm.LightRed},
		"is required": {pterm.LightRed},
		"BREAK":       {pterm.LightRed},
		"-1":          {pterm.LightRed},
		"1":           {pterm.LightRed},
		"2":           {pterm.LightRed},
		"3":           {pterm.LightRed},
		"NO":          {pterm.LightRed},
		"FAIL":        {pterm.LightRed},
		"FALSE":       {pterm.LightRed},
		"NOT":         {pterm.LightRed},
		"OK":          {pterm.LightGreen},
		"0":           {pterm.LightGreen},
		"YES":         {pterm.LightGreen},
		"PASS":        {pterm.LightGreen},
		"SUCCESS":     {pterm.LightGreen},
		"DONE":        {pterm.LightGreen},
		"拨号成功":        {pterm.LightGreen},
		"INF":         {pterm.LightGreen},
		"cloud":       {pterm.LightBlue},
		"local":       {pterm.Gray},
	}

	// Define time format pattern
	// regexHighlightRules := map[*regexp.Regexp]Style{
	// 	regexp.MustCompile(`\b\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\b`):              {pterm.LightBlue}, // Alternate Timestamp pattern
	// 	regexp.MustCompile(`\b([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}\b`):               {pterm.LightBlue}, // MAC address pattern
	// 	regexp.MustCompile(`\bfe80::[0-9a-fA-F:]+\b`):                              {pterm.LightBlue}, // Specific IPv6 address pattern
	// 	regexp.MustCompile(`\b([0-9a-fA-F]{1,4}::?){1,7}[0-9a-fA-F]{1,4}\b`):       {pterm.LightBlue}, // General IPv6 address pattern
	// 	regexp.MustCompile(`\b\d+\.\d+\.\d+\.\d+\b`):                               {pterm.LightBlue}, // IPv4 address pattern
	// 	regexp.MustCompile(`\b\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+\d{2}:\d{2}\b`): {pterm.LightBlue}, // Timestamp pattern
	// 	regexp.MustCompile(`\b\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\b`):              {pterm.LightBlue}, // Alternate Timestamp pattern
	// }
	regexHighlightRules := []struct {
		Pattern *regexp.Regexp
		Style   Style
	}{
		{Pattern: regexp.MustCompile(`\b\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+\d{2}:\d{2}\b`), Style: Style{StyleFunc: pterm.LightBlue}}, // Timestamp pattern
		{Pattern: regexp.MustCompile(`\b\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\b`), Style: Style{StyleFunc: pterm.LightBlue}},              // Alternate Timestamp pattern
		{Pattern: regexp.MustCompile(`\b([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}\b`), Style: Style{StyleFunc: pterm.LightBlue}},               // MAC address pattern
		{Pattern: regexp.MustCompile(`\bfe80::[0-9a-fA-F:]+\b`), Style: Style{StyleFunc: pterm.LightBlue}},                              // Specific IPv6 address pattern
		{Pattern: regexp.MustCompile(`\b([0-9a-fA-F]{1,4}::?){1,7}[0-9a-fA-F]{1,4}\b`), Style: Style{StyleFunc: pterm.LightBlue}},       // General IPv6 address pattern
		{Pattern: regexp.MustCompile(`\b\d+\.\d+\.\d+\.\d+\b`), Style: Style{StyleFunc: pterm.LightBlue}},                               // IPv4 address pattern
	}

	// Define substring match rules for highlighting just the substring
	substringHighlightRules := map[string]Style{
		"INF":       {pterm.Green},
		"WAR":       {pterm.LightYellow},
		"ERR":       {pterm.LightRed},
		"v4:":       {pterm.LightRed},
		"OK":        {pterm.LightGreen},
		"DBG":       {pterm.LightYellow},
		"succeeded": {pterm.Green},
		"failed":    {pterm.LightRed},
	}

	// Define substring match rules for highlighting the entire field
	substringFullHighlightRules := map[string]Style{
		"失败": {pterm.LightRed},
		"错误": {pterm.LightRed},
		"成功": {pterm.Green},
	}
	// Check for exact match
	if color, exists := exactMatchColorRules[field]; exists {
		return color.Sprint(field)
	}

	// Apply regex matches and highlight matched substrings
	for _, rule := range regexHighlightRules {
		matches := rule.Pattern.FindAllStringIndex(field, -1)
		if matches != nil {
			// Reverse the slice to replace from end to start to keep the index valid.
			for i := len(matches) - 1; i >= 0; i-- {
				startIndex := matches[i][0]
				endIndex := matches[i][1]
				field = field[:startIndex] + rule.Style.Sprint(field[startIndex:endIndex]) + field[endIndex:]
			}
		}
	}

	// Check for full field highlight based on substring match
	for substr, color := range substringFullHighlightRules {
		if strings.Contains(field, substr) {
			return color.Sprint(field)
		}
	}

	// Check for partial highlight based on substring match
	for substr, color := range substringHighlightRules {
		if strings.Contains(field, substr) {
			field = strings.ReplaceAll(field, substr, color.Sprint(substr))
		}
	}

	return field
}

func HasMachineOutputFlag() bool {
	for _, arg := range os.Args {
		if arg == "json" || arg == "json-line" || arg == "yaml" {
			return true
		}
	}

	return false
}
