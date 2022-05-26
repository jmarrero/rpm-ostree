// If not running on container continue the current path.
// SPDX-License-Identifier: Apache-2.0 OR MIT

use anyhow::{anyhow, Result};
use crate::ffi::SystemHostType;


/// Primary entrypoint to running our wrapped `kernel-install` handling.
pub(crate) fn main(hosttype: SystemHostType, argv: &[&str]) -> Result<()> {
        remove_current_kernel()?;
        run_dracut()?;
        Ok(())
}

fn remove_current_kernel() -> Result<()> {
    //For this will need to expose these functions to rust.
    //rpmostree_kernel_remove from src/libpriv/rpmostree-kernel.cxx
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

