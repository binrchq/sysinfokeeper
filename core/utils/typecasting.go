package utils

import "strconv"

func BoolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

func ByteSliceToString(ca []int8) string {
	s := make([]byte, len(ca))
	for i, v := range ca {
		if v == 0 {
			s = s[:i]
			break
		}
		s[i] = byte(v)
	}
	return string(s)
}

func ToInt(val string) (int, bool) {
	i, err := strconv.Atoi(val)
	if err != nil {
		return 0, false
	}
	return i, true
}

func ToFloat(val string) (float64, bool) {
	f, err := strconv.ParseFloat(val, 64)
	if err != nil {
		return 0, false
	}
	return f, true
}
