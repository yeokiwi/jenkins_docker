#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# escape=`

ARG REPO=mcr.microsoft.com/dotnet/framework/runtime
FROM $REPO:4.8-windowsservercore-ltsc2019

# Install NuGet CLI
ENV NUGET_VERSION=5.8.1
RUN mkdir "%ProgramFiles%\NuGet\latest" \
    && curl -fSLo "%ProgramFiles%\NuGet\nuget.exe" https://dist.nuget.org/win-x86-commandline/v%NUGET_VERSION%/nuget.exe \
    && mklink "%ProgramFiles%\NuGet\latest\nuget.exe" "%ProgramFiles%\NuGet\nuget.exe"

# Install VS components
RUN \
    # Install VS Test Agent
    curl -fSLo vs_TestAgent.exe https://download.visualstudio.microsoft.com/download/pr/5c555b0d-fffd-45a2-9929-4a5bb59479a4/521a04a4647eefe3e1364cfdcbbc5143f829cfcbd40e325afd330916daa3c075/vs_TestAgent.exe \
    && start /w vs_TestAgent --quiet --norestart --nocache --wait \
    && powershell -Command "if ($err = dir $Env:TEMP -Filter dd_setup_*_errors.log | where Length -gt 0 | Get-Content) { throw $err }" \
    && del vs_TestAgent.exe \
    \
    # Install VS Build Tools
    && curl -fSLo vs_BuildTools.exe https://download.visualstudio.microsoft.com/download/pr/5c555b0d-fffd-45a2-9929-4a5bb59479a4/45fd615bc29fadc5201483dad883e635c0ceecb0bddf0f613edf6093cb431a27/vs_BuildTools.exe \
    && start /w vs_BuildTools ^ \
        --add Microsoft.VisualStudio.Workload.MSBuildTools ^ \
        --add Microsoft.VisualStudio.Workload.NetCoreBuildTools ^ \
        --add Microsoft.Net.Component.4.8.SDK ^ \
        --add Microsoft.Component.ClickOnce.MSBuild ^ \
        --add Microsoft.VisualStudio.Component.WebDeploy ^ \
		--add Microsoft.VisualStudio.Workload.VCTools ^ \
		--add Microsoft.VisualStudio.Component.VC.CLI.Support ^ \
		--add Microsoft.VisualStudio.Component.VC.140 ^ \
		--add Microsoft.VisualStudio.Component.Windows10SDK.18362 ^ \
		--add Microsoft.VisualStudio.Component.VC.CMake.Project ^ \
		--add Microsoft.VisualStudio.Component.Windows81SDK ^ \
        --quiet --norestart --nocache --wait \
    && powershell -Command "if ($err = dir $Env:TEMP -Filter dd_setup_*_errors.log | where Length -gt 0 | Get-Content) { throw $err }" \
    && del vs_BuildTools.exe \
    \
    # Trigger dotnet first run experience by running arbitrary cmd
    && "%ProgramFiles%\dotnet\dotnet" help \
    \
    # Workaround for issues with 64-bit ngen
    && %windir%\Microsoft.NET\Framework64\v4.0.30319\ngen uninstall "%ProgramFiles(x86)%\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\SecAnnotate.exe" \
    && %windir%\Microsoft.NET\Framework64\v4.0.30319\ngen uninstall "%ProgramFiles(x86)%\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\WinMDExp.exe" \
    \
    # ngen assemblies queued by VS installers
    && %windir%\Microsoft.NET\Framework64\v4.0.30319\ngen update \
    && %windir%\Microsoft.NET\Framework\v4.0.30319\ngen update \
    \
    # Cleanup
    && (for /D %i in ("%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\*") do rmdir /S /Q "%i") \
    && (for %i in ("%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\*") do if not "%~nxi" == "vswhere.exe" del "%~i") \
    && powershell Remove-Item -Force -Recurse "%TEMP%\*" \
    && rmdir /S /Q "%ProgramData%\Package Cache"

# Install web targets
RUN curl -fSLo MSBuild.Microsoft.VisualStudio.Web.targets.zip https://dotnetbinaries.blob.core.windows.net/dockerassets/MSBuild.Microsoft.VisualStudio.Web.targets.2021.03.zip \
    && tar -zxf MSBuild.Microsoft.VisualStudio.Web.targets.zip -C "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\BuildTools\MSBuild\Microsoft\VisualStudio\v16.0" \
    && del MSBuild.Microsoft.VisualStudio.Web.targets.zip

ENV ROSLYN_COMPILER_LOCATION="C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\Roslyn"

# Set PATH in one layer to keep image size down.
RUN powershell setx /M PATH $(${Env:PATH} \
    + \";${Env:ProgramFiles}\NuGet\" \
    + \";${Env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\TestAgent\Common7\IDE\CommonExtensions\Microsoft\TestWindow\" \
    + \";${Env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\" \
    + \";${Env:ProgramFiles(x86)}\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\" \
    + \";${Env:ProgramFiles(x86)}\Microsoft SDKs\ClickOnce\SignTool\")

# Install Targeting Packs
RUN powershell " \
    $ErrorActionPreference = 'Stop'; \
    $ProgressPreference = 'SilentlyContinue'; \
    @('4.0', '4.5.2', '4.6.2', '4.7.2', '4.8') \
    | %{ \
        Invoke-WebRequest \
            -UseBasicParsing \
            -Uri https://dotnetbinaries.blob.core.windows.net/referenceassemblies/v${_}.zip \
            -OutFile referenceassemblies.zip; \
        Expand-Archive referenceassemblies.zip -DestinationPath \"${Env:ProgramFiles(x86)}\Reference Assemblies\Microsoft\Framework\.NETFramework\" -Force; \
        Remove-Item -Force referenceassemblies.zip; \
    }"

ADD win64 win64
COPY ["PublicAssemblies", "C:/Program Files (x86)/Microsoft Visual Studio 14.0/Common7/IDE/PublicAssemblies/"]


# $ProgressPreference: https://github.com/PowerShell/PowerShell/issues/2138#issuecomment-251261324
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# enable TLS 1.2
# https://docs.microsoft.com/en-us/system-center/vmm/install-tls?view=sc-vmm-1801
# https://docs.microsoft.com/en-us/windows-server/identity/ad-fs/operations/manage-ssl-protocols-in-ad-fs#enable-tls-12
RUN Write-Host 'Enabling TLS 1.2 (https://githubengineering.com/crypto-removal-notice/) ...'; \
	$tls12RegBase = 'HKLM:\\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2'; \
	if (Test-Path $tls12RegBase) { throw ('"{0}" already exists!' -f $tls12RegBase) }; \
	New-Item -Path ('{0}/Client' -f $tls12RegBase) -Force; \
	New-Item -Path ('{0}/Server' -f $tls12RegBase) -Force; \
	New-ItemProperty -Path ('{0}/Client' -f $tls12RegBase) -Name 'DisabledByDefault' -PropertyType DWORD -Value 0 -Force; \
	New-ItemProperty -Path ('{0}/Client' -f $tls12RegBase) -Name 'Enabled' -PropertyType DWORD -Value 1 -Force; \
	New-ItemProperty -Path ('{0}/Server' -f $tls12RegBase) -Name 'DisabledByDefault' -PropertyType DWORD -Value 0 -Force; \
	New-ItemProperty -Path ('{0}/Server' -f $tls12RegBase) -Name 'Enabled' -PropertyType DWORD -Value 1 -Force; \
	Write-Host 'Complete.'

ENV JAVA_HOME C:\\openjdk-8
RUN $newPath = ('{0}\bin;{1}' -f $env:JAVA_HOME, $env:PATH); \
	Write-Host ('Updating PATH: {0}' -f $newPath); \
	setx /M PATH $newPath; \
	Write-Host 'Complete.'

# https://adoptopenjdk.net/upstream.html
# >
# > What are these binaries?
# >
# > These binaries are built by Red Hat on their infrastructure on behalf of the OpenJDK jdk8u and jdk11u projects. The binaries are created from the unmodified source code at OpenJDK. Although no formal support agreement is provided, please report any bugs you may find to https://bugs.java.com/.
# >
ENV JAVA_VERSION 8u292
ENV JAVA_URL https://github.com/AdoptOpenJDK/openjdk8-upstream-binaries/releases/download/jdk8u292-b10/OpenJDK8U-jdk_x64_windows_8u292b10.zip
# https://github.com/docker-library/openjdk/issues/320#issuecomment-494050246
# >
# > I am the OpenJDK 8 and 11 Updates OpenJDK project lead.
# > ...
# > While it is true that the OpenJDK Governing Board has not sanctioned those releases, they (or rather we, since I am a member) didn't sanction Oracle's OpenJDK releases either. As far as I am aware, the lead of an OpenJDK project is entitled to release binary builds, and there is clearly a need for them.
# >

RUN Write-Host ('Downloading {0} ...' -f $env:JAVA_URL); \
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
	Invoke-WebRequest -Uri $env:JAVA_URL -OutFile 'openjdk.zip'; \
# TODO signature? checksum?
	\
	Write-Host 'Expanding ...'; \
	New-Item -ItemType Directory -Path C:\temp | Out-Null; \
	Expand-Archive openjdk.zip -DestinationPath C:\temp; \
	Move-Item -Path C:\temp\* -Destination $env:JAVA_HOME; \
	Remove-Item C:\temp; \
	\
	Write-Host 'Removing ...'; \
	Remove-Item openjdk.zip -Force; \
	\
	Write-Host 'Verifying install ...'; \
	Write-Host '  javac -version'; javac -version; \
	Write-Host '  java -version'; java -version; \
	\
	Write-Host 'Complete.'
	
# Jenkins defaults (use --build-arg to override)
ARG JENKINS_VERSION=2.277.4
ARG JENKINS_UC=https://updates.jenkins.io

# Jenkins setup
ENV JENKINS_HOME=c:/jenkins

#Git defaults (use --build-arg to override)
ARG GIT_VERSION=2.31.1

# Promote arg to env
ENV JENKINS_UC=${JENKINS_UC}

# $ProgressPreference will disable download progress info and speed-up download
SHELL ["powershell", "-NoProfile", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; "]

# Note: Install Jenkins master
RUN \
    New-Item -ItemType Directory -Force -Path 'c:/jenkins'; \
    [Net.ServicePointManager]::SecurityProtocol = 'tls12'; \
    Invoke-WebRequest "https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/$env:JENKINS_VERSION/jenkins-war-$env:JENKINS_VERSION.war" -OutFile "c:/jenkins.war" -UseBasicParsing

# Note: Install Git
RUN \
    New-Item -ItemType Directory -Force -Path 'c:/git'; \
    [Net.ServicePointManager]::SecurityProtocol = 'tls12'; \
    Invoke-WebRequest "https://github.com/git-for-windows/git/releases/download/v$env:GIT_VERSION.windows.1/Git-$env:GIT_VERSION-64-bit.exe" -OutFile "$env:TEMP/git.exe" -UseBasicParsing; \
    Start-Process -FilePath "$env:TEMP/git.exe" -ArgumentList '/VERYSILENT', '/NORESTART', '/NOCANCEL', '/SP-', '/DIR="c:/git"' -PassThru | Wait-Process; \
    dir "$env:TEMP" | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

COPY scripts /scripts

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

CMD [ "powershell", "c:/scripts/startup.ps1" ]
