#!/usr/bin/env sh

BOLD='\033[0;1m'

printf "$${BOLD}Installing jupyterlab!\n"

# check if jupyterlab is installed
if ! command -v jupyterlab > /dev/null 2>&1; then
  # install jupyterlab
  # check if pipx is installed
  if ! command -v pipx > /dev/null 2>&1; then
    echo "pipx is not installed"
    echo "Please install pipx in your Dockerfile/VM image before running this script"
    exit 1
  fi

  # install jupyterlab
  pipx install jupyterlab --include-deps
  pipx ensurepath
  echo "🥳 jupyterlab has been installed\n\n"
else
  echo "🥳 jupyterlab is already installed\n\n"
fi

echo "👷 Starting jupyterlab in background..."
echo "check logs at ${LOG_PATH}"
echo "Server base: ${SERVER_BASE_PATH}"
echo "Notebook dir: ${NOTEBOOK_DIR}"
mkdir -p "${NOTEBOOK_DIR}" || true
$HOME/.local/bin/jupyter-lab --ServerApp.ip='0.0.0.0' --ServerApp.base_url=${SERVER_BASE_PATH} --NotebookApp.notebook_dir=${NOTEBOOK_DIR} --ServerApp.port=${PORT} --no-browser --ServerApp.token='' --ServerApp.password='' > ${LOG_PATH} 2>&1 &
