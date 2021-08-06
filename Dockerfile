FROM mcr.microsoft.com/powershell:ubuntu-18.04

# To make it easier for build and release pipelines to run apt-get,
# configure apt to not require confirmation (assume the -y argument by default)
ENV DEBIAN_FRONTEND=noninteractive
ARG checkov_version="2.0.297"
ARG tflint_version="v0.30.0"
ARG tflint_azure_ruleset_version="0.11.0"

RUN echo "APT::Get::Assume-Yes \"true\";" > /etc/apt/apt.conf.d/90assumeyes

RUN curl -fSL --connect-timeout 30 https://repo.mysql.com/mysql-apt-config_0.8.17-1_all.deb -o /tmp/mysql-apt-config_0.8.17-1_all.deb && \
    echo mysql-apt-config mysql-apt-config/select-server select mysql-8.0 | debconf-set-selections && \
    dpkg -i /tmp/mysql-apt-config_0.8.17-1_all.deb && \
    rm -f /tmp/mysql-apt-config_0.8.17-1_all.deb

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
    libssl1.0 \
    unzip \
    wget \
    tree \
    sshpass \
    python3-pip \
    python3.7 \
    python3.7-venv \
    mysql-community-client
    
# update python3 and install checkov package
RUN rm /usr/bin/python3 && \
    ln -s python3.7 /usr/bin/python3 && \
    python3 -m pip install --upgrade pip && \
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
ARG AGENT_VERSION=2.185.1

# install required PowerShell modules
RUN pwsh -Command Set-PSRepository -Name PSGallery -InstallationPolicy Trusted && \
    pwsh -Command Install-Module -Name Az -RequiredVersion 5.3.1 -Scope AllUsers -Repository PSGallery -Confirm:\$False -Force && \
    pwsh -Command Install-Module -Name Az.ResourceGraph -RequiredVersion 0.11.0 -Scope AllUsers -Repository PSGallery -Confirm:\$False -Force && \
    pwsh -Command Install-Module -Name Az.Subscription -RequiredVersion 0.7.3 -Scope AllUsers -Repository PSGallery -Confirm:\$False -Force && \
    pwsh -Command Install-Module -Name VSTeam -RequiredVersion 7.3.0 -Scope AllUsers -Repository PSGallery -Confirm:\$False -Force && \
    pwsh -Command Install-Module -Name PSScriptAnalyzer -RequiredVersion 1.19.1 -Scope AllUsers -Repository PSGallery -Confirm:\$False -Force && \
    pwsh -Command Install-Module -Name Pester -RequiredVersion 5.2.2 -Scope AllUsers -Repository PSGallery -Confirm:\$False -Force
    
# Clean up
RUN apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /azp
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      AZP_AGENTPACKAGE_URL=https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz; \
    else \
      AZP_AGENTPACKAGE_URL=https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-linux-${TARGETARCH}-${AGENT_VERSION}.tar.gz; \
    fi; \
    curl -LsS "$AZP_AGENTPACKAGE_URL" | tar -xz

COPY ./start.sh .
RUN chmod +x start.sh

ENTRYPOINT [ "./start.sh" ]
