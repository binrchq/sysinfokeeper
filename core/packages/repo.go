package packages

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

type Repo struct{}

func NewRepo() *Repo {
	return &Repo{}
}

type RepoInfo struct {
	Name        string `json:"name"`        // 仓库名称
	URL         string `json:"url"`         // 仓库URL
	Type        string `json:"type"`        // 类型 (deb/deb-src/rpm等)
	Components  string `json:"components"`  // 组件 (main/restricted/universe等)
	Enabled     bool   `json:"enabled"`     // 是否启用
	Arch        string `json:"arch"`        // 架构
	Description string `json:"description"` // 描述
}

type RepoModel struct {
	RepoInfos []RepoInfo `json:"repo_infos"`
	Msg       string     `json:"msg"`
}

func NewRepoModel() *RepoModel {
	return &RepoModel{}
}

func (r *Repo) Get() (*RepoModel, error) {
	model := NewRepoModel()

	// 检测包管理器类型
	if r.isApt() {
		repos, err := r.gatherAptRepos()
		if err != nil {
			model.Msg = err.Error()
			return model, err
		}
		model.RepoInfos = repos
	} else if r.isYum() || r.isDnf() {
		repos, err := r.gatherYumRepos()
		if err != nil {
			model.Msg = err.Error()
			return model, err
		}
		model.RepoInfos = repos
	} else {
		model.Msg = "Unsupported package manager"
	}

	return model, nil
}

func (r *Repo) isApt() bool {
	_, err := exec.LookPath("apt")
	return err == nil
}

func (r *Repo) isYum() bool {
	_, err := exec.LookPath("yum")
	return err == nil
}

func (r *Repo) isDnf() bool {
	_, err := exec.LookPath("dnf")
	return err == nil
}

func (r *Repo) gatherAptRepos() ([]RepoInfo, error) {
	var repos []RepoInfo

	// 读取 /etc/apt/sources.list
	sourcesList := "/etc/apt/sources.list"
	if file, err := os.Open(sourcesList); err == nil {
		defer file.Close()
		scanner := bufio.NewScanner(file)
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if repo := r.parseAptLine(line); repo != nil {
				repos = append(repos, *repo)
			}
		}
	}

	// 读取 /etc/apt/sources.list.d/ 目录下的文件
	sourcesListDir := "/etc/apt/sources.list.d"
	if entries, err := os.ReadDir(sourcesListDir); err == nil {
		for _, entry := range entries {
			if strings.HasSuffix(entry.Name(), ".list") {
				filePath := fmt.Sprintf("%s/%s", sourcesListDir, entry.Name())
				if file, err := os.Open(filePath); err == nil {
					scanner := bufio.NewScanner(file)
					for scanner.Scan() {
						line := strings.TrimSpace(scanner.Text())
						if repo := r.parseAptLine(line); repo != nil {
							repos = append(repos, *repo)
						}
					}
					file.Close()
				}
			}
		}
	}

	return repos, nil
}

func (r *Repo) parseAptLine(line string) *RepoInfo {
	// 跳过注释和空行
	if strings.HasPrefix(line, "#") || line == "" {
		return nil
	}

	fields := strings.Fields(line)
	if len(fields) < 3 {
		return nil
	}

	repo := &RepoInfo{
		Enabled: true,
	}

	// 第一个字段是类型
	repo.Type = fields[0]

	// 第二个字段是URL
	repo.URL = fields[1]

	// 剩余字段是组件
	if len(fields) > 2 {
		components := fields[2:]
		repo.Components = strings.Join(components, " ")
	}

	// 从URL提取名称
	if strings.Contains(repo.URL, "://") {
		parts := strings.Split(repo.URL, "://")
		if len(parts) > 1 {
			host := strings.Split(parts[1], "/")[0]
			repo.Name = host
		}
	} else {
		repo.Name = repo.URL
	}

	return repo
}

func (r *Repo) gatherYumRepos() ([]RepoInfo, error) {
	var repos []RepoInfo

	// 使用 yum repolist 或 dnf repolist 获取仓库信息
	var cmd *exec.Cmd
	if r.isDnf() {
		cmd = exec.Command("dnf", "repolist", "-v")
	} else {
		cmd = exec.Command("yum", "repolist", "-v")
	}

	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to get repo list: %w", err)
	}

	lines := strings.Split(string(output), "\n")
	var currentRepo *RepoInfo

	for _, line := range lines {
		line = strings.TrimSpace(line)

		if strings.HasPrefix(line, "Repo-id") {
			if currentRepo != nil {
				repos = append(repos, *currentRepo)
			}
			currentRepo = &RepoInfo{
				Enabled: true,
				Type:    "rpm",
			}
			// 提取仓库ID
			parts := strings.Split(line, ":")
			if len(parts) > 1 {
				currentRepo.Name = strings.TrimSpace(parts[1])
			}
		} else if currentRepo != nil {
			if strings.HasPrefix(line, "Repo-name") {
				parts := strings.Split(line, ":")
				if len(parts) > 1 {
					currentRepo.Description = strings.TrimSpace(parts[1])
				}
			} else if strings.HasPrefix(line, "Repo-baseurl") {
				parts := strings.Split(line, ":")
				if len(parts) > 1 {
					currentRepo.URL = strings.TrimSpace(strings.Join(parts[1:], ":"))
				}
			} else if strings.HasPrefix(line, "Repo-enabled") {
				parts := strings.Split(line, ":")
				if len(parts) > 1 {
					enabled := strings.TrimSpace(parts[1])
					currentRepo.Enabled = (enabled == "1" || strings.ToLower(enabled) == "yes")
				}
			}
		}
	}

	if currentRepo != nil {
		repos = append(repos, *currentRepo)
	}

	return repos, nil
}
