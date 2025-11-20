package cli

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"binrc.com/sysinfokeeper/core/hardware"
	"binrc.com/sysinfokeeper/core/initialize"

	"github.com/spf13/cobra"
)

var serveCmd = &cobra.Command{
	Use:   "serve",
	Short: "Run hardware monitoring service (periodic hardware info collection)",
	Long: `Run hardware monitoring service that periodically collects hardware information and saves to database.
Service will run continuously until stopped with Ctrl+C.`,
	Run: runServe,
}

func init() {
	rootCmd.AddCommand(serveCmd)
	serveCmd.Flags().IntP("interval", "i", 3600, "Check interval in seconds (default: 3600, 1 hour)")
	serveCmd.Flags().IntP("retention", "r", 30, "Data retention days (default: 30)")
	serveCmd.Flags().StringP("speed-test", "s", "low", "Disk speed test mode: none (skip test), low (10MB, fast), high (1GB, accurate but slow). Default: low")
}

func runServe(cmd *cobra.Command, args []string) {
	fmt.Println("Starting hardware monitoring service...")

	// Initialize database
	db, err := initialize.InitCDB()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: Failed to initialize database: %v\n", err)
		os.Exit(1)
	}

	// Create scheduler
	scheduler := hardware.NewScheduler(db)

	// Set retention days
	retentionDays, _ := cmd.Flags().GetInt("retention")
	storage := hardware.NewDBStorage(db)
	if err := storage.SetRetentionDays(retentionDays); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: Failed to set retention days: %v\n", err)
	} else {
		fmt.Printf("Data retention set to: %d days\n", retentionDays)
	}

	// Set check interval
	interval, _ := cmd.Flags().GetInt("interval")
	if interval > 0 {
		scheduler.SetInterval(time.Duration(interval) * time.Second)
		fmt.Printf("Check interval set to: %d seconds\n", interval)
	}

	// Set speed test mode
	speedTestMode, _ := cmd.Flags().GetString("speed-test")
	validModes := map[string]bool{"none": true, "low": true, "high": true}
	if !validModes[speedTestMode] {
		fmt.Fprintf(os.Stderr, "Warning: Invalid speed-test mode '%s', using 'low'\n", speedTestMode)
		speedTestMode = "low"
	}
	scheduler.SetSpeedTestMode(speedTestMode)
	fmt.Printf("Disk speed test mode: %s\n", speedTestMode)
	if speedTestMode == "low" {
		fmt.Println("  (Low consumption: 10MB test, fast, minimal impact on business)")
	} else if speedTestMode == "high" {
		fmt.Println("  (High consumption: 1GB test, accurate but may impact business)")
	} else {
		fmt.Println("  (Speed test disabled)")
	}

	// Start scheduler
	if err := scheduler.Start(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: Failed to start scheduler: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Hardware monitoring service started. Press Ctrl+C to stop...")

	// Wait for stop signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	<-sigChan

	fmt.Println("\nStopping service...")
	scheduler.Stop()
	fmt.Println("Service stopped")
}
