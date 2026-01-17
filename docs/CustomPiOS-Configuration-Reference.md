# CustomPiOS Configuration Reference

This page documents all overridable configuration variables available in CustomPiOS modules. These variables can be set in your `src/config` or `src/config.local` files to customize your distribution build.

## How to Use These Variables

Add any of these variables to your `src/config` file:

```bash
export VARIABLE_NAME=value
```

Or create a `src/config.local` file for local overrides (this file should be gitignored):

```bash
echo "export VARIABLE_NAME=value" > src/config.local
```

---

## Configuration Hierarchy

CustomPiOS loads configuration in this order (later sources override earlier ones):

1. `CustomPiOS/src/modules/*/config` - Module defaults
2. `src/config` - Your distribution config
3. `src/config.local` - Local overrides (gitignored)
4. `src/variants/*/config` - Variant-specific config
5. Environment variables set in CI/CD

For more information about modules and how they work, see the [CustomPiOS Modules documentation](https://github.com/guysoft/CustomPiOS/wiki/Modules).

---

## Common Configuration Examples

### Minimal Configuration

```bash
export DIST_NAME=MyDistro
export DIST_VERSION=1.0.0
export MODULES="base(network)"
```

### Standard ARM Configuration with Docker

```bash
export DIST_NAME=MyDistro
export DIST_VERSION=1.0.0
export MODULES="base(network, docker)"

# Base image configuration
export BASE_IMAGE_ENLARGEROOT=2000
export BASE_IMAGE_RESIZEROOT=500
export BASE_SSH_ENABLE=yes
```

### Example base board: Raspberry Pi OS 64 bits (Lite)

This now requires the image to be present in src/image-NAMEHERE (NAMEHERE=raspberrypiarm64 in this case):

```bash
export DIST_NAME=MyDistro
export DIST_VERSION=1.0.0
export MODULES="base(network, docker)"

# ARM64-specific settings
export BASE_DISTRO=raspios64
export BASE_ARCH=aarch64
export BASE_BOARD=raspberrypiarm64
export BASE_IGNORE_VARIANT_NAME=yes
export BASE_IMAGE_RASPBIAN=no
export BASE_SSH_ENABLE=yes

# Build settings
export BASE_IMAGE_ENLARGEROOT=2000
export BASE_IMAGE_RESIZEROOT=500
```

For more base board selection options and architecture configurations, see [Base Board Selection](https://github.com/guysoft/CustomPiOS/wiki/Building#base-board-selection).

---

## Module: base

Core CustomPiOS module providing fundamental image building capabilities and base system configuration.

**Last Updated:** [`23fcc0c`](https://github.com/guysoft/CustomPiOS/commit/23fcc0c) (2024-12-14)

| Variable                   | Description                                                                         | Default                                                    |
|----------------------------|-------------------------------------------------------------------------------------|------------------------------------------------------------|
| `BASE_VERSION`             | CustomPiOS version.                                                                 | `2.0.0`                                                    |
| `BASE_PRESCRIPT`           | Pre-build script execution.                                                         | (empty)                                                    |
| `BASE_POSTSCRIPT`          | Post-build script execution.                                                        | (empty)                                                    |
| `BASE_BOARD`               | Target board type: "raspberrypiarmhf", "raspberrypiarm64", or other Armbian boards. | `raspberrypiarmhf`                                         |
| `BASE_OS`                  | Operating system target.                                                            | `debian_bookworm`                                          |
| `BASE_IMAGE_PATH`          | Path to the base image for the board.                                               | `${DIST_PATH}/image` or `${DIST_PATH}/image-${BASE_BOARD}` |
| `BASE_IMAGE_RASPBIAN`      | Whether this is a Raspbian image.                                                   | `yes`                                                      |
| `BASE_DISTRO`              | Linux distribution: "raspbian", "raspios64", or "ubuntu".                           | `raspbian`                                                 |
| `BASE_ZIP_IMG`             | Custom or already-extracted image file path (.img, .zip, .7z, .xz).                 | Auto-detected                                              |
| `BASE_USER`                | Default user for the image.                                                         | `pi` (raspbian) / `ubuntu` (ubuntu)                        |
| `BASE_ADD_USER`            | Add base user if it doesn't exist.                                                  | `yes`                                                      |
| `BASE_USER_PASSWORD`       | Password for the base user.                                                         | `raspberry` (raspbian) / `ubuntu` (ubuntu)                 |
| `BASE_RELEASE_COMPRESS`    | Compress the final release image.                                                   | `yes`                                                      |
| `BASE_RELEASE_IMG_NAME`    | Name for the released image.                                                        | `default`                                                  |
| `BASE_RELEASE_ZIP_NAME`    | Name for the released zip file.                                                     | `default`                                                  |
| `BASE_WORKSPACE`           | Build workspace directory.                                                          | `${DIST_PATH}/workspace${WORKSPACE_POSTFIX}`               |
| `BASE_MOUNT_PATH`          | Mount path for image manipulation.                                                  | `${BASE_WORKSPACE}/mount`                                  |
| `BASE_BOOT_MOUNT_PATH`     | Boot partition mount path in image.                                                 | `boot/firmware`                                            |
| `BASE_ROOT_PARTITION`      | Root partition number in the image.                                                 | `2`                                                        |
| `BASE_IMAGE_ENLARGEROOT`   | Pre-build root partition enlargement in MB.                                         | `200`                                                      |
| `BASE_IMAGE_RESIZEROOT`    | Post-build root partition resize in MB (minimum size + value).                      | `200`                                                      |
| `BASE_APT_CACHE`           | Local directory for APT cache bind mount.                                           | `${BASE_WORKSPACE}/aptcache`                               |
| `BASE_APT_PROXY`           | APT proxy server (host:port format, e.g., apt-cacher-ng).                           | (empty)                                                    |
| `BASE_APT_MIRROR`          | Alternative APT mirror URL.                                                         | (empty)                                                    |
| `BASE_PYPI_INDEX`          | Alternative PyPI index URL (e.g., devpi proxy).                                     | (empty)                                                    |
| `BASE_OVERRIDE_HOSTNAME`   | Override the system hostname.                                                       | `${DIST_NAME,,}`                                           |
| `BASE_USE_ALT_DNS`         | Alternative DNS servers during build (space-separated).                             | (empty)                                                    |
| `BASE_BUILD_REPO_MIRROR`   | Git mirror for clones instead of original remotes.                                  | (empty)                                                    |
| `BASE_SSH_ENABLE`          | Enable SSH daemon.                                                                  | `yes`                                                      |
| `BASE_COMMIT`              | Git commit hash of CustomPiOS used in build.                                        | Auto-detected                                              |
| `BASE_CONFIG_MEMSPLIT`     | Memory split configuration.                                                         | `default`                                                  |
| `BASE_CONFIG_TIMEZONE`     | System timezone.                                                                    | `default`                                                  |
| `BASE_CONFIG_LOCALE`       | System locale.                                                                      | `default`                                                  |
| `BASE_CONFIG_KEYBOARD`     | Keyboard layout.                                                                    | `default`                                                  |
| `BASE_ARCH`                | Architecture: "armv7l", "arm64", or "aarch64".                                      | `armv7l`                                                   |
| `BASE_IGNORE_VARIANT_NAME` | Disable variant name appending to image name.                                       | `no`                                                       |
| `BASE_ENABLE_UART`         | Enable UART console on boot.                                                        | `no`                                                       |
| `BASE_APT_CLEAN`           | Clean APT cache after build completion.                                             | `yes`                                                      |

### Raspberry Pi Imager Integration

These distribution-level variables configure metadata for Raspberry Pi Imager JSON generation:

| Variable                 | Description                                                    | Default                |
|--------------------------|----------------------------------------------------------------|------------------------|
| `RPI_IMAGER_NAME`        | Display name in Raspberry Pi Imager.                           | `${DIST_NAME}`         |
| `RPI_IMAGER_DESCRIPTION` | Description shown in Raspberry Pi Imager.                      | (required)             |
| `RPI_IMAGER_WEBSITE`     | Project website URL.                                           | (required)             |
| `RPI_IMAGER_ICON`        | Icon image URL (PNG format recommended).                       | (required)             |

---

## Module: network

Configures network settings including WiFi power save and network management.

| Variable                  | Description                                                      | Default |
|---------------------------|------------------------------------------------------------------|---------|
| `NETWORK_DISABLE_PWRSAVE` | Disable power save for WiFi module.                              | `yes`   |
| `NETWORK_PWRSAVE_TYPE`    | Power save implementation type: "rclocal", "service", or "udev". | `udev`  |
| `NETWORK_WPA_SUPPLICANT`  | Enable WPA-Supplicant boot folder support (pre-Bookworm).        | `no`    |
| `NETWORK_NETWORK_MANAGER` | Enable Network Manager boot folder support (Bookworm).           | `yes`   |

---

## Module: admin-toolkit

Provides administrative tools for user management, SSH configuration, firewall setup, and system administration tasks.

| Variable | Description | Default |
|----------|-------------|---------|
| `ADMIN_TOOLKIT_NAME` | Username for the new admin user to add. If left "default", no user will be added. | `default` |
| `ADMIN_TOOLKIT_FULLNAME` | GECOS field (full name) of the new account. If left "default", this is skipped. | `default` |
| `ADMIN_TOOLKIT_PASSWORD` | Override password for the new user, otherwise uses image default (raspberry). | `default` |
| `ADMIN_TOOLKIT_PI_NO_SUDO` | Remove pi from the sudoers file. Set to "yes" to configure. | `no` |
| `ADMIN_TOOLKIT_HOSTNAME_CHANGE_SCRIPT` | Include a hostname change script. Set to "yes" to include. | `no` |
| `ADMIN_TOOLKIT_SSH` | Public SSH key for user connections. Format: "ssh-rsa SzYtCpyRUU1fvLXvWlezJw...==" | `default` |
| `ADMIN_TOOLKIT_SSH_NO_PASS` | Disable SSH password logins (only if SSH key is set). Set to "yes" to configure. | `no` |
| `ADMIN_TOOLKIT_SSH_ALLOW_ONLY_CREATED_USER` | Allow only the newly created user to SSH. Set to "yes" to configure. | `no` |
| `ADMIN_TOOLKIT_UPDATE_PACKAGES` | Update all packages (apt-get update && apt-get upgrade). Set to "yes" to configure. | `no` |
| `ADMIN_TOOLKIT_INSTALL_LIST` | Package list to install. Use quotes for multiple packages (space-separated). | `no` |
| `ADMIN_TOOLKIT_UFW_INSTALL` | Install UFW firewall. Unless other ports are specified, only SSH port 22 will be open. | `no` |
| `ADMIN_TOOLKIT_UFW_PORTS_TCP` | TCP ports to allow through UFW firewall (comma-separated list). | `no` |
| `ADMIN_TOOLKIT_UFW_PORTS_UDP` | UDP ports to allow through UFW firewall (comma-separated list). | `no` |
| `ADMIN_TOOLKIT_UFW_ENABLE_LOGGING` | Enable UFW logging. Set to "yes" to configure. | `no` |
| `ADMIN_TOOLKIT_REMOVE_NETWORK_MANAGER` | Remove Network Manager (causes different MAC on wifi devices). Set to "yes" to configure. | `no` |
| `ADMIN_TOOLKIT_HDMI_SCRIPTS` | Install FullPageOS HDMI scripts for turning TV on/off. Set to "yes" to configure. | `no` |
| `ADMIN_TOOLKIT_CRON_JOB` | Install a cron job. Set to "yes" to configure. | `no` |
| `ADMIN_TOOLKIT_CRON_USER` | Cron jobs username. Default is 'pi'. | `pi` |
| `ADMIN_TOOLKIT_SYSTEM_CRON` | Install root user cron jobs (for auto-reboot, etc.). Set to "yes" to configure. | `no` |
| `ADMIN_TOOLKIT_USER_SCRIPTS` | Add custom scripts to user's home directory. Set to "yes" to configure. | `no` |
| `ADMIN_TOOLKIT_USER_SCRIPTS_NAME` | Username for user-defined scripts. Default is 'pi'. | `pi` |
| `ADMIN_TOOLKIT_SCREEN_ROTATION` | Screen rotation value. Requires GUI module and Pi 4. Options: "normal", "inverted", "left", "right". | `normal` |

---

## Module: auto-hotspot

Creates a WiFi hotspot automatically when no known networks are available.

| Variable | Description | Default |
|----------|-------------|---------|
| `AUTO_HOTSPOT_NAME` | Name of the hotspot network. | `${DIST_NAME,,}` |
| `AUTO_HOTSPOT_PASSWORD` | Hotspot WiFi password. | `raspberry` |
| `AUTO_HOTSPOT_CHANNEL` | WiFi channel for hotspot. | `6` |

---

## Module: cockpit-install

Installs Cockpit web-based system administration interface.

| Variable | Description | Default |
|----------|-------------|---------|
| `COCKPIT_INSTALL_DISABLE_COCKPIT_SOCKET` | Disable the Cockpit web socket. Useful if you have an existing Cockpit server. | `no` |

---

## Module: docker

Installs Docker and Docker Compose with optional auto-start configuration.

| Variable | Description | Default |
|----------|-------------|---------|
| `DOCKER_COMPOSE` | Install Docker Compose. | `yes` |
| `DOCKER_ADD_USER_TO_GROUP` | Add the default user to the docker group. | `no` |
| `DOCKER_COMPOSE_BOOT` | Start Docker Compose on boot. | `yes` |
| `DOCKER_COMPOSE_BOOT_PATH` | Path to docker-compose.yml for startup. | `default` |

---

## Module: ffmpeg

Compiles and installs FFmpeg from source with hardware acceleration support.

| Variable | Description | Default |
|----------|-------------|---------|
| `FFMPEG_CLEANUP` | Clean up FFmpeg build artifacts after installation. | `yes` |

---

## Module: gui

Provides graphical user interface with X11 and GPU acceleration support.

| Variable | Description | Default |
|----------|-------------|---------|
| `GUI_INCLUDE_ACCELERATION` | Include GPU acceleration for GUI. | `yes` |
| `GUI_STARTUP_SCRIPT` | Script that starts in the session. Session closes if this script ends. | `xterm` |

---

## Module: kernel

Compiles custom Linux kernel from source for Raspberry Pi.

| Variable | Description | Default |
|----------|-------------|---------|
| `KERNEL_TYPE` | Kernel type to build: "all" or specific types. | `all` |
| `KERNEL_CONFIG_APPEND` | Additional kernel configuration to append. | (empty) |
| `KERNEL_COMMIT` | Git commit/branch for kernel source. | `rpi-4.19.y` |
| `KERNEL_URL` | URL to fetch kernel source from. | `https://github.com/raspberrypi/linux/archive` |
| `KERNEL_SOURCE_CLEANUP` | Clean up kernel source after compilation. | `no` |
| `KERNEL_EXPORT` | Export compiled kernel artifacts. | `yes` |
| `KERNEL_EXPORT_NAME` | Name prefix for exported kernel. | `kernel-${KERNEL_COMMIT}` |

---

## Module: mysql

Installs and configures MySQL/MariaDB database server.

| Variable | Description | Default |
|----------|-------------|---------|
| `MYSQL_USER` | MySQL user account (not root, as root is CLI-only). | `pi` |
| `MYSQL_USER_PASSWORD` | Password for the MySQL user. | `raspberry` |

---

## Module: pkgupgrade

Performs system package upgrades during image build.

| Variable | Description | Default |
|----------|-------------|---------|
| `PKGUPGRADE_DISTUPGRADE` | Perform distribution upgrade. Options: "y" or "n". | `y` |
| `PKGUPGRADE_DISTUPGRADE_METHOD` | Upgrade method: "upgrade" or "full-upgrade". | `full-upgrade` |
| `PKGUPGRADE_USE_PREINSTALLER` | Use preinstaller for package upgrades. Options: "y" or "n". | `n` |
| `PKGUPGRADE_PRE_INSTALL_PKGS` | Packages to pre-install before upgrade. | (empty) |
| `PKGUPGRADE_CLEANUP` | Clean up APT cache after upgrade. Options: "y" or "n". | `y` |

---

## Module: raspicam

Enables Raspberry Pi Camera support in the kernel.

*This module has no configurable variables.*

---

## Module: readonly

Configures the root filesystem as read-only for SD card longevity.

*This module has no configurable variables.*

---

## Module: usage-statistics

Collects anonymous usage statistics for CustomPiOS distributions.

| Variable | Description | Default |
|----------|-------------|---------|
| `USAGE_STATISTICS_URL` | URL of the tracking server for anonymous statistics. | `https://custompios-tracking.gnethomelinux.com` |
| `USAGE_STATISTICS_VERSION_FILE` | File path that stores the distro version. | `/etc/${DIST_NAME,,}_version` |
| `USAGE_STATISTICS_VARIANT_FILE` | File path that stores the distro variant. | `/etc/dist_variant` |

---

## Module: usbconsole

Enables USB serial console for headless debugging.

*This module has no configurable variables.*

---

> **Note:** This table represents the latest devel branch of CustomPiOS. Variable availability and defaults may change between versions. Always refer to the specific CustomPiOS commit SHA you're using in your builds.

**Last Updated:** 2026-01-17
**CustomPiOS Version:** 2.0.0 (devel)
