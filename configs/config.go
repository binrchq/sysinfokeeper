package configs

type Config struct {
	Title  string        `mapstructure:"title"`
	Api    *ApiConfig    `mapstructure:"api"`
	Log    *LogConfig    `mapstructure:"log"`
	ApiKey *ApiKeyConfig `mapstructure:"apikey"`
}

func NewConfig() *Config {
	return &Config{}
}

type ApiConfig struct {
	GinMode string `mapstructure:"gin_mode"`
	Host    string `mapstructure:"host"`
	Port    string `mapstructure:"port"`
}

type LogConfig struct {
	Format string `mapstructure:"format"`
	Level  string `mapstructure:"level"`
}

type ApiKeyConfig struct {
	Prefix string `mapstructure:"prefix"`
	Key    string `mapstructure:"key"`
}
