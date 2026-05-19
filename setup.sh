#!/usr/bin/env bash

set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
TMP_DIR="$(mktemp -d)"
CURRENT_USER="${USER:-$(id -un)}"
SUDO="sudo"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

info() {
  printf '\033[1;34m[INFO]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2
  exit 1
}

require_user_run() {
  if [[ "${EUID}" -eq 0 ]]; then
    die "Run this script as your normal user, not with sudo. It will request sudo when needed."
  fi
}

require_ubuntu() {
  if [[ ! -r /etc/os-release ]]; then
    die "This setup currently supports Ubuntu only."
  fi

  # shellcheck source=/dev/null
  . /etc/os-release
  if [[ "${ID:-}" != "ubuntu" ]]; then
    die "This setup currently supports Ubuntu only. Detected: ${PRETTY_NAME:-unknown}"
  fi

  info "Detected ${PRETTY_NAME:-Ubuntu}"
}

require_sudo() {
  command -v sudo >/dev/null 2>&1 || die "sudo is required."
  info "Requesting sudo credentials for system package installation."
  "$SUDO" -v
}

apt_update() {
  "$SUDO" apt-get update
}

apt_install() {
  "$SUDO" DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

install_base_packages() {
  info "Installing base Ubuntu packages."
  apt_update
  apt_install \
    ca-certificates \
    curl \
    gnupg \
    software-properties-common
  "$SUDO" add-apt-repository -y universe
  apt_update
  apt_install \
    apt-transport-https \
    build-essential \
    ca-certificates \
    curl \
    fd-find \
    ffmpeg \
    fzf \
    gettext \
    git \
    gnupg \
    gpg \
    imagemagick \
    jq \
    libbz2-dev \
    libffi-dev \
    liblzma-dev \
    libncursesw5-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    libxml2-dev \
    libxmlsec1-dev \
    llvm \
    lsb-release \
    make \
    p7zip-full \
    pkg-config \
    poppler-utils \
    python3 \
    python3-dev \
    python3-neovim \
    python3-pip \
    python3-venv \
    ripgrep \
    software-properties-common \
    tar \
    tk-dev \
    tmux \
    unzip \
    wget \
    xz-utils \
    zlib1g-dev \
    zoxide \
    zsh
}

install_pipx() {
  export PATH="$HOME/.local/bin:$PATH"

  if command -v pipx >/dev/null 2>&1; then
    info "pipx is already installed."
  elif apt-cache show pipx >/dev/null 2>&1; then
    info "Installing pipx from apt."
    apt_install pipx
  else
    info "Installing pipx with python3 -m pip."
    python3 -m pip install --user --upgrade pipx
  fi

  pipx ensurepath
}

pipx_install_or_upgrade() {
  local package="$1"

  if pipx list --short 2>/dev/null | awk '{print $1}' | grep -qx "$package"; then
    info "Upgrading pipx package: $package"
    pipx upgrade "$package"
  else
    info "Installing pipx package: $package"
    pipx install "$package"
  fi
}

install_python_cli_tools() {
  install_pipx
  pipx_install_or_upgrade poetry
  pipx_install_or_upgrade twine
}

setup_github_cli_repo() {
  info "Configuring GitHub CLI apt repository."
  "$SUDO" install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | "$SUDO" tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  "$SUDO" chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  "$SUDO" install -m 0755 -d /etc/apt/sources.list.d
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' "$(dpkg --print-architecture)" \
    | "$SUDO" tee /etc/apt/sources.list.d/github-cli.list >/dev/null
}

setup_docker_repo() {
  info "Configuring Docker official apt repository."

  # shellcheck source=/dev/null
  . /etc/os-release
  local codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
  [[ -n "$codename" ]] || die "Could not determine Ubuntu codename for Docker repository."

  "$SUDO" install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | "$SUDO" tee /etc/apt/keyrings/docker.asc >/dev/null
  "$SUDO" chmod a+r /etc/apt/keyrings/docker.asc

  cat <<EOF | "$SUDO" tee /etc/apt/sources.list.d/docker.sources >/dev/null
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${codename}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
}

remove_docker_conflicts() {
  local pkg
  local installed=()
  local conflicts=(
    docker.io
    docker-doc
    docker-compose
    docker-compose-v2
    podman-docker
    containerd
    runc
  )

  for pkg in "${conflicts[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      installed+=("$pkg")
    fi
  done

  if ((${#installed[@]})); then
    info "Removing Docker packages that conflict with Docker CE: ${installed[*]}"
    "$SUDO" DEBIAN_FRONTEND=noninteractive apt-get remove -y "${installed[@]}"
  fi
}

install_repo_packages() {
  setup_github_cli_repo
  setup_docker_repo
  remove_docker_conflicts

  info "Installing GitHub CLI and Docker Engine."
  apt_update
  apt_install \
    containerd.io \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin \
    gh

  if getent group docker >/dev/null 2>&1; then
    "$SUDO" usermod -aG docker "$CURRENT_USER"
  fi
}

system_arch() {
  case "$(dpkg --print-architecture)" in
    amd64) printf 'x86_64' ;;
    arm64) printf 'arm64' ;;
    *)
      die "Unsupported architecture: $(dpkg --print-architecture)"
      ;;
  esac
}

debian_arch() {
  case "$(dpkg --print-architecture)" in
    amd64) printf 'amd64' ;;
    arm64) printf 'arm64' ;;
    *)
      die "Unsupported architecture: $(dpkg --print-architecture)"
      ;;
  esac
}

install_neovim() {
  local arch
  local archive
  local install_dir
  local url

  arch="$(system_arch)"
  archive="$TMP_DIR/nvim-linux-${arch}.tar.gz"
  install_dir="/opt/nvim-linux-${arch}"
  url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${arch}.tar.gz"

  info "Installing latest stable Neovim from official release archive."
  curl -fL "$url" -o "$archive"
  "$SUDO" rm -rf "$install_dir"
  "$SUDO" tar -C /opt -xzf "$archive"

  if [[ -e /usr/local/bin/nvim && ! -L /usr/local/bin/nvim ]]; then
    warn "/usr/local/bin/nvim exists and is not a symlink; leaving it unchanged."
  else
    "$SUDO" ln -sfn "$install_dir/bin/nvim" /usr/local/bin/nvim
  fi
}

source_cargo_env() {
  if [[ -r "$HOME/.cargo/env" ]]; then
    # shellcheck source=/dev/null
    . "$HOME/.cargo/env"
  fi
  export PATH="$HOME/.cargo/bin:$PATH"
}

install_rust() {
  source_cargo_env

  if command -v rustup >/dev/null 2>&1; then
    info "Updating Rust stable toolchain."
    rustup update stable
  else
    info "Installing Rust with rustup."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --profile default
  fi

  source_cargo_env
}

install_yazi() {
  source_cargo_env
  command -v cargo >/dev/null 2>&1 || die "cargo is required before installing Yazi."

  info "Installing Yazi with cargo."
  cargo install --force yazi-build
}

latest_github_asset_url() {
  local repo="$1"
  local regex="$2"
  local release_json
  local asset_url

  release_json="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest")"
  asset_url="$(jq -r --arg regex "$regex" 'first(.assets[] | select(.name | test($regex)) | .browser_download_url) // empty' <<<"$release_json")"
  [[ -n "$asset_url" && "$asset_url" != "null" ]] || die "Could not find release asset for ${repo} matching ${regex}."
  printf '%s' "$asset_url"
}

install_github_tar_binary() {
  local repo="$1"
  local binary="$2"
  local asset_regex="$3"
  local archive
  local asset_url
  local candidate
  local workdir

  info "Installing ${binary} from ${repo} latest release."
  workdir="$(mktemp -d "$TMP_DIR/${binary}.XXXXXX")"
  archive="$workdir/${binary}.tar.gz"
  asset_url="$(latest_github_asset_url "$repo" "$asset_regex")"

  curl -fL "$asset_url" -o "$archive"
  tar -xzf "$archive" -C "$workdir"
  candidate="$(find "$workdir" -type f -name "$binary" -perm -111 -print -quit)"
  [[ -n "$candidate" ]] || candidate="$(find "$workdir" -type f -name "$binary" -print -quit)"
  [[ -n "$candidate" ]] || die "Could not find ${binary} inside ${asset_url}."

  "$SUDO" install -m 0755 "$candidate" "/usr/local/bin/$binary"
}

install_lazygit_and_lazydocker() {
  local arch

  arch="$(system_arch)"
  install_github_tar_binary "jesseduffield/lazygit" "lazygit" "^lazygit_.*_[Ll]inux_${arch}\\.tar\\.gz$"
  install_github_tar_binary "jesseduffield/lazydocker" "lazydocker" "^lazydocker_.*_[Ll]inux_${arch}\\.tar\\.gz$"
}

install_glab() {
  local arch
  local asset_url
  local deb
  local release_json
  local tag
  local version

  arch="$(debian_arch)"
  deb="$TMP_DIR/glab.deb"

  info "Installing glab from GitLab latest release."
  release_json="$(curl -fsSL "https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases/permalink/latest")"
  asset_url="$(jq -r --arg regex "^glab_.*_linux_${arch}\\.deb$" 'first(.assets.links[]? | select(.name | test($regex)) | (.direct_asset_url // .url)) // empty' <<<"$release_json")"

  if [[ -z "$asset_url" || "$asset_url" == "null" ]]; then
    tag="$(jq -r '.tag_name' <<<"$release_json")"
    [[ -n "$tag" && "$tag" != "null" ]] || die "Could not determine latest glab release tag."
    version="${tag#v}"
    asset_url="https://gitlab.com/gitlab-org/cli/-/releases/${tag}/downloads/glab_${version}_linux_${arch}.deb"
  fi

  curl -fL "$asset_url" -o "$deb"
  apt_install "$deb"
}

install_pyenv() {
  info "Installing or updating pyenv."

  if [[ -d "$HOME/.pyenv/.git" ]]; then
    git -C "$HOME/.pyenv" pull --ff-only
  elif [[ -e "$HOME/.pyenv" ]]; then
    warn "$HOME/.pyenv exists but is not a git checkout; leaving it unchanged."
  else
    curl -fsSL https://pyenv.run | bash
  fi

  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
}

source_nvm() {
  export NVM_DIR="$HOME/.nvm"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    set +u
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
    set -u
  fi
}

install_nvm_and_codex() {
  local nvm_tag

  export NVM_DIR="$HOME/.nvm"

  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    info "Installing nvm."
    nvm_tag="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')"
    [[ -n "$nvm_tag" && "$nvm_tag" != "null" ]] || nvm_tag="v0.40.3"
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_tag}/install.sh" \
      | PROFILE=/dev/null bash
  else
    info "nvm is already installed."
  fi

  source_nvm
  command -v nvm >/dev/null 2>&1 || die "nvm installation failed."

  info "Installing latest Node.js LTS with nvm."
  nvm install --lts
  nvm alias default 'lts/*'
  nvm use default

  info "Installing OpenAI Codex CLI with npm."
  npm i -g @openai/codex
}

backup_existing() {
  local destination="$1"
  local backup="${destination}.backup.${TIMESTAMP}"

  while [[ -e "$backup" || -L "$backup" ]]; do
    backup="${destination}.backup.${TIMESTAMP}.${RANDOM}"
  done

  info "Backing up ${destination} -> ${backup}"
  mv "$destination" "$backup"
}

link_file() {
  local source_rel="$1"
  local destination="$2"
  local source_abs="$REPO_DIR/$source_rel"

  [[ -e "$source_abs" ]] || die "Missing source file: $source_abs"
  mkdir -p "$(dirname "$destination")"

  if [[ -L "$destination" && "$(readlink "$destination")" == "$source_abs" ]]; then
    info "Already linked: $destination"
    return
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    backup_existing "$destination"
  fi

  ln -s "$source_abs" "$destination"
  info "Linked ${destination} -> ${source_abs}"
}

link_user_bin_alias() {
  local name="$1"
  local target="$2"
  local destination="$HOME/.local/bin/$name"

  if command -v "$name" >/dev/null 2>&1; then
    return
  fi

  mkdir -p "$HOME/.local/bin"
  if [[ -e "$destination" && ! -L "$destination" ]]; then
    warn "$destination exists and is not a symlink; leaving it unchanged."
    return
  fi

  ln -sfn "$target" "$destination"
}

configure_fd_aliases() {
  local fdfind_path

  if command -v fdfind >/dev/null 2>&1; then
    fdfind_path="$(command -v fdfind)"
    link_user_bin_alias fd "$fdfind_path"
    link_user_bin_alias fdf "$fdfind_path"
  fi
}

link_dotfiles() {
  info "Linking dotfiles."
  link_file "zsh/.zshrc" "$HOME/.zshrc"
  link_file "git/.gitconfig" "$HOME/.gitconfig"
  link_file "tmux/.tmux.conf" "$HOME/.tmux.conf"
  link_file "wezterm/.wezterm.lua" "$HOME/.wezterm.lua"
  link_file "yazi/yazi.toml" "$HOME/.config/yazi/yazi.toml"
  link_file "vscode/settings.json" "$HOME/.config/Code/User/settings.json"
}

install_neovim_config() {
  local target="$HOME/.config/nvim"
  local repo="https://github.com/SuperSocialForce/nvim_config.git"
  local current_remote

  mkdir -p "$HOME/.config"

  if [[ -d "$target/.git" ]]; then
    current_remote="$(git -C "$target" config --get remote.origin.url || true)"
    if [[ "$current_remote" == "$repo" || "$current_remote" == "git@github.com:SuperSocialForce/nvim_config.git" ]]; then
      info "Updating Neovim config."
      git -C "$target" pull --ff-only
      return
    fi
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    backup_existing "$target"
  fi

  info "Cloning Neovim config."
  git clone "$repo" "$target"
}

check_command() {
  local name="$1"
  local command_name="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    printf '  [ok]   %s (%s)\n' "$name" "$(command -v "$command_name")"
  else
    printf '  [miss] %s\n' "$name"
  fi
}

print_summary() {
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.pyenv/bin:/usr/local/bin:$PATH"
  source_nvm || true

  printf '\nSetup finished.\n'
  printf '\nInstalled command check:\n'
  check_command "zsh" zsh
  check_command "git" git
  check_command "tmux" tmux
  check_command "nvim" nvim
  check_command "rg" rg
  check_command "fd" fd
  check_command "fdf" fdf
  check_command "zoxide" zoxide
  check_command "gh" gh
  check_command "glab" glab
  check_command "lazygit" lazygit
  check_command "docker" docker
  check_command "lazydocker" lazydocker
  check_command "codex" codex
  check_command "pyenv" pyenv
  check_command "pipx" pipx
  check_command "poetry" poetry
  check_command "twine" twine
  check_command "yazi" yazi
  check_command "cargo" cargo

  cat <<'EOF'

Notes:
  - Restart your shell or log in again so PATH and docker group changes take effect.
  - zsh is installed and ~/.zshrc is linked, but the default shell is left unchanged.
  - Run `gh auth login`, `glab auth login`, and `codex` when you are ready to authenticate.
  - Put machine-local secrets or overrides in `~/.zshrc.local`.
EOF
}

main() {
  require_user_run
  require_ubuntu
  require_sudo

  install_base_packages
  install_repo_packages
  install_neovim
  install_rust
  install_yazi
  install_glab
  install_lazygit_and_lazydocker
  install_pyenv
  install_python_cli_tools
  install_nvm_and_codex
  configure_fd_aliases
  link_dotfiles
  install_neovim_config
  print_summary
}

main "$@"
