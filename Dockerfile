FROM mcr.microsoft.com/powershell:ubuntu-20.04

# To make it easier for build and release pipelines to run apt-get,
# configure apt to not require confirmation (assume the -y argument by default)
ENV DEBIAN_FRONTEND=noninteractive
ARG checkov_version="2.0.983"
ARG tflint_version="v0.34.1"
ARG tflint_azure_ruleset_version="0.14.0"

RUN echo "APT::Get::Assume-Yes \"true\";" > /etc/apt/apt.conf.d/90assumeyes


RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    jq \
    git \
    iputils-ping \
    libcurl4 \
    libicu60 \
    libunwind8 \
    netcat \
    openssl \
    libssl1.0 \
    unzip \
    wget \
    tree \
    sshpass \
    python3-pip \
    python3.8-venv \
    lsb-release \
    gnupg \
    software-properties-common

# install azcopy
RUN wget -O azcopy_v10.tar.gz https://aka.ms/downloadazcopy-v10-linux && \
    tar -xf azcopy_v10.tar.gz --strip-components=1 && \
    mv azcopy /usr/bin && \
    rm azcopy_v10.tar.gz

# install mysql-community-client
# RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 467B942D3A79BD29
# RUN curl -fSL --connect-timeout 30 https://repo.mysql.com/mysql-apt-config_0.8.17-1_all.deb -o /tmp/mysql-apt-config_0.8.17-1_all.deb && \
#     echo mysql-apt-config mysql-apt-config/select-server select mysql-8.0 | debconf-set-selections && \
#     dpkg -i /tmp/mysql-apt-config_0.8.17-1_all.deb && \
#     rm -f /tmp/mysql-apt-config_0.8.17-1_all.deb

# RUN apt-get update && apt-get install -y --no-install-recommends \
#     mysql-community-client

# install PHP 7.4
# RUN add-apt-repository ppa:ondrej/php && \
#     apt-get update && apt-get install -y --no-install-recommends \
#     php7.4 \
#     php7.4-common \
#     php7.4-bcmath \
#     php7.4-json \
#     php7.4-mbstring \
#     php7.4-curl \
#     php7.4-xml \
#     php7.4-mysql

# COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# update python3 and install checkov package
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install --upgrade setuptools && \
    python3 -m pip install checkov=="$checkov_version"

# install tflint
COPY .tflint.hcl ./
RUN wget https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh -O /tmp/tflint_install_linux.sh && \
    chmod +x /tmp/tflint_install_linux.sh && \
    TFLINT_VERSION="$tflint_version" /tmp/tflint_install_linux.sh && \
    sed -i "s/tf_lint_azure_ruleset_version/$tflint_azure_ruleset_version/g" .tflint.hcl && \
    tflint --init

# install latest azure cli
RUN curl -LsS https://aka.ms/InstallAzureCLIDeb | bash

ARG TARGETARCH=amd64
ARG AGENT_VERSION=2.200.2

# install required PowerShell modules
RUN pwsh -Command Set-PSRepository -Name PSGallery -InstallationPolicy Trusted && \
    pwsh -Command Install-Module -Name Az -RequiredVersion 5.3.1 -Scope AllUsers -Repository PSGallery -Confirm:\$False -Force && \
    pwsh -Command Install-Module -Name Az.ResourceGraph -RequiredVersion 0.12.0 -Scope AllUsers -Repository PSGallery -Confirm:\$False -Force && \
    pwsh -Command Install-Module -Name Az.Subscription -RequiredVersion 0.8.1 -Scope AllUsers -Repository PSGallery -Confirm:\$False -Force && \
    pwsh -Command Install-Module -Name VSTeam -RequiredVersion 7.6.1 -Scope AllUsers -Repository PSGallery -Confirm:\$False -Force && \
    pwsh -Command Install-Module -Name PSScriptAnalyzer -RequiredVersion 1.20.0 -Scope AllUsers -Repository PSGallery -Confirm:\$False -Force && \
    pwsh -Command Install-Module -Name Pester -RequiredVersion 5.3.1 -Scope AllUsers -Repository PSGallery -Confirm:\$False -Force

# Clean up
RUN apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /azp
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      AZP_AGENTPACKAGE_URL=https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/pipelines-agent-linux-x64-${AGENT_VERSION}.tar.gz; \
    else \
      AZP_AGENTPACKAGE_URL=https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/pipelines-agent-linux-${TARGETARCH}-${AGENT_VERSION}.tar.gz; \
    fi; \
    curl -LsS "$AZP_AGENTPACKAGE_URL" | tar -xz

COPY ./start.sh .
RUN chmod +x start.sh

ENTRYPOINT [ "./start.sh" ]
