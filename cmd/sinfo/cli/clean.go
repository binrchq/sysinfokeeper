package cli

import (
	"fmt"
	"os"
	"time"

	"binrc.com/sysinfokeeper/core/hardware"
	"binrc.com/sysinfokeeper/core/initialize"

	"github.com/spf13/cobra"
)

var cleanCmd = &cobra.Command{
	Use:   "clean",
	Short: "Clean database records",
	Long: `Clean hardware records from the database.
Supports various cleanup modes: all records, inactive records, old records, or by hardware type.`,
	Run: runClean,
}

func init() {
	rootCmd.AddCommand(cleanCmd)

	cleanCmd.Flags().BoolP("all", "a", false, "Clean all records")
	cleanCmd.Flags().BoolP("inactive", "i", false, "Clean only inactive (removed) records")
	cleanCmd.Flags().IntP("days", "d", 0, "Clean records older than specified days")
	cleanCmd.Flags().StringP("type", "t", "", "Clean records by hardware type (cpu, gpu, memory, disk, nic, fan)")
	cleanCmd.Flags().BoolP("dry-run", "n", false, "Dry run mode (show what would be deleted without actually deleting)")
	cleanCmd.Flags().StringVarP(&dbPath, "db", "", "", "Database file path (default: /var/lib/sysinfokeeper/hardware.db)")
}

func runClean(cmd *cobra.Command, args []string) {
	db, err := initialize.InitCDB()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: Failed to connect to database: %v\n", err)
		os.Exit(1)
	}

	storage := hardware.NewDBStorage(db)

	allFlag, _ := cmd.Flags().GetBool("all")
	inactiveFlag, _ := cmd.Flags().GetBool("inactive")
	days, _ := cmd.Flags().GetInt("days")
	typeFlag, _ := cmd.Flags().GetString("type")
	dryRun, _ := cmd.Flags().GetBool("dry-run")

	var deletedCount int64
	var err2 error

	if allFlag {
		if dryRun {
			count, _ := storage.GetRecordCount()
			fmt.Printf("Would delete %d records (all records)\n", count)
		} else {
			deletedCount, err2 = storage.CleanAllRecords()
			if err2 == nil {
				fmt.Printf("Deleted %d records (all records)\n", deletedCount)
			}
		}
	} else if inactiveFlag {
		if dryRun {
			count, _ := storage.GetInactiveRecordCount()
			fmt.Printf("Would delete %d inactive records\n", count)
		} else {
			deletedCount, err2 = storage.CleanInactiveRecords()
			if err2 == nil {
				fmt.Printf("Deleted %d inactive records\n", deletedCount)
			}
		}
	} else if days > 0 {
		cutoffDate := time.Now().AddDate(0, 0, -days)
		if dryRun {
			count, _ := storage.GetRecordCountBeforeDate(cutoffDate)
			fmt.Printf("Would delete %d records older than %d days (before %s)\n", count, days, cutoffDate.Format("2006-01-02 15:04:05"))
		} else {
			deletedCount, err2 = storage.CleanRecordsBeforeDate(cutoffDate)
			if err2 == nil {
				fmt.Printf("Deleted %d records older than %d days\n", deletedCount, days)
			}
		}
	} else if typeFlag != "" {
		validTypes := map[string]bool{
			"cpu": true, "gpu": true, "memory": true,
			"disk": true, "nic": true, "fan": true,
		}
		if !validTypes[typeFlag] {
			fmt.Fprintf(os.Stderr, "Error: Invalid hardware type '%s'. Valid types: cpu, gpu, memory, disk, nic, fan\n", typeFlag)
			os.Exit(1)
		}

		if dryRun {
			count, _ := storage.GetRecordCountByType(typeFlag)
			fmt.Printf("Would delete %d records of type '%s'\n", count, typeFlag)
		} else {
			deletedCount, err2 = storage.CleanRecordsByType(typeFlag)
			if err2 == nil {
				fmt.Printf("Deleted %d records of type '%s'\n", deletedCount, typeFlag)
			}
		}
	} else {
		retentionDays, err := storage.GetRetentionDays()
		if err != nil {
			retentionDays = 30
		}

		if dryRun {
			count, _ := storage.GetExpiredRemovedRecordCount(retentionDays)
			fmt.Printf("Would delete %d expired removed records (retention: %d days)\n", count, retentionDays)
		} else {
			deletedCount, err2 = storage.CleanOldRecords(retentionDays)
			if err2 == nil {
				fmt.Printf("Deleted %d expired removed records (retention: %d days)\n", deletedCount, retentionDays)
			}
		}
	}

	if err2 != nil {
		fmt.Fprintf(os.Stderr, "Error: Failed to clean records: %v\n", err2)
		os.Exit(1)
	}

	if !dryRun && deletedCount > 0 {
		totalCount, _ := storage.GetRecordCount()
		fmt.Printf("Total records remaining: %d\n", totalCount)
	}
}
