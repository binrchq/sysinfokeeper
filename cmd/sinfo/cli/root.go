package cli

import (
	"errors"
	"fmt"
	"os"
	"runtime"

	"bitrec.ai/systemkeeper/core/beforehand"
	"bitrec.ai/systemkeeper/core/constants"
	"bitrec.ai/systemkeeper/core/omni"

	"bitrec.ai/systemkeeper/configs"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var (
	cfgFile string
)

func init() {
	if len(os.Args) > 1 && (os.Args[1] == "version" || os.Args[1] == "completion") {
		return
	}
	cobra.OnInitialize(loadConfig)
	rootCmd.PersistentFlags().StringArrayP("target", "t", []string{}, "Target of System Information. Empty for all, 'cpu','gpu','memory', 'disk', 'network','mainboard','sensor','aduio','battery','usb','bluetooth','motherboard','process'")
	rootCmd.PersistentFlags().
		StringVarP(&cfgFile, "config", "c", "", "config file (default is /etc/dialer/config.toml)")
	rootCmd.PersistentFlags().
		StringP("output", "o", "", "Output format. Empty for human-readable,'toml', 'json', 'json-line' or 'yaml'")
	rootCmd.PersistentFlags().StringP("level", "l", "", "Output infomation level(3). Empty for basic, 'basic'.(1),'advanced'.(2),'full'.(3)")
	rootCmd.PersistentFlags().
		Bool("force", false, "Disable prompts and forces the execution")
	rootCmd.Flags().SortFlags = false
}

func loadConfig() {
	if cfgFile == "" {
		cfgFile = os.Getenv("DIALER_CONFIG")

	}
	if cfgFile == "" && omni.Mode == "dev" {
		cfgFile = constants.DEV_CONFIG_FILE
	}
	if cfgFile != "" {
		err := readCfg(cfgFile)
		if err != nil {
			log.Fatal().Caller().Err(err).Msgf("Error loading config file %s", cfgFile)
		}
	} else {
		log.Fatal().Caller().Err(errors.New("config file not found")).Msgf("Error loading config")
	}
	machineOutput := HasMachineOutputFlag()

	logLevel, err := zerolog.ParseLevel(omni.Config.Log.Level)
	if err != nil {
		logLevel = zerolog.DebugLevel
	}
	zerolog.SetGlobalLevel(logLevel)
	if machineOutput {
		zerolog.SetGlobalLevel(zerolog.Disabled)
	}
	if machineOutput {
		zerolog.SetGlobalLevel(zerolog.Disabled)
	}

	if omni.Config.Log.Format == constants.JSONLogFormat {
		log.Logger = log.Output(os.Stdout)
	}
	if runtime.GOOS != "linux" && runtime.GOOS != "darwin" && runtime.GOOS != "unix" {
		log.Fatal().Caller().Err(errors.New("os not support")).Msgf("dialer only support linux/unix and darwin")
	}

}
func readCfg(cfgPath string) error {
	v := viper.New()
	v.SetConfigFile(cfgPath)
	err := v.ReadInConfig()
	if err != nil {
		return err
	}
	conf := configs.NewConfig()
	if err := v.Unmarshal(&conf); err != nil {
		log.Fatal().Caller().Err(err).Msgf("Fatal error config file: Unmarshal failed")
		return err
	}
	omni.Config = conf
	return nil
}

var rootCmd = &cobra.Command{
	Use:   "sinfo",
	Short: "sinfo - a system information tool and keeper",
	Long: `
sinfo - a system information tool and keeper in the Linux/Unix system, can view hardware process network information, etc. 

https://dl.bitrec.ai/app/sinfo`, //在类Unix系统的系统信息获取工具和信息守护工具，可以查看硬件信息，进程信息，网络信息等
	Run: masterCmd,
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func masterCmd(cmd *cobra.Command, args []string) {
	targets, _ := cmd.Flags().GetStringArray("target")
	output, _ := cmd.Flags().GetString("output")
	beforeRun() // before hand

	fmt.Println(targets)
	SuccessOutput(map[string]string{"version": constants.VERSION}, constants.VERSION, output)
}

func beforeRun() {
	beforehand.SetPath()
	beforehand.SetUserPaths()
	beforehand.SetBasics()
	beforehand.SetSystemFiles()
	beforehand.SetOS()
	beforehand.NewBlueprint().Set(false)
	beforehand.SetDisplaySize()
}
