package cli

import (
	"bitrec.ai/dialmainer/core/constants"
	"github.com/spf13/cobra"
)

func init() {
	rootCmd.AddCommand(listCmd)
}

var listCmd = &cobra.Command{
	Use:   "list",
	Short: "Print the dial info list.",
	Long:  "The dial info list of dialer.",
	Run: func(cmd *cobra.Command, args []string) {
		output, _ := cmd.Flags().GetString("output")
		SuccessOutput(map[string]string{"version": constants.VERSION}, constants.VERSION, output)
	},
}
