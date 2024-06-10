package packages

type Cpu struct{}

func NewCpu() *Cpu {
	return &Cpu{}
}

func (c *Cpu) GetCpuInfo() (map[string]interface{}, error) {

	// shortOutput()
	// advancedOutput()
	// fullOutput()

	return nil, nil // 这里需要实现获取CPU信息的逻辑
}

func ShortData(){
	
}