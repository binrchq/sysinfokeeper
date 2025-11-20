package cli

import (
	"fmt"
	"os"

	"binrc.com/sysinfokeeper/core/hardware"
	"binrc.com/sysinfokeeper/core/initialize"

	"github.com/spf13/cobra"
)

var (
	retentionDaysToSet int
	retentionShowOnly  bool
)

func init() {
	rootCmd.AddCommand(retentionCmd)
	retentionCmd.Flags().IntVar(&retentionDaysToSet, "set", 0, "Set retention days (e.g. --set 30)")
	retentionCmd.Flags().BoolVar(&retentionShowOnly, "show", false, "Only show current retention days")
}

var retentionCmd = &cobra.Command{
	Use:   "retention",
	Short: "Show or update hardware change retention days",
	Long: `Displays or updates the retention period (in days) for hardware change history.

By default the system keeps removed hardware records for 30 days.
Use --set to update the retention period and --show to display the current value.`,
	Run: runRetention,
}

func runRetention(cmd *cobra.Command, args []string) {
	db, err := initialize.InitCDB()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: Failed to connect to database: %v\n", err)
		os.Exit(1)
	}

	storage := hardware.NewDBStorage(db)

	if retentionDaysToSet > 0 {
		if retentionDaysToSet < 1 {
			fmt.Fprintln(os.Stderr, "Error: retention days must be greater than 0")
			os.Exit(1)
		}
		if err := storage.SetRetentionDays(retentionDaysToSet); err != nil {
			fmt.Fprintf(os.Stderr, "Error: Failed to set retention days: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("Retention days updated to %d\n", retentionDaysToSet)
	}

	if retentionDaysToSet == 0 || retentionShowOnly {
		days, err := storage.GetRetentionDays()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Warning: Failed to load retention days, defaulting to 30: %v\n", err)
			days = 30
		}
		fmt.Printf("Current retention days: %d\n", days)
	}
}
