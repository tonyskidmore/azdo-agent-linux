FROM mcr.microsoft.com/powershell:ubuntu-18.04

# To make it easier for build and release pipelines to run apt-get,
# configure apt to not require confirmation (assume the -y argument by default)
ENV DEBIAN_FRONTEND=noninteractive
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
    libssl1.0 \
    unzip \
    wget \
    tree \
  && rm -rf /var/lib/apt/lists/*

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
