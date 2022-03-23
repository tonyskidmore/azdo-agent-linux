# azdo-agent-linux
Azure DevOps Self Hosted Agent Container Image

## Overview

This repository contains a `Dockerfile` and a `start.sh` script based on [Run a self-hosted agent in Docker](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/docker?view=azure-devops#linux).  When built using a [GitHub Actions](https://docs.github.com/en/actions) workflow a container images is created and is accessible at `ghcr.io/tonyskidmore/azdo-agent-linux:latest`.  All available versions can be viewed in [View and manage all versions](https://github.com/tonyskidmore/azdo-agent-linux/pkgs/container/azdo-agent-linux/versions).  

Normally the preferred solution would be provided by Azure Container Registry.  However, this method highlights a mechanism for using the [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry) to provide a similar facility.  


## Trivy

When scanning the Azure DevOps container image with the [Trivy Action](https://github.com/aquasecurity/trivy-action) there a number of issues highlighted.  There is an existing similar [GitHub Issue](https://github.com/microsoft/azure-pipelines-agent/issues/3385) that I added further information to.  Probably worth tracking this issue to see if any progress is made (none yet as of 23rd March 2022).  


For now the action has been set to not fail:  

````bash

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'az-pipelines-agentcontainerimage'
          format: 'table'
          # uncomment to fail on found issues with defined severity
          # exit-code: '1'
          ignore-unfixed: true
          vuln-type: 'os,library'
          severity: 'CRITICAL,HIGH'

````