FROM mcr.microsoft.com/devcontainers/base:jammy

# Install packages with apt (including Python and pip)
RUN apt-get update \
	&& apt-get install -y \
	curl \
	git \
	golang \
	ripgrep \
	sudo \
	vim \
	wget \
	jq \
	sshpass \
	zsh \
	python3 \
	python3-pip \
	python3-venv \
	&& rm -rf /var/lib/apt/lists/*

USER vscode

# Install pip packages
RUN pip3 install \
    ansible \
    paramiko \
    pyopenssl \
    pywinrm \
    pre-commit \
    ansible-lint
