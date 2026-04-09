package main

import (
	"bufio"
	"bytes"
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/BurntSushi/toml"
	"github.com/TinorNoah/QEST/internal/assets"
	embeddedmanifests "github.com/TinorNoah/QEST/manifests"
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"golang.org/x/term"
)

type appConfig struct {
	dryRun            bool
	yes               bool
	noGum             bool
	validateManifests bool
}

type systemInfo struct {
	osID   string
	osLike []string
	arch   string
	home   string
}

type toolManifest struct {
	ID               string            `toml:"id"`
	Category         string            `toml:"category"`
	Tier             string            `toml:"tier"`
	ValidationStatus string            `toml:"validation_status"`
	InstallSource    map[string]string `toml:"install_source"`
	PackageName      map[string]string `toml:"package_name"`
	BinaryNames      []string          `toml:"binary_names"`
	Notes            string            `toml:"notes"`
}

type selection struct {
	profile      string
	categories   map[string]bool
	dotfilesMode string
	dotfilesRepo string
}

type phaseResult struct {
	name   string
	status string
	err    error
}

type installer struct {
	cfg       appConfig
	sys       systemInfo
	tools     []toolManifest
	selection selection
	logger    func(string)
}

var errUserCancelled = errors.New("installer cancelled")

func main() {
	cfg := parseFlags()

	if cfg.validateManifests {
		tools, err := loadToolManifests("manifests/tools")
		if err != nil {
			fatalf("failed to load tool manifests: %v", err)
		}
		fmt.Printf("validated %d tool manifests\n", len(tools))
		return
	}

	sys, err := detectSystem()
	if err != nil {
		fatalf("%v", err)
	}

	tools, err := loadToolManifests("manifests/tools")
	if err != nil {
		fatalf("failed to load tool manifests: %v", err)
	}
	sel, err := chooseSelection(cfg, sys, tools)
	if err != nil {
		if errors.Is(err, errUserCancelled) {
			fmt.Println("qest: installer cancelled")
			return
		}
		fatalf("%v", err)
	}

	inst := installer{
		cfg:       cfg,
		sys:       sys,
		tools:     tools,
		selection: sel,
		logger: func(msg string) {
			fmt.Println(msg)
		},
	}

	if isInteractive(cfg) {
		if err := runInteractiveInstaller(inst); err != nil {
			fatalf("install failed: %v", err)
		}
		return
	}

	if err := runInstaller(context.Background(), &inst); err != nil {
		fatalf("install failed: %v", err)
	}
}

func parseFlags() appConfig {
	var cfg appConfig
	flag.BoolVar(&cfg.dryRun, "dry-run", false, "Preview commands without mutating system")
	flag.BoolVar(&cfg.yes, "yes", false, "Non-interactive mode")
	flag.BoolVar(&cfg.yes, "y", false, "Non-interactive mode")
	flag.BoolVar(&cfg.noGum, "no-gum", false, "Disable full-screen TUI mode")
	flag.BoolVar(&cfg.validateManifests, "validate-manifests", false, "Validate TOML manifests and exit")
	flag.Parse()
	return cfg
}

func detectSystem() (systemInfo, error) {
	sys := systemInfo{
		arch: runtime.GOARCH,
		home: os.Getenv("HOME"),
	}
	if runtime.GOOS != "linux" {
		return sys, fmt.Errorf("unsupported OS %q: qest currently supports Ubuntu/Fedora/Arch Linux", runtime.GOOS)
	}
	data, err := os.ReadFile("/etc/os-release")
	if err != nil {
		return sys, fmt.Errorf("cannot read /etc/os-release: %w", err)
	}
	fields := map[string]string{}
	for _, line := range strings.Split(string(data), "\n") {
		if strings.TrimSpace(line) == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		fields[parts[0]] = strings.Trim(parts[1], `"`)
	}
	sys.osID = fields["ID"]
	if like := fields["ID_LIKE"]; like != "" {
		sys.osLike = strings.Fields(like)
	}
	if !isSupportedLinux(sys) {
		return sys, fmt.Errorf("unsupported distro: %s (%s)", sys.osID, strings.Join(sys.osLike, ","))
	}
	return sys, nil
}

func isSupportedLinux(sys systemInfo) bool {
	switch sys.osID {
	case "ubuntu", "debian", "fedora", "arch", "manjaro":
		return true
	}
	for _, item := range sys.osLike {
		switch item {
		case "debian", "ubuntu", "fedora", "arch":
			return true
		}
	}
	return false
}

func chooseSelection(cfg appConfig, _ systemInfo, _ []toolManifest) (selection, error) {
	if cfg.yes {
		return selection{
			profile:      "full",
			dotfilesMode: "bundled",
			categories:   defaultCategories(),
		}, nil
	}

	if !isInteractive(cfg) {
		return choosePlainSelection()
	}

	return chooseInteractiveSelection()
}

func isInteractive(cfg appConfig) bool {
	if cfg.noGum {
		return false
	}
	return term.IsTerminal(int(os.Stdin.Fd())) && term.IsTerminal(int(os.Stdout.Fd()))
}

func choosePlainSelection() (selection, error) {
	reader := bufio.NewReader(os.Stdin)
	sel := selection{
		profile:      "full",
		dotfilesMode: "bundled",
		categories:   defaultCategories(),
	}
	fmt.Println("QEST setup profile:")
	fmt.Println("1) full")
	fmt.Println("2) shell")
	fmt.Println("3) essentials")
	fmt.Println("4) custom")
	fmt.Print("Select [1-4] (default 1): ")
	raw, _ := reader.ReadString('\n')
	switch strings.TrimSpace(raw) {
	case "2":
		sel.profile = "shell"
	case "3":
		sel.profile = "essentials"
	case "4":
		sel.profile = "custom"
		sel.categories = map[string]bool{}
		for _, cat := range categoryOptions() {
			fmt.Printf("Include %s? [y/N]: ", categoryLabel(cat))
			line, _ := reader.ReadString('\n')
			if strings.EqualFold(strings.TrimSpace(line), "y") {
				sel.categories[cat] = true
			}
		}
	}

	fmt.Println("Dotfiles source:")
	fmt.Println("1) QEST bundled defaults")
	fmt.Println("2) Custom GitHub repo")
	fmt.Println("3) Skip dotfiles")
	fmt.Print("Select [1-3] (default 1): ")
	raw, _ = reader.ReadString('\n')
	switch strings.TrimSpace(raw) {
	case "2":
		sel.dotfilesMode = "custom"
		fmt.Print("Enter dotfiles repo URL: ")
		repo, _ := reader.ReadString('\n')
		sel.dotfilesRepo = strings.TrimSpace(repo)
		if sel.dotfilesRepo == "" {
			sel.dotfilesMode = "bundled"
		}
	case "3":
		sel.dotfilesMode = "skip"
	}
	fmt.Println("")
	fmt.Printf("Install now with profile '%s'? [y/N]: ", sel.profile)
	raw, _ = reader.ReadString('\n')
	confirmed := strings.EqualFold(strings.TrimSpace(raw), "y")
	if !confirmed {
		return selection{}, errUserCancelled
	}
	return sel, nil
}

func categoryOptions() []string {
	return []string{"shell_env", "essentials", "editor_workflow", "network_tools", "utilities"}
}

func categoryLabel(category string) string {
	switch category {
	case "shell_env":
		return "Shell and env"
	case "essentials":
		return "Essentials"
	case "editor_workflow":
		return "Editor and workflow"
	case "network_tools":
		return "Network tools"
	case "utilities":
		return "Utilities"
	default:
		return category
	}
}

func selectedCategoryLabels(set map[string]bool) []string {
	labels := make([]string, 0, len(set))
	for category, enabled := range set {
		if enabled {
			labels = append(labels, categoryLabel(category))
		}
	}
	sort.Strings(labels)
	return labels
}

type menuItem struct {
	title string
	desc  string
	value string
}

func (i menuItem) FilterValue() string { return i.title }
func (i menuItem) Title() string       { return i.title }
func (i menuItem) Description() string { return i.desc }

type wizardState int

const (
	stepWelcome wizardState = iota
	stepProfile
	stepCustom
	stepDotfiles
	stepDotfilesRepo
	stepConfirm
)

type wizardModel struct {
	step          wizardState
	profileList   list.Model
	dotfilesList  list.Model
	categoryIdx   int
	categorySet   map[string]bool
	dotfilesRepo  string
	selections    selection
	ready         bool
	width         int
	height        int
	colorDisabled bool
}

func chooseInteractiveSelection() (selection, error) {
	profileItems := []list.Item{
		menuItem{title: "Full", desc: "Validated default set (v0.1)", value: "full"},
		menuItem{title: "Shell Only", desc: "Shell stack only", value: "shell"},
		menuItem{title: "Essentials", desc: "Core shell + essentials", value: "essentials"},
		menuItem{title: "Custom", desc: "Pick categories manually", value: "custom"},
	}
	dotfilesItems := []list.Item{
		menuItem{title: "Use QEST bundled defaults", desc: ".zshrc + starship.toml from QEST", value: "bundled"},
		menuItem{title: "Use custom GitHub repo", desc: "Repo root must contain .zshrc and starship.toml", value: "custom"},
		menuItem{title: "Skip dotfiles", desc: "Do not write shell config files", value: "skip"},
	}

	pList := list.New(profileItems, list.NewDefaultDelegate(), 60, 12)
	pList.Title = "Choose profile"
	pList.SetShowStatusBar(false)
	pList.SetFilteringEnabled(false)

	dList := list.New(dotfilesItems, list.NewDefaultDelegate(), 70, 12)
	dList.Title = "Dotfiles source"
	dList.SetShowStatusBar(false)
	dList.SetFilteringEnabled(false)

	model := wizardModel{
		step:         stepWelcome,
		profileList:  pList,
		dotfilesList: dList,
		categorySet:  map[string]bool{},
		selections: selection{
			profile:      "full",
			categories:   defaultCategories(),
			dotfilesMode: "bundled",
		},
		colorDisabled: os.Getenv("NO_COLOR") != "",
	}

	p := tea.NewProgram(model, tea.WithAltScreen())
	result, err := p.Run()
	if err != nil {
		return selection{}, err
	}
	wm, ok := result.(wizardModel)
	if !ok {
		return selection{}, errors.New("unexpected wizard result type")
	}
	if !wm.ready {
		return selection{}, errUserCancelled
	}
	return wm.selections, nil
}

func (m wizardModel) Init() tea.Cmd { return nil }

func (m wizardModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		listWidth := msg.Width - 8
		if listWidth < 40 {
			listWidth = 40
		}
		listHeight := msg.Height - 11
		if listHeight < 8 {
			listHeight = 8
		}
		if listHeight > 18 {
			listHeight = 18
		}
		m.profileList.SetSize(listWidth, listHeight)
		m.dotfilesList.SetSize(listWidth, listHeight)
		return m, nil
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c":
			return m, tea.Quit
		}
	}

	switch m.step {
	case stepWelcome:
		if k, ok := msg.(tea.KeyMsg); ok && (k.String() == "enter" || k.String() == " ") {
			m.step = stepProfile
			return m, nil
		}
	case stepProfile:
		var cmd tea.Cmd
		m.profileList, cmd = m.profileList.Update(msg)
		if k, ok := msg.(tea.KeyMsg); ok && k.String() == "enter" {
			if selected, ok := m.profileList.SelectedItem().(menuItem); ok {
				m.selections.profile = selected.value
				if selected.value == "custom" {
					m.step = stepCustom
					m.categorySet = map[string]bool{}
				} else {
					m.selections.categories = profileCategories(selected.value)
					m.step = stepDotfiles
				}
			}
			return m, nil
		}
		return m, cmd
	case stepCustom:
		categories := categoryOptions()
		if k, ok := msg.(tea.KeyMsg); ok {
			switch k.String() {
			case "up":
				if m.categoryIdx > 0 {
					m.categoryIdx--
				}
			case "down":
				if m.categoryIdx < len(categories)-1 {
					m.categoryIdx++
				}
			case " ":
				cat := categories[m.categoryIdx]
				m.categorySet[cat] = !m.categorySet[cat]
			case "enter":
				if len(m.categorySet) == 0 {
					m.categorySet["essentials"] = true
				}
				m.selections.categories = m.categorySet
				m.step = stepDotfiles
			case "esc":
				m.step = stepProfile
			}
		}
		return m, nil
	case stepDotfiles:
		var cmd tea.Cmd
		m.dotfilesList, cmd = m.dotfilesList.Update(msg)
		if k, ok := msg.(tea.KeyMsg); ok {
			if k.String() == "esc" {
				if m.selections.profile == "custom" {
					m.step = stepCustom
				} else {
					m.step = stepProfile
				}
				return m, nil
			}
			if k.String() == "enter" {
				if selected, ok := m.dotfilesList.SelectedItem().(menuItem); ok {
					m.selections.dotfilesMode = selected.value
					if selected.value == "custom" {
						m.step = stepDotfilesRepo
					} else {
						m.step = stepConfirm
					}
				}
				return m, nil
			}
		}
		return m, cmd
	case stepDotfilesRepo:
		if k, ok := msg.(tea.KeyMsg); ok {
			switch k.String() {
			case "enter":
				if strings.TrimSpace(m.dotfilesRepo) == "" {
					m.selections.dotfilesMode = "bundled"
				} else {
					m.selections.dotfilesRepo = strings.TrimSpace(m.dotfilesRepo)
				}
				m.step = stepConfirm
			case "backspace":
				if len(m.dotfilesRepo) > 0 {
					m.dotfilesRepo = m.dotfilesRepo[:len(m.dotfilesRepo)-1]
				}
			case "esc":
				m.step = stepDotfiles
			default:
				if len(k.String()) == 1 {
					m.dotfilesRepo += k.String()
				}
			}
		}
		return m, nil
	case stepConfirm:
		if k, ok := msg.(tea.KeyMsg); ok {
			switch k.String() {
			case "enter", "y":
				m.ready = true
				return m, tea.Quit
			case "b", "esc":
				if m.selections.dotfilesMode == "custom" {
					m.step = stepDotfilesRepo
				} else {
					m.step = stepDotfiles
				}
			case "n", "q":
				m.ready = false
				return m, tea.Quit
			}
		}
	}
	return m, nil
}

func (m wizardModel) View() string {
	render := lipgloss.NewStyle().Padding(1, 2).Border(lipgloss.RoundedBorder())
	if m.colorDisabled {
		render = render.UnsetForeground().UnsetBackground()
	}
	title := lipgloss.NewStyle().Bold(true).Render("QEST Installer Wizard")

	var body strings.Builder
	body.WriteString(title + "\n\n")
	hint := ""

	switch m.step {
	case stepWelcome:
		body.WriteString("Welcome to QEST.\n")
		body.WriteString("Press Enter to start setup.\n")
		hint = "Enter: continue | Ctrl+C: quit"
	case stepProfile:
		body.WriteString(m.profileList.View())
		hint = "Arrows: move | Enter: select | Ctrl+C: quit"
	case stepCustom:
		categories := categoryOptions()
		body.WriteString("Custom categories (space to toggle, enter to continue):\n\n")
		for i, cat := range categories {
			cursor := " "
			if i == m.categoryIdx {
				cursor = ">"
			}
			mark := " "
			if m.categorySet[cat] {
				mark = "x"
			}
			body.WriteString(fmt.Sprintf("%s [%s] %s\n", cursor, mark, categoryLabel(cat)))
		}
		hint = "Arrows: move | Space: toggle | Enter: continue | Esc: back"
	case stepDotfiles:
		body.WriteString(m.dotfilesList.View())
		hint = "Arrows: move | Enter: select | Esc: back"
	case stepDotfilesRepo:
		body.WriteString("Enter GitHub dotfiles repo URL and press Enter:\n\n")
		body.WriteString(m.dotfilesRepo)
		hint = "Type URL | Enter: continue | Esc: back"
	case stepConfirm:
		body.WriteString("Review before install:\n\n")
		body.WriteString(fmt.Sprintf("- Profile: %s\n", m.selections.profile))
		cats := selectedCategoryLabels(m.selections.categories)
		body.WriteString(fmt.Sprintf("- Categories: %s\n", strings.Join(cats, ", ")))
		body.WriteString(fmt.Sprintf("- Dotfiles: %s\n", m.selections.dotfilesMode))
		if m.selections.dotfilesRepo != "" {
			body.WriteString(fmt.Sprintf("- Dotfiles repo: %s\n", m.selections.dotfilesRepo))
		}
		body.WriteString("\nReady to install.\n")
		hint = "Enter/Y: install | B/Esc: back | N/Q: cancel"
	}

	if hint != "" {
		body.WriteString("\n" + hint + "\n")
	}

	content := render.Render(body.String())
	if m.width > 0 && m.height > 0 {
		return lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, content)
	}
	return content
}

func runInteractiveInstaller(inst installer) error {
	spin := spinner.New(spinner.WithSpinner(spinner.Dot))
	pm := progressModel{
		model: progressState{spinner: spin},
		run: func(send func(string)) error {
			i := inst
			i.logger = send
			return runInstaller(context.Background(), &i)
		},
	}

	p := tea.NewProgram(pm, tea.WithAltScreen())
	result, err := p.Run()
	if err != nil {
		return err
	}
	finalModel, ok := result.(progressModel)
	if !ok {
		return errors.New("unexpected installer result type")
	}
	return finalModel.model.err
}

type progressState struct {
	spinner         spinner.Model
	logs            []string
	done            bool
	err             error
	summary         []string
	awaitingDismiss bool
}

type progressModel struct {
	model  progressState
	events chan progressEventMsg
	run    func(send func(string)) error
}

type progressEventMsg struct {
	line    string
	done    bool
	err     error
	summary []string
}

func waitForProgress(events <-chan progressEventMsg) tea.Cmd {
	return func() tea.Msg {
		msg, ok := <-events
		if !ok {
			return progressEventMsg{done: true}
		}
		return msg
	}
}

func (m progressModel) Init() tea.Cmd {
	if m.events == nil {
		m.events = make(chan progressEventMsg, 256)
		go func() {
			err := m.run(func(line string) {
				m.events <- progressEventMsg{line: line}
			})
			m.events <- progressEventMsg{done: true, err: err, summary: buildSummaryLines(err)}
			close(m.events)
		}()
	}
	return tea.Batch(m.model.spinner.Tick, waitForProgress(m.events))
}

func (m progressModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		if msg.String() == "ctrl+c" {
			return m, tea.Quit
		}
		if m.model.done {
			switch msg.String() {
			case "enter", "q", "esc":
				return m, tea.Quit
			}
		}
	case spinner.TickMsg:
		if m.model.done {
			return m, nil
		}
		var cmd tea.Cmd
		m.model.spinner, cmd = m.model.spinner.Update(msg)
		return m, cmd
	case progressEventMsg:
		if msg.line != "" {
			m.model.logs = append(m.model.logs, msg.line)
		}
		if msg.done {
			m.model.done = true
			m.model.err = msg.err
			m.model.summary = msg.summary
			m.model.awaitingDismiss = true
			return m, nil
		}
		return m, waitForProgress(m.events)
	}
	return m, nil
}

func (m progressModel) View() string {
	var b strings.Builder
	if m.model.done {
		if m.model.err != nil {
			b.WriteString("Install completed with failures.\n\n")
		} else {
			b.WriteString("Install completed successfully.\n\n")
		}
	} else {
		b.WriteString(fmt.Sprintf("%s Installing...\n\n", m.model.spinner.View()))
	}
	start := 0
	if len(m.model.logs) > 20 {
		start = len(m.model.logs) - 20
	}
	for _, line := range m.model.logs[start:] {
		b.WriteString(line + "\n")
	}
	if m.model.done {
		if len(m.model.summary) > 0 {
			b.WriteString("\nSummary:\n")
			for _, line := range m.model.summary {
				b.WriteString("- " + line + "\n")
			}
		}
		if m.model.awaitingDismiss {
			b.WriteString("\nPress Enter to exit.\n")
		}
	}
	return b.String()
}

func runInstaller(ctx context.Context, inst *installer) error {
	if err := preflightChecks(inst.sys); err != nil {
		return err
	}
	results := []phaseResult{
		runPhase(ctx, "tools", func() error { return inst.installTools(ctx) }, inst.logger),
		runPhase(ctx, "shell_plugins", func() error { return inst.installShellPlugins(ctx) }, inst.logger),
		runPhase(ctx, "config", func() error { return inst.applyConfig(ctx) }, inst.logger),
		runPhase(ctx, "default_shell", func() error { return inst.setDefaultShell(ctx) }, inst.logger),
	}
	var failed []string
	for _, r := range results {
		if r.status == "failed" && r.err != nil {
			failed = append(failed, fmt.Sprintf("%s: %v", r.name, r.err))
		}
	}
	if len(failed) > 0 {
		return fmt.Errorf("one or more phases failed:\n%s", strings.Join(failed, "\n"))
	}
	return nil
}

func preflightChecks(sys systemInfo) error {
	if sys.home == "" {
		return errors.New("HOME is not set")
	}
	if err := os.MkdirAll(filepath.Join(sys.home, ".config"), 0o755); err != nil {
		return fmt.Errorf("cannot write to home config dir: %w", err)
	}
	if _, err := exec.LookPath("sudo"); err != nil {
		return fmt.Errorf("sudo is required: %w", err)
	}
	client := http.Client{Timeout: 8 * time.Second}
	resp, err := client.Get("https://github.com")
	if err != nil {
		return fmt.Errorf("internet check failed: %w", err)
	}
	_ = resp.Body.Close()
	return nil
}

func runPhase(ctx context.Context, name string, fn func() error, logger func(string)) phaseResult {
	logger(fmt.Sprintf("==> Phase %s started", name))
	if err := fn(); err != nil {
		logger(fmt.Sprintf("==> Phase %s failed: %v", name, err))
		return phaseResult{name: name, status: "failed", err: err}
	}
	logger(fmt.Sprintf("==> Phase %s completed", name))
	return phaseResult{name: name, status: "success"}
}

func (i *installer) installTools(ctx context.Context) error {
	selected := selectTools(i.tools, i.selection)
	nativePkgs := []string{}
	brewPkgs := []string{}
	for _, t := range selected {
		source := sourceForOS(t, i.sys.osID)
		switch source {
		case "native":
			if pkg := packageForOS(t, i.sys.osID); pkg != "" {
				nativePkgs = append(nativePkgs, pkg)
			}
		case "brew":
			if pkg := packageForOS(t, "brew"); pkg != "" {
				brewPkgs = append(brewPkgs, pkg)
			}
		default:
			i.logger(fmt.Sprintf("skip unsupported tool: %s", t.ID))
		}
	}

	if len(nativePkgs) > 0 {
		if err := i.installNative(ctx, nativePkgs); err != nil {
			return err
		}
	}
	if len(brewPkgs) > 0 {
		if err := i.ensureBrew(ctx); err != nil {
			return err
		}
		if err := i.runCommand(ctx, false, "brew", append([]string{"install"}, uniqueStrings(brewPkgs)...)...); err != nil {
			return err
		}
	}
	return nil
}

func (i *installer) installNative(ctx context.Context, pkgs []string) error {
	pkgs = uniqueStrings(pkgs)
	switch i.sys.osID {
	case "ubuntu", "debian":
		if err := i.runCommand(ctx, true, "apt-get", "update"); err != nil {
			return err
		}
		args := append([]string{"install", "-y"}, pkgs...)
		return i.runCommand(ctx, true, "apt-get", args...)
	case "fedora":
		args := append([]string{"install", "-y"}, pkgs...)
		return i.runCommand(ctx, true, "dnf", args...)
	case "arch", "manjaro":
		args := append([]string{"-Sy", "--noconfirm"}, pkgs...)
		return i.runCommand(ctx, true, "pacman", args...)
	default:
		return fmt.Errorf("native install unsupported on %s", i.sys.osID)
	}
}

func (i *installer) ensureBrew(ctx context.Context) error {
	i.addBrewToPath()
	if _, err := exec.LookPath("brew"); err == nil {
		return nil
	}
	if i.cfg.dryRun {
		i.logger("[dry-run] install Homebrew")
		return nil
	}
	tmp := filepath.Join(os.TempDir(), "qest-brew-install.sh")
	if err := i.runCommand(ctx, false, "curl", "-fsSL", "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh", "-o", tmp); err != nil {
		return err
	}
	if err := i.runCommand(ctx, false, "bash", tmp); err != nil {
		return err
	}
	i.addBrewToPath()
	if _, err := exec.LookPath("brew"); err != nil {
		return fmt.Errorf("homebrew installed but brew is not on PATH: %w", err)
	}
	return nil
}

func (i *installer) installShellPlugins(ctx context.Context) error {
	if i.selection.profile == "shell" || i.selection.profile == "full" || i.selection.categories["shell_env"] {
		home := i.sys.home
		fzfTab := filepath.Join(home, ".zsh", "fzf-tab")
		highlight := filepath.Join(home, ".zsh", "fast-syntax-highlighting")
		_ = os.MkdirAll(filepath.Join(home, ".zsh"), 0o755)
		if _, err := os.Stat(fzfTab); errors.Is(err, os.ErrNotExist) {
			if err := i.runCommand(ctx, false, "git", "clone", "--depth", "1", "https://github.com/Aloxaf/fzf-tab.git", fzfTab); err != nil {
				return err
			}
		}
		if _, err := os.Stat(highlight); errors.Is(err, os.ErrNotExist) {
			if err := i.runCommand(ctx, false, "git", "clone", "--depth", "1", "https://github.com/zdharma-continuum/fast-syntax-highlighting.git", highlight); err != nil {
				return err
			}
		}
	}
	return nil
}

func (i *installer) applyConfig(ctx context.Context) error {
	_ = ctx
	if i.selection.dotfilesMode == "skip" {
		i.logger("dotfiles skipped")
		return nil
	}
	home := i.sys.home
	zshrc := assets.DefaultZshrc
	starship := assets.DefaultStarship

	if i.selection.dotfilesMode == "custom" && i.selection.dotfilesRepo != "" {
		tmp := filepath.Join(os.TempDir(), fmt.Sprintf("qest-dotfiles-%d", time.Now().Unix()))
		if err := i.runCommand(context.Background(), false, "git", "clone", "--depth", "1", i.selection.dotfilesRepo, tmp); err != nil {
			i.logger(fmt.Sprintf("custom dotfiles unavailable, falling back to bundled defaults: %v", err))
		} else {
			if b, err := os.ReadFile(filepath.Join(tmp, ".zshrc")); err == nil {
				zshrc = string(b)
			}
			if b, err := os.ReadFile(filepath.Join(tmp, "starship.toml")); err == nil {
				starship = string(b)
			}
		}
	}

	if err := os.MkdirAll(filepath.Join(home, ".config", "zsh"), 0o755); err != nil {
		return err
	}
	if err := backupAndWrite(filepath.Join(home, ".zshrc"), []byte(zshrc)); err != nil {
		return err
	}
	if err := backupAndWrite(filepath.Join(home, ".config", "starship.toml"), []byte(starship)); err != nil {
		return err
	}
	return nil
}

func (i *installer) setDefaultShell(ctx context.Context) error {
	if !term.IsTerminal(int(os.Stdin.Fd())) || !term.IsTerminal(int(os.Stdout.Fd())) {
		i.logger("skip default shell change in non-interactive environment")
		return nil
	}
	if os.Getenv("CI") != "" || isContainerEnvironment() {
		i.logger("skip default shell change in CI/container environment")
		return nil
	}
	zshPath, err := exec.LookPath("zsh")
	if err != nil {
		return nil
	}
	current := os.Getenv("SHELL")
	if current == zshPath {
		return nil
	}
	return i.runCommand(ctx, false, "chsh", "-s", zshPath)
}

func (i *installer) runCommand(ctx context.Context, useSudo bool, name string, args ...string) error {
	if i.cfg.dryRun {
		prefix := ""
		if useSudo {
			prefix = "sudo "
		}
		i.logger(fmt.Sprintf("[dry-run] %s%s %s", prefix, name, strings.Join(args, " ")))
		return nil
	}

	cmdName := name
	cmdArgs := args
	if useSudo {
		cmdName = "sudo"
		cmdArgs = append([]string{name}, args...)
	}
	cmd := exec.CommandContext(ctx, cmdName, cmdArgs...)
	writer := newLineWriter(func(line string) { i.logger(line) })
	cmd.Stdout = writer
	cmd.Stderr = writer
	return cmd.Run()
}

func sourceForOS(t toolManifest, osID string) string {
	if v := t.InstallSource[osID]; v != "" {
		return v
	}
	if strings.Contains(osID, "debian") && t.InstallSource["ubuntu"] != "" {
		return t.InstallSource["ubuntu"]
	}
	return "unsupported"
}

func packageForOS(t toolManifest, key string) string {
	return t.PackageName[key]
}

func selectTools(all []toolManifest, sel selection) []toolManifest {
	var out []toolManifest
	for _, t := range all {
		if t.ValidationStatus != "validated" {
			continue
		}
		switch sel.profile {
		case "shell":
			if t.Category == "shell_env" {
				out = append(out, t)
			}
		case "essentials":
			if t.Tier == "core" {
				out = append(out, t)
			}
		case "custom":
			if sel.categories[t.Category] {
				out = append(out, t)
			}
		default:
			out = append(out, t)
		}
	}
	return out
}

func defaultCategories() map[string]bool {
	return map[string]bool{
		"shell_env":       true,
		"essentials":      true,
		"editor_workflow": true,
	}
}

func profileCategories(profile string) map[string]bool {
	switch profile {
	case "shell":
		return map[string]bool{"shell_env": true}
	case "essentials":
		return map[string]bool{"shell_env": true, "essentials": true}
	default:
		return defaultCategories()
	}
}

func loadToolManifests(dir string) ([]toolManifest, error) {
	entries, err := os.ReadDir(dir)
	tools := make([]toolManifest, 0, len(entries))
	if err == nil {
		for _, entry := range entries {
			if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".toml") {
				continue
			}
			path := filepath.Join(dir, entry.Name())
			var t toolManifest
			if _, err := toml.DecodeFile(path, &t); err != nil {
				return nil, fmt.Errorf("invalid tool manifest %s: %w", entry.Name(), err)
			}
			tools = append(tools, t)
		}
	} else {
		embeddedEntries, embeddedErr := fs.ReadDir(embeddedmanifests.ToolFS, "tools")
		if embeddedErr != nil {
			return nil, err
		}
		for _, entry := range embeddedEntries {
			if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".toml") {
				continue
			}
			data, readErr := fs.ReadFile(embeddedmanifests.ToolFS, filepath.Join("tools", entry.Name()))
			if readErr != nil {
				return nil, fmt.Errorf("cannot read embedded tool manifest %s: %w", entry.Name(), readErr)
			}
			var t toolManifest
			if _, decodeErr := toml.Decode(string(data), &t); decodeErr != nil {
				return nil, fmt.Errorf("invalid embedded tool manifest %s: %w", entry.Name(), decodeErr)
			}
			tools = append(tools, t)
		}
	}
	if len(tools) == 0 {
		return nil, errors.New("no tool manifests found")
	}
	if err := validateToolManifests(tools); err != nil {
		return nil, err
	}
	sort.Slice(tools, func(i, j int) bool { return tools[i].ID < tools[j].ID })
	return tools, nil
}

func validateToolManifests(tools []toolManifest) error {
	allowedCategories := map[string]bool{
		"shell_env":       true,
		"essentials":      true,
		"editor_workflow": true,
		"network_tools":   true,
		"utilities":       true,
	}
	allowedTiers := map[string]bool{
		"core": true,
	}
	allowedValidationStatus := map[string]bool{
		"validated": true,
		"planned":   true,
	}
	allowedInstallSources := map[string]bool{
		"native":      true,
		"brew":        true,
		"unsupported": true,
	}
	requiredOS := []string{"ubuntu", "fedora", "arch"}
	seenIDs := map[string]bool{}

	for _, t := range tools {
		if t.ID == "" || t.Category == "" || t.Tier == "" || t.ValidationStatus == "" {
			return fmt.Errorf("tool manifest missing required fields: %s", t.ID)
		}
		if seenIDs[t.ID] {
			return fmt.Errorf("duplicate tool id: %s", t.ID)
		}
		seenIDs[t.ID] = true

		if !allowedCategories[t.Category] {
			return fmt.Errorf("invalid category for %s: %s", t.ID, t.Category)
		}
		if !allowedTiers[t.Tier] {
			return fmt.Errorf("invalid tier for %s: %s", t.ID, t.Tier)
		}
		if !allowedValidationStatus[t.ValidationStatus] {
			return fmt.Errorf("invalid validation_status for %s: %s", t.ID, t.ValidationStatus)
		}
		for _, osID := range requiredOS {
			source := t.InstallSource[osID]
			if source == "" {
				return fmt.Errorf("missing install_source[%s] for %s", osID, t.ID)
			}
			if !allowedInstallSources[source] {
				return fmt.Errorf("invalid install_source[%s] for %s: %s", osID, t.ID, source)
			}
			if source == "native" {
				if strings.TrimSpace(t.PackageName[osID]) == "" {
					return fmt.Errorf("missing package_name[%s] for %s", osID, t.ID)
				}
			}
			if source == "brew" {
				if strings.TrimSpace(t.PackageName["brew"]) == "" {
					return fmt.Errorf("missing package_name[brew] for %s", t.ID)
				}
			}
		}
	}
	return nil
}

func backupAndWrite(path string, data []byte) error {
	if existing, err := os.ReadFile(path); err == nil {
		backup := fmt.Sprintf("%s.qest.bak.%s", path, time.Now().Format("20060102_150405"))
		if err := os.WriteFile(backup, existing, 0o644); err != nil {
			return err
		}
	}
	return os.WriteFile(path, data, 0o644)
}

func uniqueStrings(items []string) []string {
	seen := map[string]bool{}
	out := make([]string, 0, len(items))
	for _, item := range items {
		if item == "" || seen[item] {
			continue
		}
		seen[item] = true
		out = append(out, item)
	}
	return out
}

type lineWriter struct {
	mu  sync.Mutex
	buf bytes.Buffer
	cb  func(string)
}

func newLineWriter(cb func(string)) io.Writer {
	return &lineWriter{cb: cb}
}

func (w *lineWriter) Write(p []byte) (int, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	for _, b := range p {
		if b == '\n' {
			line := strings.TrimRight(w.buf.String(), "\r")
			if line != "" {
				w.cb(line)
			}
			w.buf.Reset()
			continue
		}
		_ = w.buf.WriteByte(b)
	}
	return len(p), nil
}

func (i *installer) addBrewToPath() {
	paths := []string{
		"/home/linuxbrew/.linuxbrew/bin",
		"/home/linuxbrew/.linuxbrew/sbin",
	}
	current := os.Getenv("PATH")
	for _, p := range paths {
		if _, err := os.Stat(p); err == nil && !strings.Contains(current, p) {
			current = p + ":" + current
		}
	}
	_ = os.Setenv("PATH", current)
}

func isContainerEnvironment() bool {
	if _, err := os.Stat("/.dockerenv"); err == nil {
		return true
	}
	if _, err := os.Stat("/run/.containerenv"); err == nil {
		return true
	}
	data, err := os.ReadFile("/proc/1/cgroup")
	if err != nil {
		return false
	}
	content := strings.ToLower(string(data))
	return strings.Contains(content, "docker") ||
		strings.Contains(content, "containerd") ||
		strings.Contains(content, "kubepods") ||
		strings.Contains(content, "libpod")
}

func buildSummaryLines(err error) []string {
	if err == nil {
		return []string{"all phases completed"}
	}
	lines := []string{}
	for _, line := range strings.Split(err.Error(), "\n") {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" {
			continue
		}
		lines = append(lines, trimmed)
	}
	if len(lines) == 0 {
		return []string{err.Error()}
	}
	return lines
}

func fatalf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "qest: "+format+"\n", args...)
	os.Exit(1)
}
