# Releasing with Github Actions

This guide explains how to release your CustomPiOS-based distribution using GitHub Actions for automated builds, including image creation, compression, and optional Raspberry Pi Imager JSON generation.

## Repository Directory Layout

```
your-distro/
├── .github/
│   └── workflows/
│       └── release.yaml          # GitHub Actions workflow
├── src/
│   ├── config                     # Main configuration file
│   ├── config.local               # Local overrides (gitignored)
│   ├── image/                     # Base image directory (auto-detect)
│   │   └── *-raspbian.zip         # Downloaded base images
│   ├── image-VARIANT/             # Variant-specific images (e.g., image-raspberrypiarm64)
│   │   └── *.img.xz               # Specific OS images for your board
│   ├── modules/
│   │   └── your-distro/           # Your custom module
│   │       ├── config             # Module configuration
│   │       ├── start_chroot_script # Main installation script
│   │       └── filesystem/        # Files to copy to image
│   └── build_dist                 # Build script
└── CustomPiOS/                    # Checked out during CI (not in repo)
```

## Quick Start

### 1. Create the Workflow File

Create `.github/workflows/release.yaml` in your repository:

```yaml
name: Release
on:
  #  Depends on your release strategy, we went for release branches (e.g. release/1.0.0 or release/1.0.0-rc1) 
  push:
    branches:
      - 'release/*'

jobs:
  release:
    if: startsWith(github.ref, 'refs/heads/release')
    runs-on: ubuntu-24.04-arm
    steps:
    - name: Install Dependencies
      run: |
        sudo apt update
        sudo apt install coreutils p7zip-full qemu-user-static python3-git

    - name: Checkout CustomPiOS
      uses: actions/checkout@v6.0.1
      with:
        repository: 'guysoft/CustomPiOS'
        path: CustomPiOS
        # Pin to specific commit on devel, tip: use Mend Renovate to auto-update this using Pull-Requests! 
        # This way your chances of dealing with a broken build are minimalized.
        ref: "79b77a4c1a34ef551ab09e9bd84710d048b65e55"

    - name: Checkout Project Repository
      uses: actions/checkout@v6.0.1
      with:
        path: repository
        submodules: true
        fetch-depth: 0

    - name: Install GitVersion
      uses: gittools/actions/gitversion/setup@v4.2.0
      with:
        versionSpec: '6.x'

    - name: Use GitVersion
      uses: gittools/actions/gitversion/execute@v4.2.0
      id: gitversion
      with:
        targetPath: repository

    # Example of how to download a custom image to image-*, but note `BASE_BOARD` must support this.
#    - name: Download Base Image
#      run: |    
#        cd repository/src/image-raspberrypiarm64
#        wget -c --trust-server-names 'https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-12-04/2025-12-04-raspios-trixie-arm64-lite.img.xz'
  
    - name: Download Base Image (default)
      run: |
        cd repository/src/image
        wget -c --trust-server-names 'LINK_HERE'

    - name: Update CustomPiOS Paths
      run: |
        cd repository/src
        ../../CustomPiOS/src/update-custompios-paths

    - name: Set release image version
      run: |
        source repository/src/config
        echo "DIST_VERSION=${{ steps.gitversion.outputs.majorMinorPatch }}" > repository/src/config.local

    - name: Build Image
      run: |
        sudo modprobe loop
        cd repository/src
        sudo bash -x ./build_dist

    - name: Copy output
      id: copy
      run: |
        source repository/src/config
        TAG=${DIST_VERSION}
        IMAGE=your-distro-$TAG
        cp repository/src/workspace/*.img $IMAGE.img
        echo "tag=$TAG" >> $GITHUB_OUTPUT
        echo "image=$IMAGE" >> $GITHUB_OUTPUT

    - name: Zip Image
      run: |
        zip ${{ steps.copy.outputs.image }}.zip ${{ steps.copy.outputs.image }}.img
        echo "File size of ${{ steps.copy.outputs.image }}.zip"
        stat --printf="%s" ${{ steps.copy.outputs.image }}.zip

    - name: Create release
      uses: actions/create-release@v1
      id: create_release
      with:
        draft: false
        prerelease: ${{ contains(steps.copy.outputs.tag, 'rc') || contains(steps.copy.outputs.tag, 'unstable') }}
        tag_name: ${{ steps.copy.outputs.tag }}
        release_name: YourDistro ${{ steps.copy.outputs.image }}
        body: "Release notes will be added manually."
      env:
        GITHUB_TOKEN: ${{ github.token }}

    - name: Upload image zip
      uses: actions/upload-release-asset@v1
      id: upload_zip
      env:
        GITHUB_TOKEN: ${{ github.token }}
      with:
        upload_url: ${{ steps.create_release.outputs.upload_url }}
        asset_path: ${{ steps.copy.outputs.image }}.zip
        asset_name: ${{ steps.copy.outputs.image }}.zip
        asset_content_type: application/zip

    - name: Generate Raspberry Pi Imager JSON
      run: |
        source repository/src/config
        python3 CustomPiOS/src/custompios_core/make_rpi-imager-snipplet.py \
          --rpi_imager_url "${{ steps.upload_zip.outputs.browser_download_url }}" \
          -- default

    - name: Upload Raspberry Pi Imager JSON
      uses: actions/upload-release-asset@v1
      env:
        GITHUB_TOKEN: ${{ github.token }}
      with:
        upload_url: ${{ steps.create_release.outputs.upload_url }}
        asset_path: repository/src/workspace/your-distro-rpi-imager-default.json
        asset_name: your-distro-rpi-imager.json
        asset_content_type: application/json
```

### 2. Trigger a Release

Push to a release branch to trigger the workflow:

```bash
git checkout -b release/1.0.0
git push origin release/1.0.0
```

## Important Configuration Points

### CustomPiOS Path and Version

The workflow checks out CustomPiOS to a specific commit for reproducible builds:

```yaml
- name: Checkout CustomPiOS
  uses: actions/checkout@v6.0.1
  with:
    repository: 'guysoft/CustomPiOS'
    path: CustomPiOS
    ref: "79b77a4c1a34ef551ab09e9bd84710d048b65e55"  # Pin this!
```

**Why pin the commit?**
- Ensures reproducible builds
- Prevents breaking changes from affecting your release
- Allows you to test and upgrade CustomPiOS deliberately

**How to update:**
1. Test with a newer CustomPiOS commit in development
2. Once verified, update the `ref` value
3. Document the CustomPiOS version in your release notes

### GitVersion for Semantic Versioning

GitVersion automatically calculates version numbers based on your git history:

```yaml
- name: Use GitVersion
  uses: gittools/actions/gitversion/execute@v4.2.0
  id: gitversion
  with:
    targetPath: repository
```

The version is then injected into your image:

```yaml
- name: Set release image version
  run: |
    source repository/src/config
    echo "DIST_VERSION=${{ steps.gitversion.outputs.majorMinorPatch }}" > repository/src/config.local
```

**Available GitVersion outputs:**
- `majorMinorPatch` - e.g., `1.0.0`
- `semVer` - e.g., `1.0.0-beta.1`
- `fullSemVer` - e.g., `1.0.0-beta.1+5`

### Base Image Selection

#### Option 1: Specific OS Image (Recommended for Production)

If you need a specific OS variant (like arm64), download directly:

```yaml
- name: Download Base Image
  run: |
    cd repository/src/image-raspberrypiarm64
    wget -c --trust-server-names 'https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-12-04/2025-12-04-raspios-trixie-arm64-lite.img.xz'
```

Your `src/config` should specify:

```bash
export BASE_DISTRO=raspios64
export BASE_ARCH=aarch64
export BASE_BOARD=raspberrypiarm64
export BASE_IGNORE_VARIANT_NAME=yes
export BASE_IMAGE_RASPBIAN=no
```

> **Note:** The directory name `image-VARIANT` (e.g., `image-raspberrypiarm64`) tells CustomPiOS exactly which image to use. This is particularly important when building for specific architectures.

For a complete list of supported base boards and architecture options, see [Base Board Selection](https://github.com/guysoft/CustomPiOS/wiki/Building#base-board-selection).

#### Option 2: Auto-Detect Base Image

For standard Raspbian builds, you can use the `image/` directory with auto-detection:

```yaml
- name: Download Base Image
  run: |
    cd repository/src/image
    wget -c --trust-server-names 'https://downloads.raspberrypi.com/raspbian_lite/images/raspbian_lite-latest/raspbian-lite.zip'
```

CustomPiOS will automatically detect the most recent `*-raspbian.zip` file in `src/image/`.

> **Advanced:** You can further constrain the expected image using `src/config` variables. See the [Base Image Configuration](Base-Image-Configuration) page for details on variables like `BASE_DISTRO`, `BASE_ARCH`, `BASE_BOARD`, `BASE_IGNORE_VARIANT_NAME`, and `BASE_IMAGE_RASPBIAN`.

### Update CustomPiOS Paths

This critical step links your distro to the CustomPiOS framework:

```yaml
- name: Update CustomPiOS Paths
  run: |
    cd repository/src
    ../../CustomPiOS/src/update-custompios-paths
```

This script updates symlinks and paths so your distro's `build_dist` script can find CustomPiOS modules and utilities.

### Raspberry Pi Imager Integration (Optional)

The workflow can generate a JSON metadata file for Raspberry Pi Imager, making your distribution discoverable in the official imaging tool. This requires:

1. Setting `RPI_IMAGER_*` variables in your `src/config`
2. Adding steps to generate and upload the JSON file

See the [Raspberry Pi Imager Integration](#raspberry-pi-imager-integration) section below for complete configuration details.

### Building the Image

```yaml
- name: Build Image
  run: |
    sudo modprobe loop        # Required for loopback device support
    cd repository/src
    sudo bash -x ./build_dist # -x enables debug output
```

The build process:
1. Mounts the base image
2. Executes chroot scripts from your modules
3. Installs packages and configures the system
4. Unmounts and resizes the image
5. Outputs to `src/workspace/*.img`

### Raspberry Pi Imager Integration

The workflow generates a JSON metadata file for Raspberry Pi Imager integration:

```yaml
- name: Generate Raspberry Pi Imager JSON
  run: |
    source repository/src/config
    python3 CustomPiOS/src/custompios_core/make_rpi-imager-snipplet.py \
      --rpi_imager_url "${{ steps.upload_zip.outputs.browser_download_url }}" \
      -- default

- name: Upload Raspberry Pi Imager JSON
  uses: actions/upload-release-asset@v1
  env:
    GITHUB_TOKEN: ${{ github.token }}
  with:
    upload_url: ${{ steps.create_release.outputs.upload_url }}
    asset_path: repository/src/workspace/your-distro-rpi-imager-default.json
    asset_name: your-distro-rpi-imager.json
    asset_content_type: application/json
```

**How it works:**

1. After the image zip is uploaded, its download URL is captured
2. The `make_rpi-imager-snipplet.py` script generates a JSON file using:
   - `RPI_IMAGER_NAME` - Display name from your config
   - `RPI_IMAGER_DESCRIPTION` - Description from your config
   - `RPI_IMAGER_WEBSITE` - Website URL from your config
   - `RPI_IMAGER_ICON` - Icon URL from your config
   - Download URL from the uploaded release asset
3. The JSON is uploaded as a release asset

**Configuration requirements:**

Make sure your `src/config` includes these variables:

```bash
export RPI_IMAGER_NAME="${DIST_NAME}"
export RPI_IMAGER_DESCRIPTION="Your distribution description"
export RPI_IMAGER_WEBSITE="https://github.com/your-org/your-distro"
export RPI_IMAGER_ICON="https://example.com/icon.png"
```

Users can then add your JSON URL to Raspberry Pi Imager as a custom OS source.

## Pre-release Detection

The workflow automatically detects pre-releases:

```yaml
prerelease: ${{ contains(steps.copy.outputs.tag, 'rc') || contains(steps.copy.outputs.tag, 'unstable') }}
```

Branch naming examples:
- `release/1.0.0` → Full release
- `release/1.0.0-rc1` → Pre-release
- `release/1.0.0-unstable` → Pre-release

## Troubleshooting

### Build Fails with "No space left on device"

Increase the `BASE_IMAGE_ENLARGEROOT` value in `src/config`:

```bash
export BASE_IMAGE_ENLARGEROOT=2000  # Increase from default 200MB
```

### Modules Not Found

Ensure `update-custompios-paths` runs before `build_dist`:

```yaml
- name: Update CustomPiOS Paths
  run: |
    cd repository/src
    ../../CustomPiOS/src/update-custompios-paths
```

### GitVersion Not Working

Ensure you checkout with full history:

```yaml
- name: Checkout Project Repository
  uses: actions/checkout@v6.0.1
  with:
    fetch-depth: 0  # Important: fetch all history
```

## Runner Selection

The example uses ARM runners (`ubuntu-24.04-arm`) for faster builds on ARM architecture. If you don't have ARM runners:

- Use `ubuntu-latest` (x86_64)
- QEMU will be used for cross-compilation (slower)
- Ensure `qemu-user-static` is installed

## Reference Links

- [GitHub Actions Workflows Documentation](https://docs.github.com/en/actions/how-tos/write-workflows)
- [OctoPi Build Workflow Example](https://github.com/guysoft/OctoPi/blob/devel/.github/workflows/build.yml)
- [CustomPiOS Documentation](https://github.com/guysoft/CustomPiOS)
- [GitVersion Documentation](https://gitversion.net/)
