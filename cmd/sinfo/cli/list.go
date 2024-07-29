package cli

import (
	"bitrec.ai/systemkeeper/core/constants"
	"bitrec.ai/systemkeeper/core/utils"

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
		utils.SuccessOutput(map[string]string{"version": constants.VERSION}, constants.VERSION, output)
	},
}
