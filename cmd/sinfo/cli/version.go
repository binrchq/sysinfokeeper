package cli

import (
	"bitrec.ai/systemkeeper/core/constants"
	"bitrec.ai/systemkeeper/core/utils"

	"github.com/spf13/cobra"
)

func init() {
	rootCmd.AddCommand(versionCmd)
}

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print the version.",
	Long:  "The version of headscale.",
	Run: func(cmd *cobra.Command, args []string) {
		output, _ := cmd.Flags().GetString("output")
		utils.SuccessOutput(map[string]string{"version": constants.VERSION}, constants.VERSION, output)
	},
}
