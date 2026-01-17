#!/usr/bin/env python3
import json
import zipfile
import hashlib
import os
import argparse
from datetime import date


def get_file_sha256(filepath):
    """Calculate SHA256 hash of a file."""
    sha256_hash = hashlib.sha256()
    with open(filepath, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()


def main():
    parser = argparse.ArgumentParser(description='Generate Raspberry Pi Imager JSON')
    parser.add_argument('--zip-path', required=True, help='Path to the zip file')
    parser.add_argument('--sha256-path', required=True, help='Path to the .img.sha256 file')
    parser.add_argument('--image-url', required=True, help='URL to the uploaded image')
    parser.add_argument('--dist-version', required=True, help='Distribution version')
    parser.add_argument('--output', required=True, help='Output JSON file path')

    args = parser.parse_args()

    # Validate zip file exists
    if not os.path.exists(args.zip_path):
        print(f"Error: Zip file not found at {args.zip_path}")
        exit(1)
    zip_path = args.zip_path

    # Validate sha256 file exists
    if not os.path.exists(args.sha256_path):
        print(f"Error: SHA256 file not found at {args.sha256_path}")
        exit(1)
    sha256_path = args.sha256_path

    # Read extract SHA256 from .img.sha256 file
    with open(sha256_path, 'r') as f:
        extract_sha256 = f.read().split()[0]

    # Get extract size from zip contents
    with zipfile.ZipFile(zip_path) as zip_file:
        extract_size = zip_file.filelist[0].file_size

    # Get download size
    image_download_size = os.stat(zip_path).st_size

    # Calculate download SHA256
    image_download_sha256 = get_file_sha256(zip_path)

    # Get release date
    release_date = date.today().strftime("%Y-%m-%d")

    # Create the JSON structure with static imager section
    rpi_imager_json = {
        "imager": {
            "latest_version": "2.0.0",
            "url": "https://www.raspberrypi.com/software/",
            "devices": [
                {
                    "name": "Raspberry Pi 5",
                    "tags": ["pi5-64bit"],
                    "default": True,
                    "icon": "https://downloads.raspberrypi.com/imager/icons/RPi_5.png",
                    "description": "Raspberry Pi 5, 500 / 500+, and Compute Module 5",
                    "matching_type": "exclusive"
                },
                {
                    "name": "Raspberry Pi 4",
                    "tags": ["pi4-64bit"],
                    "icon": "https://downloads.raspberrypi.com/imager/icons/RPi_4.png",
                    "description": "Raspberry Pi 4 Model B, 400, and Compute Module 4 / 4S",
                    "matching_type": "inclusive"
                },
                {
                    "name": "Raspberry Pi 3",
                    "tags": ["pi3-64bit"],
                    "icon": "https://downloads.raspberrypi.com/imager/icons/RPi_3.png",
                    "description": "Raspberry Pi 3 Model A+ / B / B+ and Compute Module 3 / 3+",
                    "matching_type": "inclusive"
                }
            ]
        },
        "os_list": [
            {
                "name": f"MonsterPi {args.dist_version} (Trixie)",
                "description": f"FDM Monster RaspberryPi distro ({args.dist_version})",
                "website": "https://fdm-monster.net",
                "icon": "https://raw.githubusercontent.com/fdm-monster/fdm-monster/ba18cb7049a137939f9d2845d4d32507c9dbba08/docs/images/logo-copyright.png",
                "url": args.image_url,
                "extract_size": extract_size,
                "extract_sha256": extract_sha256,
                "image_download_size": image_download_size,
                "image_download_sha256": image_download_sha256,
                "release_date": release_date,
                "devices": [
                    "pi5-64bit",
                    "pi4-64bit",
                    "pi3-64bit"
                ],
                "init_format": "systemd"
            }
        ]
    }

    # Write to output file
    with open(args.output, 'w') as f:
        json.dump(rpi_imager_json, f, indent=2)

    print(f"Generated Raspberry Pi Imager JSON: {args.output}")
    print(f"  Name: MonsterPi {args.dist_version} (Trixie)")
    print(f"  URL: {args.image_url}")
    print(f"  Extract size: {extract_size} bytes")
    print(f"  Download size: {image_download_size} bytes")
    print(f"  Release date: {release_date}")


if __name__ == "__main__":
    main()
