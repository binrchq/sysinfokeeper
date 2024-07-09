package utils

// Contains checks if a slice contains a given string
func ContainsAll(slice []string, items []string) bool {
	itemMap := make(map[string]bool)
	for _, s := range slice {
		itemMap[s] = true
	}
	for _, item := range items {
		if !itemMap[item] {
			return false
		}
	}
	return true
}
