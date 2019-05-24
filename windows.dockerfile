# gnucash-dev-docker: Docker containers for automated OS setup and dev/build environ for gnucash v3+ binaries and docs
# Copyright (C) 2019 Dale Phurrough <dale@hidale.com>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.


# supports Windows
ARG OS_DIST=mcr.microsoft.com/windows
ARG OS_TAG=1809
FROM $OS_DIST:$OS_TAG

# volume map these to host volumes, else all source and build results will remain in container
# gnucash: contains git clone of gnucash source
# build: build destination of make
VOLUME [ "c:/gnucash", "c:/build" ]

HEALTHCHECK --start-period=30s --interval=60s --timeout=10s \
    CMD dir

# setup the OS build environment; update needs to be included in installs otherwise older package database is cached in docker layer
SHELL ["powershell.exe", "-Command"]

RUN Set-ExecutionPolicy RemoteSigned ; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) ; \
    refreshenv ; \
    choco feature disable --name showDownloadProgress ; \
    mkdir C:/gcdev64 > $null ; \
    Write-Host "===== MSYS2 INSTALL BEGINNING =====" ; \
        #choco install msys2 -y --fail-on-stderr --version 20180531.0.0 -params '/InstallDir:C:\gcdev64\msys2' ; \
        Import-Module "$Env:ChocolateyInstall/helpers/chocolateyInstaller.psm1" ; \
        Get-ChocolateyWebFile -FileFullPath 'C:/gcdev64/msys2-download.tar.xz' \
                            -Url64bit 'http://repo.msys2.org/distrib/x86_64/msys2-base-x86_64-20181211.tar.xz' \
                            -ChecksumType64 'sha256' \
                            -Checksum64 '5CAB863861BC9D414B4DF2CBE0B1BF8B560EB9A19AA637AFABD6F436B572F2E3' \
                            -Url 'http://repo.msys2.org/distrib/i686/msys2-base-i686-20181211.tar.xz' \
                            -ChecksumType 'sha256' \
                            -Checksum '78BE710D0A1F2C70BAC4C51CD4E2CABFB1427A8740F241B3174E7946724993C1' \
                            -PackageName 'msys2-gnucash' ; \
        Get-ChocolateyUnzip -FileFullPath64 'C:/gcdev64/msys2-download.tar.xz' \
                            -Destination 'C:/gcdev64' ; \
        Get-ChocolateyUnzip -FileFullPath64 'C:/gcdev64/msys2-download.tar' \
                            -Destination 'C:/gcdev64' ; \
        rm 'C:/gcdev64/msys2-download.tar*' ; \
        Get-ChildItem 'C:/gcdev64' | Where { $_.PSIsContainer } | Rename-Item -NewName 'msys2' ; \
        cd C:/gcdev64/msys2 ; \
        ./msys2_shell.cmd -defterm -no-start ; \
        Get-Process | where Path -Like 'C:\gcdev64\msys2*' | Stop-Process -Force ; \
        ./msys2_shell.cmd -defterm -no-start -c 'pacman-key --init && pacman-key --populate msys2 && pacman-key --refresh-keys' ; \
        while (!$done) { ; \
            Write-Host "===== MSYS2 UPGRADE STAGE $((++$i)) =====" ; \
            ./msys2_shell.cmd -defterm -no-start -c 'pacman --noconfirm -Syuu | tee /init_update.log' ; \
            $done = (Get-Content ./init_update.log) -match 'there is nothing to do' | Measure-Object | ForEach-Object { $_.Count -eq 2 } ; \
            $done = $done -or ($i -ge 5) ; \
            Get-Process | where Path -Like 'C:\gcdev64\msys2*' | Stop-Process -Force ; \
        } ; \
        rm ./init_update.log ; \
    Write-Host "===== MSYS2 INSTALL FINISHED =====" ; \
    choco install html-help-workshop -y --version 1.32 ; \
    choco install innosetup -y --version 5.5.9.20171105 --installargs '/dir=""""""""C:\Program Files (x86)\inno""""""""' ; \
    Write-Host "There may be a delay at the end of this Docker build stage..."

#RUN DISM /Online /Add-Capability /CapabilityName:"ServerCore.AppCompatibility~~~~0.0.1.0"
#Invoke-WebRequest -Uri https://raw.githubusercontent.com/Gnucash/gnucash-on-windows/master/setup-mingw64.ps1 -OutFile /setup-mingw64.ps1 ; \

# environment vars
#ENV BUILDTYPE=${BUILDTYPE:-cmake-make}

# install startup files
COPY windowsbuild.ps1 /
CMD [ "powershell", "/windowsbuild.ps1" ]