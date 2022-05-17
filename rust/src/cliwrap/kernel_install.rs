// If not running on container continue the current path.
// SPDX-License-Identifier: Apache-2.0 OR MIT
use anyhow::Result;
use std::fs;

/// Primary entrypoint to running our wrapped `kernel-install` handling.
pub(crate) fn main() -> Result<()> {
    remove_current_kernel()?;
    run_dracut()?;
    Ok(())
}

fn remove_current_kernel() -> Result<()> {
    let modules_dir = "/lib/modules";
    let kernel_bin = "vmlinuz";
    let paths = fs::read_dir(modules_dir).unwrap();

    for path in paths {
        let current_path = path.unwrap().path();
        let file_path = current_path.join(kernel_bin);
        if !fs::metadata(file_path).is_ok() {
            fs::remove_dir_all(current_path)?;
        }
    }
    Ok(())
}

fn run_dracut() -> Result<()> {
    // -> Reimplement the dracut calls in rust
    // This new code must move the new initramfs to /lib/modules/new-kernel-dir
    //"#!/usr/bin/bash\n"
    //"set -euo pipefail\n"
    //"export PATH=%s:${PATH}\n"
    //"extra_argv=; if (dracut --help; true) | grep -q -e --reproducible; then "
    //"extra_argv=\"--reproducible --gzip\"; fi\n"
    //"mkdir -p /tmp/dracut && dracut $extra_argv -v --add ostree "
    //"--tmpdir=/tmp/dracut -f /tmp/initramfs.img \"$@\"\n"
    //"mv /tmp/initramfs.img /lib/modules/NEWKERNEL-DIR
    Ok(())
}
