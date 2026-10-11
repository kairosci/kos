function helper() {
	case "${1:-}" in
	"" | list | ls)
		cat << 'HELP'
helper - one helper per tool. Usage: helper <name>
  fzf ................ fuzzy search
  rg ................. search in files   fd ..... find files
  bat ................ cat with colors   eza .... modern ls
  zoxide ............. jump to frequent directories
  git ................ git essentials   lazygit  visual git
  gum ................ menus and prompts for scripts
  ai ................. AI CLI: default TUI only
HELP
		;;
	fzf)
		cat << 'HELP'
fzf - Ctrl-t files, Ctrl-r history, Alt-c directories
  inside fzf: TAB multi-select, Ctrl-j/k move, ENTER confirm
HELP
		;;
	rg)
		cat << 'HELP'
rg - rg 'text' (recursive), rg -i ignore case
  rg -l filenames only, rg -t py by type, rg -C2 2 lines context
HELP
		;;
	fd)
		cat << 'HELP'
fd - fd name (recursive, ignores .git), fd -e pdf by extension
  fd -t d directories only, fd -x command {} run on each
HELP
		;;
	bat)
		cat << 'HELP'
bat - bat file (cat with numbers and colors), bat -n numbers
  bat -l python force language, bat --diff git changes only
HELP
		;;
	eza)
		cat << 'HELP'
eza - eza -l details, eza -la including hidden, eza -T tree
  eza --git with git status, eza -s size sort by size
HELP
		;;
	zoxide)
		cat << 'HELP'
zoxide - z partial-name jump to directory, z - previous
  zi interactive menu
HELP
		;;
	git)
		cat << 'HELP'
git - status, add -A, commit -m "msg", push, pull
  checkout -b new branch, branch list, log --oneline --graph -10
  diff changes, restore file discard changes, reset --soft HEAD~1
HELP
		;;
	lazygit)
		cat << 'HELP'
lazygit - SPACE select, a stage all, c commit, P push
  p pull, ? full help inside lazygit, q quit
HELP
		;;
	gum)
		cat << 'HELP'
gum - gum choose a b c (menu), gum confirm "ok?" && ...
  gum input --placeholder "name", gum spin -- long command
HELP
		;;
	ai)
		cat << 'HELP'
AI CLI - no exceptions: default TUI only, no omaconf themes.
  Open the built-in help inside the app you are using.
HELP
		;;
	*)
		printf '%s\n' "helper: '$1' unknown. Try: helper list" >&2
		return 1
		;;
	esac
}
